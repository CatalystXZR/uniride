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

// ... (tus funciones de logs y helpers se quedan igual arriba)

serve(async (req) => {
  if (req.method === "GET") return new Response("ok", { status: 200 });
  
  try {
    const body = await req.json();
    logInfo("sandbox_webhook_received", body);

    // --- MODO SIMULADO ---
    // En lugar de ir a buscar a MercadoPago, sacamos los datos del body que tú envíes
    // O usamos valores por defecto para pruebas rápidas.
    
    const paymentId = body.payment_id ?? `fake_pmt_${Date.now()}`;
    const userId = body.user_id; // DEBES enviar el user_id en tu prueba
    const amountRequested = body.amount ?? 5000;
    const amountCharged = amountRequested + (amountRequested * 0.01); // Simulamos la comisión del 1%
    const feeAmount = amountCharged - amountRequested;

    if (!userId || !isValidUuid(userId)) {
      logError("sandbox_missing_user_id");
      return new Response("missing valid user_id", { status: 400 });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // 1. Evitar duplicados (opcional en sandbox, pero bueno para probar)
    const { data: existing } = await supabase
      .from("mp_payments")
      .select("external_payment_id")
      .eq("external_payment_id", paymentId)
      .maybeSingle();

    if (existing) {
      return new Response("already processed", { status: 200 });
    }

    // 2. Llamamos al RPC que crearemos abajo para abonar la billetera
    const { error: creditErr } = await supabase.rpc("credit_wallet_topup", {
      p_user_id: userId,
      p_amount: amountRequested,
      p_external_payment_id: paymentId,
      p_amount_charged: Math.round(amountCharged),
      p_fee_amount: Math.round(feeAmount),
      p_provider: "mercadopago_sandbox",
    });

    if (creditErr) {
      logError("credit_wallet_topup_failed", creditErr);
      return new Response("db credit failed", { status: 500 });
    }

    logInfo("wallet_topped_up_SUCCESS_SANDBOX", { userId, amountRequested });

    return new Response(JSON.stringify({ status: "success", payment_id: paymentId }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });

  } catch (err) {
    logError("sandbox_unhandled_error", { message: String(err) });
    return new Response("internal error", { status: 500 });
  }
});