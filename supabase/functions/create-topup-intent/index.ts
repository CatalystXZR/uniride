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

serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ── Auth: extract calling user from JWT ──────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      SUPABASE_URL,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Verify the JWT and get the user
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authErr } = await supabase.auth.getUser(token);
    if (authErr || !user) {
      return new Response(JSON.stringify({ error: "invalid token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ── Parse body ───────────────────────────────────────────
    const { amount } = await req.json() as { amount: number };

    // Minimum topup: $2.000 CLP
    if (!amount || amount < 2000) {
      return new Response(JSON.stringify({ error: "minimum amount is 2000 CLP" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Maximum topup: $200.000 CLP per transaction (fraud prevention)
    if (amount > 200000) {
      return new Response(JSON.stringify({ error: "maximum amount is 200000 CLP" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
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
      console.error("MP preference creation failed:", errText);
      return new Response(JSON.stringify({ error: "payment provider error" }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const mpData = await mpRes.json();

    return new Response(
      JSON.stringify({
        init_point:        mpData.init_point,         // Production checkout URL
        sandbox_init_point: mpData.sandbox_init_point, // Test URL
        preference_id:     mpData.id,
        external_reference: externalRef,
      }),
      {
        status:  200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );

  } catch (err) {
    console.error("create-topup-intent error:", err);
    return new Response(JSON.stringify({ error: "internal server error" }), {
      status:  500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
