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

// supabase/functions/create-topup-intent/index.ts
//
// Called by: WalletService.createTopupIntent(amountCLP)
// Payload:   { amount: number }   (CLP, e.g. 2000)
// Returns:   { init_point: string }  (Mercado Pago checkout URL)
//
// Environment variables required (set in Supabase Dashboard → Settings → Edge Functions):
//   MP_ACCESS_TOKEN   — Mercado Pago seller access token (starts with APP_USR-...)
//   APP_BASE_URL      — Public URL of your app, e.g. https://turnoapp.cl
//   SUPABASE_URL      — Injected automatically by Supabase runtime
//   SUPABASE_SERVICE_ROLE_KEY — Injected automatically by Supabase runtime

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const MP_ACCESS_TOKEN = Deno.env.get("MP_ACCESS_TOKEN")!;
const APP_BASE_URL    = Deno.env.get("APP_BASE_URL") ?? "https://turnoapp.cl";
const SUPABASE_URL    = Deno.env.get("SUPABASE_URL")!;

// Webhook URL: the mercadopago-webhook Edge Function on this same Supabase project.
// This is constructed from SUPABASE_URL (auto-injected), so it is always correct
// regardless of which Supabase project the function is deployed to.
const MP_WEBHOOK_URL  = `${SUPABASE_URL}/functions/v1/mercadopago-webhook`;

const corsHeaders = {
  "Access-Control-Allow-Origin":  "*",
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

function logInfo(event: string, details: Record<string, unknown> = {}) {
  console.log(JSON.stringify({ level: "info", event, ...details }));
}

function logError(event: string, details: Record<string, unknown> = {}) {
  console.error(JSON.stringify({ level: "error", event, ...details }));
}

serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  try {
    // ── Auth: extract calling user from JWT ──────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "unauthorized" }, 401);
    }

    const supabase = createClient(
      SUPABASE_URL,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Verify the JWT and get the user
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authErr } = await supabase.auth.getUser(token);
    if (authErr || !user) {
      return jsonResponse({ error: "invalid_token" }, 401);
    }

    // ── Parse body ───────────────────────────────────────────
    const body = await req.json() as { amount?: unknown };
    const amount = sanitizeAmount(body.amount);

    if (amount == null) {
      return jsonResponse({ error: "invalid_amount" }, 400);
    }

    // Minimum topup: $2.000 CLP
    if (amount < 2000) {
      return jsonResponse({ error: "minimum amount is 2000 CLP" }, 400);
    }

    // Maximum topup: $200.000 CLP per transaction (fraud prevention)
    if (amount > 200000) {
      return jsonResponse({ error: "maximum amount is 200000 CLP" }, 400);
    }

    // ── Create Mercado Pago preference ───────────────────────
    // external_reference is used by the webhook to identify user + amount.
    const externalRef = `turnoapp_topup_${user.id}_${Date.now()}`;

    const mpBody = {
      items: [
        {
          id:          "wallet_topup",
          title:       "Recarga billetera TurnoApp",
          description: `Recarga de $${amount.toLocaleString("es-CL")} CLP`,
          quantity:    1,
          currency_id: "CLP",
          unit_price:  amount,
        },
      ],
      payer: {
        email: user.email,
      },
      external_reference: externalRef,
      // NOTE on back_urls and mobile deep links:
      // These are plain HTTPS URLs. For a Flutter Web PWA the browser navigates
      // back to the app naturally. For a native mobile app, MP redirects to the
      // browser after payment and the user must switch back manually — the balance
      // will update on next refresh.
      // To make the mobile flow seamless in the future, register a custom URL scheme
      // (e.g. turnoapp://wallet) and replace these with deep-link URLs.
      back_urls: {
        success: `${APP_BASE_URL}/wallet?topup=success`,
        failure: `${APP_BASE_URL}/wallet?topup=failure`,
        pending: `${APP_BASE_URL}/wallet?topup=pending`,
      },
      auto_return:        "approved",
      notification_url:   MP_WEBHOOK_URL,   // Edge Function URL — auto-derived from SUPABASE_URL
      statement_descriptor: "TURNOAPP",
      expires:            false,
    };

    const mpRes = await fetch("https://api.mercadopago.com/checkout/preferences", {
      method:  "POST",
      headers: {
        "Content-Type":  "application/json",
        "Authorization": `Bearer ${MP_ACCESS_TOKEN}`,
      },
      body: JSON.stringify(mpBody),
    });

    if (!mpRes.ok) {
      const errText = await mpRes.text();
      logError("mp_preference_create_failed", {
        user_id: user.id,
        amount,
        status: mpRes.status,
        response: errText,
      });
      return jsonResponse({ error: "payment provider error" }, 502);
    }

    const mpData = await mpRes.json();

    logInfo("topup_intent_created", {
      user_id: user.id,
      amount,
      preference_id: mpData.id,
    });

    return jsonResponse({
      init_point: mpData.init_point,
      sandbox_init_point: mpData.sandbox_init_point,
      preference_id: mpData.id,
      external_reference: externalRef,
    });

  } catch (err) {
    logError("create_topup_intent_unhandled", {
      message: err instanceof Error ? err.message : String(err),
    });
    return jsonResponse({ error: "internal server error" }, 500);
  }
});
