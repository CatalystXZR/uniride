/**
 *
 * Project: TurnoApp
 *
 * Original Concept: Agustin Puelma, Cristobal Cordova, Carlos Ibarra
 *
 * Software Architecture & Code: Matias Toledo (catalystxzr)
 *
 * Description: Production-grade implementation for UDD carpooling system.
 *
 * Copyright (c) 2026. All rights reserved.
 *
 */

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const MP_ACCESS_TOKEN = Deno.env.get("MP_ACCESS_TOKEN")!;
const MP_WEBHOOK_SECRET = Deno.env.get("MP_WEBHOOK_SECRET") ?? "";

function logInfo(event: string, details: Record<string, unknown> = {}) {
  console.log(JSON.stringify({ level: "info", event, ...details }));
}

function logWarn(event: string, details: Record<string, unknown> = {}) {
  console.warn(JSON.stringify({ level: "warn", event, ...details }));
}

function logError(event: string, details: Record<string, unknown> = {}) {
  console.error(JSON.stringify({ level: "error", event, ...details }));
}

function isValidUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function parseExternalReference(externalRef: string, chargedAmount: number) {
  // New format: turnoapp_topup_<userId>_<timestamp>_<amountRequested>_<amountCharged>
  // Legacy format: turnoapp_topup_<userId>_<timestamp>
  const parts = externalRef.split("_");
  if (parts.length < 4 || parts[0] !== "turnoapp" || parts[1] !== "topup") {
    return null;
  }

  const userId = parts[2];
  if (!isValidUuid(userId)) {
    return null;
  }

  if (parts.length >= 6) {
    const amountRequested = Number(parts[4]);
    const amountCharged = Number(parts[5]);

    if (!Number.isFinite(amountRequested) || !Number.isFinite(amountCharged)) {
      return null;
    }

    return {
      userId,
      amountRequested: Math.round(amountRequested),
      amountCharged: Math.round(amountCharged),
      isLegacy: false,
    };
  }

  if (chargedAmount <= 0) {
    return null;
  }

  return {
    userId,
    amountRequested: chargedAmount,
    amountCharged: chargedAmount,
    isLegacy: true,
  };
}

function feeFromAmounts(amountRequested: number, amountCharged: number): number | null {
  const fee = amountCharged - amountRequested;
  return fee < 0 ? null : fee;
}

function expectedFee(amountRequested: number): number {
  return Math.round(amountRequested * 0.01);
}

function isFeeConsistent(amountRequested: number, feeAmount: number): boolean {
  return feeAmount === expectedFee(amountRequested);
}

function parseTimestampMs(ts: string): number | null {
  const parsed = Number(ts);
  if (!Number.isFinite(parsed)) return null;
  const rounded = Math.trunc(parsed);
  if (rounded <= 0) return null;

  // Mercado Pago may send ts in seconds or milliseconds depending on integration path.
  // Normalize to milliseconds before stale-window validation.
  return rounded < 1_000_000_000_000 ? rounded * 1000 : rounded;
}

async function verifyMPSignature(req: Request, dataId: string): Promise<boolean> {
  if (!MP_WEBHOOK_SECRET) {
    logWarn("mp_webhook_secret_missing", { data_id: dataId });
    return true;
  }

  const xSignature = req.headers.get("x-signature");
  const xRequestId = req.headers.get("x-request-id") ?? "";

  if (!xSignature) {
    logError("mp_webhook_missing_signature", { data_id: dataId });
    return false;
  }

  const parts = Object.fromEntries(
    xSignature.split(";").map((part) => {
      const [k, v] = part.split("=");
      return [k.trim(), v?.trim() ?? ""];
    }),
  );

  const ts = parts["ts"];
  const receivedHmac = parts["v1"]?.toLowerCase();

  if (!ts || !receivedHmac) {
    logError("mp_webhook_malformed_signature", {
      data_id: dataId,
      signature: xSignature,
    });
    return false;
  }

  const tsMs = parseTimestampMs(ts);
  if (tsMs == null) {
    logError("mp_webhook_invalid_timestamp", { data_id: dataId, ts });
    return false;
  }

  if (Math.abs(Date.now() - tsMs) > 5 * 60 * 1000) {
    logError("mp_webhook_stale_timestamp", { data_id: dataId, ts });
    return false;
  }

  const message = `id:${dataId};request-id:${xRequestId};ts:${ts};`;

  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(MP_WEBHOOK_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signatureBuffer = await crypto.subtle.sign("HMAC", key, encoder.encode(message));
  const computedHmac = Array.from(new Uint8Array(signatureBuffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  if (computedHmac.length !== receivedHmac.length) return false;
  let diff = 0;
  for (let i = 0; i < computedHmac.length; i++) {
    diff |= computedHmac.charCodeAt(i) ^ receivedHmac.charCodeAt(i);
  }
  if (diff !== 0) {
    logError("mp_webhook_signature_mismatch", { data_id: dataId });
    return false;
  }

  return true;
}

serve(async (req) => {
  if (req.method === "GET") {
    return new Response("ok", { status: 200 });
  }

  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }

  try {
    if (!MP_ACCESS_TOKEN) {
      logError("mp_access_token_missing");
      return new Response("mp access token missing", { status: 500 });
    }

    const body = await req.json();
    logInfo("mp_webhook_received", {
      body_type: body?.type ?? body?.topic,
      body_id: body?.data?.id ?? body?.id ?? body?.data_id,
    });

    const topic = body.type ?? body.topic;
    const dataId = String(body.data?.id ?? body.id ?? body.data_id ?? "");

    if (topic !== "payment" || !dataId) {
      logInfo("mp_webhook_ignored", { topic, data_id: dataId || null });
      return new Response("ignored", { status: 200 });
    }

    const signatureValid = await verifyMPSignature(req, dataId);
    if (!signatureValid) {
      return new Response("invalid signature", { status: 401 });
    }

    const mpRes = await fetch(`https://api.mercadopago.com/v1/payments/${dataId}`, {
      headers: {
        "Authorization": `Bearer ${MP_ACCESS_TOKEN}`,
      },
    });

    if (!mpRes.ok) {
      const response = await mpRes.text();
      logError("mp_payment_fetch_failed", {
        data_id: dataId,
        status: mpRes.status,
        response,
      });
      return new Response("payment fetch failed", { status: 200 });
    }

    const payment = await mpRes.json();
    logInfo("mp_payment_fetched", {
      payment_id: payment?.id,
      status: payment?.status,
      external_reference: payment?.external_reference,
    });

    if (payment.status !== "approved") {
      logInfo("mp_payment_not_approved", {
        payment_id: payment?.id,
        status: payment?.status,
      });
      return new Response("not approved", { status: 200 });
    }

    const paymentId = String(payment.id);
    const transactionAmount = Number(payment.transaction_amount);
    if (!Number.isFinite(transactionAmount)) {
      logError("mp_payment_invalid_amount", {
        payment_id: paymentId,
        transaction_amount: payment.transaction_amount,
      });
      return new Response("invalid amount", { status: 200 });
    }

    const chargedAmount = Math.round(transactionAmount);
    const parsedRef = parseExternalReference(payment.external_reference ?? "", chargedAmount);
    if (!parsedRef) {
      logWarn("mp_payment_unrecognized_external_reference", {
        payment_id: paymentId,
        external_reference: payment.external_reference,
      });
      return new Response("unrecognized reference", { status: 200 });
    }

    if (chargedAmount !== parsedRef.amountCharged) {
      logError("mp_payment_amount_mismatch", {
        payment_id: paymentId,
        charged_amount: chargedAmount,
        expected_charged_amount: parsedRef.amountCharged,
      });
      return new Response("amount mismatch", { status: 200 });
    }

    const computedFeeAmount = feeFromAmounts(parsedRef.amountRequested, chargedAmount);
    if (computedFeeAmount == null) {
      logError("mp_payment_invalid_fee", {
        payment_id: paymentId,
        amount_requested: parsedRef.amountRequested,
        amount_charged: chargedAmount,
      });
      return new Response("invalid fee", { status: 200 });
    }

    if (!parsedRef.isLegacy && !isFeeConsistent(parsedRef.amountRequested, computedFeeAmount)) {
      logError("mp_payment_inconsistent_fee", {
        payment_id: paymentId,
        amount_requested: parsedRef.amountRequested,
        amount_charged: chargedAmount,
        fee_amount: computedFeeAmount,
      });
      return new Response("inconsistent fee", { status: 200 });
    }

    const feeAmount = parsedRef.isLegacy ? 0 : computedFeeAmount;

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: existing } = await supabase
      .from("mp_payments")
      .select("external_payment_id")
      .eq("external_payment_id", paymentId)
      .maybeSingle();

    if (existing) {
      logInfo("mp_webhook_duplicate", { payment_id: paymentId });
      return new Response("already processed", { status: 200 });
    }

    const { error: creditErr } = await supabase.rpc("credit_wallet_topup", {
      p_user_id: parsedRef.userId,
      p_amount: parsedRef.amountRequested,
      p_external_payment_id: paymentId,
      p_amount_charged: chargedAmount,
      p_fee_amount: feeAmount,
      p_provider: "mercadopago",
    });

    if (creditErr) {
      logError("credit_wallet_topup_failed", {
        payment_id: paymentId,
        user_id: parsedRef.userId,
        amount_requested: parsedRef.amountRequested,
        charged_amount: chargedAmount,
        fee_amount: feeAmount,
        error: creditErr.message,
      });
      return new Response("credit failed", { status: 500 });
    }

    logInfo("wallet_topped_up", {
      payment_id: paymentId,
      user_id: parsedRef.userId,
      amount_requested: parsedRef.amountRequested,
      charged_amount: chargedAmount,
      fee_amount: feeAmount,
      legacy_external_reference: parsedRef.isLegacy,
      provider: "mercadopago",
    });

    return new Response("ok", { status: 200 });
  } catch (err) {
    logError("mp_webhook_unhandled", {
      message: err instanceof Error ? err.message : String(err),
    });
    return new Response("internal error", { status: 500 });
  }
});
