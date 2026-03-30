/**
 *
 * Project: TurnoApp
 *
 * Original Concept: Agustín Puelma, Cristobal Cordova, Carlos Ibarra
 *
 * Software Architecture & Code: Matías Toledo (catalystxzr)
 *
 * Description: Production-grade implementation for UDD carpooling system.
 *
 * Copyright (c) 2026. All rights reserved.
 *
 */

// supabase/functions/mercadopago-webhook/index.ts
//
// Receives IPN / webhook notifications from Mercado Pago.
// Only processes "payment" topic with status "approved".
//
// Environment variables required:
//   MP_ACCESS_TOKEN          — Same seller access token
//   MP_WEBHOOK_SECRET        — Shared secret from MP Notifications config (required in production)
//   SUPABASE_URL             — Injected automatically
//   SUPABASE_SERVICE_ROLE_KEY — Injected automatically
//
// In Mercado Pago Dashboard:
//   Notifications URL → https://<your-project>.supabase.co/functions/v1/mercadopago-webhook

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const MP_ACCESS_TOKEN   = Deno.env.get("MP_ACCESS_TOKEN")!;
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

// ── HMAC-SHA256 signature verification ──────────────────────────────────────
//
// Mercado Pago signs each webhook with the header:
//   x-signature: ts=<unix_ms>;v1=<hex_hmac>
//
// The signed message is: "id:<data.id>;request-id:<x-request-id>;ts:<ts>;"
// Ref: https://www.mercadopago.com.ar/developers/en/docs/your-integrations/notifications/webhooks
//
async function verifyMPSignature(
  req: Request,
  dataId: string,
): Promise<boolean> {
  if (!MP_WEBHOOK_SECRET) {
    // If the secret is not configured, skip verification (dev/staging only).
    // Production deploys MUST set MP_WEBHOOK_SECRET.
    logWarn("mp_webhook_secret_missing", { data_id: dataId });
    return true;
  }

  const xSignature = req.headers.get("x-signature");
  const xRequestId = req.headers.get("x-request-id") ?? "";

  if (!xSignature) {
    logError("mp_webhook_missing_signature", { data_id: dataId });
    return false;
  }

  // Parse ts and v1 from "ts=<value>;v1=<value>"
  const parts = Object.fromEntries(
    xSignature.split(";").map((part) => {
      const [k, v] = part.split("=");
      return [k.trim(), v?.trim() ?? ""];
    }),
  );

  const ts = parts["ts"];
  const receivedHmac = parts["v1"];

  if (!ts || !receivedHmac) {
    logError("mp_webhook_malformed_signature", {
      data_id: dataId,
      signature: xSignature,
    });
    return false;
  }

  // Reject requests older than 5 minutes (replay attack protection)
  const tsMs = parseInt(ts, 10);
  const nowMs = Date.now();
  if (Math.abs(nowMs - tsMs) > 5 * 60 * 1000) {
    logError("mp_webhook_stale_timestamp", { data_id: dataId, ts });
    return false;
  }

  // Build the message that MP signs
  const message = `id:${dataId};request-id:${xRequestId};ts:${ts};`;

  // Compute HMAC-SHA256
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(MP_WEBHOOK_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signatureBuffer = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(message),
  );
  const computedHmac = Array.from(new Uint8Array(signatureBuffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  // Constant-time comparison to prevent timing attacks
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

// ── Main handler ─────────────────────────────────────────────────────────────

serve(async (req) => {
  // MP sends GET to validate the URL during setup — must return 200
  if (req.method === "GET") {
    return new Response("ok", { status: 200 });
  }

  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }

  try {
    // ── Parse the notification ────────────────────────────────
    const body = await req.json();
    logInfo("mp_webhook_received", {
      body_type: body?.type ?? body?.topic,
      body_id: body?.data?.id ?? body?.id ?? body?.data_id,
    });

    // MP sends two formats: IPN (type/id) and modern webhooks (action/data.id)
    const topic  = body.type   ?? body.topic;
    const dataId = String(body.data?.id ?? body.id ?? body.data_id ?? "");

    // Only handle payment events
    if (topic !== "payment" || !dataId) {
      logInfo("mp_webhook_ignored", { topic, data_id: dataId || null });
      return new Response("ignored", { status: 200 });
    }

    // ── Verify HMAC signature ─────────────────────────────────
    const signatureValid = await verifyMPSignature(req, dataId);
    if (!signatureValid) {
      return new Response("invalid signature", { status: 401 });
    }

    // ── Fetch payment details from MP API ────────────────────
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
      // Return 200 so MP doesn't retry — we'll lose this event but won't loop
      return new Response("payment fetch failed", { status: 200 });
    }

    const payment = await mpRes.json();
    logInfo("mp_payment_fetched", {
      payment_id: payment?.id,
      status: payment?.status,
      external_reference: payment?.external_reference,
    });

    // Only credit on approved payments
    if (payment.status !== "approved") {
      logInfo("mp_payment_not_approved", {
        payment_id: payment?.id,
        status: payment?.status,
      });
      return new Response("not approved", { status: 200 });
    }

    const externalRef: string = payment.external_reference ?? "";
    const paymentId   = String(payment.id);
    const amountCLP   = Math.round(payment.transaction_amount);

    // external_reference format: "turnoapp_topup_<userId>_<timestamp>"
    const parts = externalRef.split("_");
    if (parts.length < 4 || parts[0] !== "turnoapp" || parts[1] !== "topup") {
      logWarn("mp_payment_unrecognized_external_reference", {
        payment_id: paymentId,
        external_reference: externalRef,
      });
      return new Response("unrecognized reference", { status: 200 });
    }
    const userId = parts[2]; // UUID

    // ── Idempotency: check if already processed ───────────────
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

    // ── Credit wallet ─────────────────────────────────────────
    // Use a Postgres transaction via RPC to keep the ledger consistent.
    const { error: creditErr } = await supabase.rpc("credit_wallet_topup", {
      p_user_id:             userId,
      p_amount:              amountCLP,
      p_external_payment_id: paymentId,
    });

    if (creditErr) {
      logError("credit_wallet_topup_failed", {
        payment_id: paymentId,
        user_id: userId,
        amount_clp: amountCLP,
        error: creditErr.message,
      });
      // Return 500 so MP retries — the RPC must be idempotent
      return new Response("credit failed", { status: 500 });
    }

    logInfo("wallet_topped_up", {
      payment_id: paymentId,
      user_id: userId,
      amount_clp: amountCLP,
    });
    return new Response("ok", { status: 200 });

  } catch (err) {
    logError("mp_webhook_unhandled", {
      message: err instanceof Error ? err.message : String(err),
    });
    // Return 500 so MP retries the notification
    return new Response("internal error", { status: 500 });
  }
});
