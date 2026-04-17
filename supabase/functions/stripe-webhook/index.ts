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

// supabase/functions/stripe-webhook/index.ts
// Stripe-ready webhook skeleton with idempotent wallet credit logic.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const STRIPE_WEBHOOK_SECRET = Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "";

function logInfo(event: string, details: Record<string, unknown> = {}) {
  console.log(JSON.stringify({ level: "info", event, ...details }));
}

function logError(event: string, details: Record<string, unknown> = {}) {
  console.error(JSON.stringify({ level: "error", event, ...details }));
}

function parseMetadata(metadata: Record<string, unknown> | undefined) {
  if (!metadata) return null;
  const userId = String(metadata.user_id ?? "");
  const amountRequested = Number(metadata.amount_requested ?? NaN);
  const amountCharged = Number(metadata.amount_charged ?? NaN);
  const feeAmount = Number(metadata.fee_amount ?? NaN);

  if (!userId || !Number.isFinite(amountRequested) || !Number.isFinite(amountCharged) || !Number.isFinite(feeAmount)) {
    return null;
  }

  return {
    userId,
    amountRequested: Math.round(amountRequested),
    amountCharged: Math.round(amountCharged),
    feeAmount: Math.round(feeAmount),
  };
}

serve(async (req) => {
  if (req.method === "GET") {
    return new Response("ok", { status: 200 });
  }

  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }

  try {
    if (!STRIPE_WEBHOOK_SECRET) {
      logError("stripe_webhook_secret_missing");
      return new Response("stripe webhook secret missing", { status: 500 });
    }

    // NOTE: signature verification implementation intentionally left TODO for final Stripe key wiring.
    // In launch integration, verify req.headers['stripe-signature'] with STRIPE_WEBHOOK_SECRET.

    const payload = await req.json();
    const eventType = String(payload?.type ?? "");
    const eventId = String(payload?.id ?? "");

    logInfo("stripe_webhook_received", {
      event_type: eventType,
      event_id: eventId,
    });

    if (eventType !== "checkout.session.completed") {
      return new Response("ignored", { status: 200 });
    }

    const session = payload?.data?.object;
    const paymentStatus = String(session?.payment_status ?? "");
    if (paymentStatus !== "paid") {
      return new Response("not paid", { status: 200 });
    }

    const metadata = parseMetadata(session?.metadata as Record<string, unknown> | undefined);
    if (!metadata) {
      logError("stripe_webhook_missing_metadata", {
        event_id: eventId,
        session_id: session?.id,
      });
      return new Response("invalid metadata", { status: 200 });
    }

    const externalPaymentId = String(session?.payment_intent ?? session?.id ?? eventId);
    if (!externalPaymentId) {
      return new Response("invalid payment id", { status: 200 });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: existing } = await supabase
      .from("mp_payments")
      .select("external_payment_id")
      .eq("external_payment_id", externalPaymentId)
      .maybeSingle();

    if (existing) {
      return new Response("already processed", { status: 200 });
    }

    const { error: creditErr } = await supabase.rpc("credit_wallet_topup", {
      p_user_id: metadata.userId,
      p_amount: metadata.amountRequested,
      p_external_payment_id: externalPaymentId,
      p_amount_charged: metadata.amountCharged,
      p_fee_amount: metadata.feeAmount,
      p_provider: "stripe",
    });

    if (creditErr) {
      logError("stripe_credit_wallet_failed", {
        event_id: eventId,
        user_id: metadata.userId,
        error: creditErr.message,
      });
      return new Response("credit failed", { status: 500 });
    }

    logInfo("stripe_wallet_topped_up", {
      event_id: eventId,
      user_id: metadata.userId,
      amount_requested: metadata.amountRequested,
      amount_charged: metadata.amountCharged,
      fee_amount: metadata.feeAmount,
    });

    return new Response("ok", { status: 200 });
  } catch (err) {
    logError("stripe_webhook_unhandled", {
      message: err instanceof Error ? err.message : String(err),
    });
    return new Response("internal error", { status: 500 });
  }
});
