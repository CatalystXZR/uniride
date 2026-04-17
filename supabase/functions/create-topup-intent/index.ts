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

// supabase/functions/create-topup-intent/index.ts
//
// Provider-agnostic topup intent creator.
// Current providers:
// - mercadopago (active flow)
// - stripe (stub response to keep API ready)

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const APP_BASE_URL = Deno.env.get("APP_BASE_URL") ?? "https://turnoapp.cl";

const SUPPORTED_PAYMENT_PROVIDERS = new Set(["mercadopago", "stripe", "disabled"]);
const PAYMENT_PROVIDER_RAW = (Deno.env.get("PAYMENT_PROVIDER") ?? "mercadopago").toLowerCase();
const PAYMENT_PROVIDER = SUPPORTED_PAYMENT_PROVIDERS.has(PAYMENT_PROVIDER_RAW)
  ? PAYMENT_PROVIDER_RAW
  : "mercadopago";

// Mercado Pago config
const MP_ACCESS_TOKEN = Deno.env.get("MP_ACCESS_TOKEN") ?? "";
const MP_WEBHOOK_URL = `${SUPABASE_URL}/functions/v1/mercadopago-webhook`;

// Stripe config placeholders (for future connection)
const STRIPE_PUBLISHABLE_KEY = Deno.env.get("STRIPE_PUBLISHABLE_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function sanitizeAmount(rawAmount: unknown): number | null {
  if (typeof rawAmount === "number") {
    if (!Number.isFinite(rawAmount)) return null;
    return Math.round(rawAmount);
  }
  if (typeof rawAmount === "string") {
    const parsed = Number(rawAmount.trim());
    if (!Number.isFinite(parsed)) return null;
    return Math.round(parsed);
  }
  return null;
}

function topupFee(amount: number): number {
  return Math.round(amount * 0.01);
}

function topupChargedAmount(amount: number): number {
  return amount + topupFee(amount);
}

function logInfo(event: string, details: Record<string, unknown> = {}) {
  console.log(JSON.stringify({ level: "info", event, ...details }));
}

function logWarn(event: string, details: Record<string, unknown> = {}) {
  console.warn(JSON.stringify({ level: "warn", event, ...details }));
}

function logError(event: string, details: Record<string, unknown> = {}) {
  console.error(JSON.stringify({ level: "error", event, ...details }));
}

function extractBearerToken(authHeader: string | null): string | null {
  if (!authHeader) return null;
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() ?? null;
}

async function getAuthedUser(authHeader: string | null) {
  const token = extractBearerToken(authHeader);
  if (!token) return null;

  const supabase = createClient(
    SUPABASE_URL,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: { user }, error } = await supabase.auth.getUser(token);
  if (error || !user) return null;
  return user;
}

async function createMercadoPagoIntent(params: {
  amountRequested: number;
  amountCharged: number;
  userId: string;
  userEmail?: string;
}) {
  const { amountRequested, amountCharged, userId, userEmail } = params;

  if (!MP_ACCESS_TOKEN) {
    throw new Error("mp_access_token_missing");
  }

  const externalRef = `turnoapp_topup_${userId}_${Date.now()}_${amountRequested}_${amountCharged}`;

  const payer = userEmail?.trim()
    ? { email: userEmail.trim() }
    : undefined;

  const mpBody = {
    items: [
      {
        id: "wallet_topup",
        title: "Recarga billetera TurnoApp",
        description: `Recarga neta $${amountRequested.toLocaleString("es-CL")} CLP + 1% fee`,
        quantity: 1,
        currency_id: "CLP",
        unit_price: amountCharged,
      },
    ],
    payer,
    external_reference: externalRef,
    back_urls: {
      success: `${APP_BASE_URL}/wallet?topup=success`,
      failure: `${APP_BASE_URL}/wallet?topup=failure`,
      pending: `${APP_BASE_URL}/wallet?topup=pending`,
    },
    auto_return: "approved",
    notification_url: MP_WEBHOOK_URL,
    statement_descriptor: "TURNOAPP",
    expires: false,
  };

  const mpRes = await fetch("https://api.mercadopago.com/checkout/preferences", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${MP_ACCESS_TOKEN}`,
    },
    body: JSON.stringify(mpBody),
  });

  if (!mpRes.ok) {
    const response = await mpRes.text();
    logError("mp_preference_create_failed", {
      user_id: userId,
      amount_requested: amountRequested,
      amount_charged: amountCharged,
      status: mpRes.status,
      response,
    });
    throw new Error("payment_provider_error");
  }

  const mpData = await mpRes.json();
  return {
    provider: "mercadopago",
    init_point: mpData.init_point,
    sandbox_init_point: mpData.sandbox_init_point,
    preference_id: mpData.id,
    external_reference: externalRef,
  };
}

function createStripeStub(params: {
  amountRequested: number;
  amountCharged: number;
  userId: string;
}) {
  const { amountRequested, amountCharged, userId } = params;
  const externalRef = `turnoapp_topup_${userId}_${Date.now()}_${amountRequested}_${amountCharged}`;

  return {
    provider: "stripe",
    status: "provider_not_connected",
    message: "Stripe endpoint listo. Falta conectar secret key y webhook de produccion.",
    external_reference: externalRef,
    stripe_publishable_key_present: STRIPE_PUBLISHABLE_KEY.length > 0,
    amount_requested: amountRequested,
    fee_amount: topupFee(amountRequested),
    amount_charged: amountCharged,
  };
}

function createDisabledResponse(params: {
  amountRequested: number;
  amountCharged: number;
}) {
  const { amountRequested, amountCharged } = params;
  return {
    provider: "disabled",
    status: "disabled",
    message: "Recargas temporalmente deshabilitadas hasta configurar credenciales del proveedor.",
    amount_requested: amountRequested,
    fee_amount: topupFee(amountRequested),
    amount_charged: amountCharged,
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  try {
    const user = await getAuthedUser(req.headers.get("Authorization"));
    if (!user) {
      return jsonResponse({ error: "unauthorized" }, 401);
    }

    const body = await req.json() as { amount?: unknown };
    const amountRequested = sanitizeAmount(body.amount);

    if (amountRequested == null) {
      return jsonResponse({ error: "invalid_amount" }, 400);
    }

    if (amountRequested < 2000) {
      return jsonResponse({ error: "minimum amount is 2000 CLP" }, 400);
    }

    if (amountRequested > 200000) {
      return jsonResponse({ error: "maximum amount is 200000 CLP" }, 400);
    }

    const feeAmount = topupFee(amountRequested);
    const amountCharged = topupChargedAmount(amountRequested);

    if (PAYMENT_PROVIDER !== PAYMENT_PROVIDER_RAW) {
      logWarn("payment_provider_invalid_fallback", {
        configured_provider: PAYMENT_PROVIDER_RAW,
        selected_provider: PAYMENT_PROVIDER,
      });
    }

    logInfo("topup_intent_requested", {
      user_id: user.id,
      provider: PAYMENT_PROVIDER,
      amount_requested: amountRequested,
      fee_amount: feeAmount,
      amount_charged: amountCharged,
    });

    if (PAYMENT_PROVIDER === "stripe") {
      const stripeStub = createStripeStub({
        amountRequested,
        amountCharged,
        userId: user.id,
      });
      return jsonResponse(stripeStub, 200);
    }

    if (PAYMENT_PROVIDER === "disabled") {
      const disabledResponse = createDisabledResponse({
        amountRequested,
        amountCharged,
      });
      return jsonResponse(disabledResponse, 200);
    }

    const mpIntent = await createMercadoPagoIntent({
      amountRequested,
      amountCharged,
      userId: user.id,
      userEmail: user.email,
    });

    return jsonResponse({
      ...mpIntent,
      amount_requested: amountRequested,
      fee_amount: feeAmount,
      amount_charged: amountCharged,
    });
  } catch (err) {
    logError("create_topup_intent_unhandled", {
      message: err instanceof Error ? err.message : String(err),
    });
    if (err instanceof Error && err.message === "payment_provider_error") {
      return jsonResponse({ error: "payment_provider_error" }, 502);
    }
    return jsonResponse({ error: "internal_server_error" }, 500);
  }
});
