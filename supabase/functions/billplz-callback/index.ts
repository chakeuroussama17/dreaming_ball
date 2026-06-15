// ─────────────────────────────────────────────────────────────────────────────
// billplz-callback — Billplz server webhook. Billplz POSTs here when a bill is
// paid. We verify the X-Signature, then mark the payment + game slot as paid.
// This is the source of truth (the browser redirect can be skipped/spoofed).
//
// Set this function's deployed URL as PUBLIC_CALLBACK_URL for create-bill, and
// also as the Collection's callback URL in the Billplz dashboard.
//
// Secrets required:
//   BILLPLZ_XSIGNATURE_KEY   the X-Signature key from Billplz settings
// (SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically.)
//
// IMPORTANT: this endpoint must be deployed with --no-verify-jwt (Billplz can't
// send a Supabase JWT). The X-Signature check is what authenticates the call.
// ─────────────────────────────────────────────────────────────────────────────
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Billplz X-Signature: take all params except x_signature, build "key" + value
// for each, sort those strings ascending, join with "|", HMAC-SHA256 with the
// signature key, hex-encode, compare.
async function computeSignature(
  params: Record<string, string>,
  key: string,
): Promise<string> {
  const parts = Object.keys(params)
    .filter((k) => k !== "x_signature")
    .map((k) => `${k}${params[k]}`)
    .sort();
  const source = parts.join("|");

  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(key),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "HMAC",
    cryptoKey,
    new TextEncoder().encode(source),
  );
  return [...new Uint8Array(sig)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  try {
    // Billplz sends application/x-www-form-urlencoded.
    const raw = await req.text();
    const params: Record<string, string> = {};
    for (const [k, v] of new URLSearchParams(raw)) params[k] = v;

    const sigKey = Deno.env.get("BILLPLZ_XSIGNATURE_KEY")!;
    const expected = await computeSignature(params, sigKey);
    if (expected !== params["x_signature"]) {
      // Log both so you can compare in sandbox if the format ever differs.
      console.error("Signature mismatch", {
        expected,
        received: params["x_signature"],
      });
      return new Response("Invalid signature", { status: 401 });
    }

    const billId = params["id"];
    const paid = params["paid"] === "true";
    if (!billId) return new Response("Missing id", { status: 400 });

    const db = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: payment } = await db
      .from("payments")
      .select("id, game_id, player_id, amount, status")
      .eq("bill_id", billId)
      .maybeSingle();
    if (!payment) return new Response("Unknown bill", { status: 404 });

    // Idempotent: ignore repeat webhooks for an already-paid bill.
    if (payment.status === "paid") return new Response("OK");

    if (paid) {
      const now = new Date().toISOString();
      await db
        .from("payments")
        .update({ status: "paid", paid_at: now, method: "billplz" })
        .eq("id", payment.id);
      // Flipping payment_status fires on_player_paid → notifications.
      await db
        .from("game_players")
        .update({
          payment_status: "paid",
          payment_method: "fpx",
          amount_paid: payment.amount,
          booking_ref: billId,
          paid_at: now,
        })
        .eq("game_id", payment.game_id)
        .eq("player_id", payment.player_id);
    }

    return new Response("OK");
  } catch (e) {
    console.error("callback error", e);
    return new Response("Error", { status: 500 });
  }
});
