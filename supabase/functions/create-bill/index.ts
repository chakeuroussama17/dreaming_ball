// ─────────────────────────────────────────────────────────────────────────────
// create-bill — reserves a pending slot for the signed-in player and creates a
// Billplz bill, returning the hosted payment-page URL.
//
// The Flutter app calls this via supabase.functions.invoke('create-bill',
// body: { game_id }). The Authorization header carries the player's JWT.
//
// Secrets required (supabase secrets set ...):
//   BILLPLZ_SECRET_KEY      your Billplz API secret key
//   BILLPLZ_COLLECTION_ID   the collection bills are created under
//   BILLPLZ_BASE_URL        https://www.billplz-sandbox.com/api/v3  (sandbox)
//                           https://www.billplz.com/api/v3          (live)
//   PUBLIC_CALLBACK_URL     deployed URL of the billplz-callback function
//   PAYMENT_REDIRECT_URL    where Billplz sends the player back after paying
// (SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically.)
// ─────────────────────────────────────────────────────────────────────────────
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const { game_id } = await req.json();
    if (!game_id) return json({ error: "game_id is required" }, 400);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // Identify the caller from their JWT.
    const authHeader = req.headers.get("Authorization") ?? "";
    const userClient = createClient(supabaseUrl, serviceKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return json({ error: "Not signed in" }, 401);

    // Privileged client for the reservation + bill record.
    const db = createClient(supabaseUrl, serviceKey);

    // Load the game.
    const { data: game, error: gErr } = await db
      .from("games")
      .select("id, field_name, price, status, num_players, num_slots_filled")
      .eq("id", game_id)
      .single();
    if (gErr || !game) return json({ error: "Game not found" }, 404);
    if (game.status !== "scheduled") {
      return json({ error: "This game is no longer open for joining" }, 409);
    }

    // Already in this game?
    const { data: existing } = await db
      .from("game_players")
      .select("id, payment_status")
      .eq("game_id", game_id)
      .eq("player_id", user.id)
      .maybeSingle();

    if (existing?.payment_status === "paid") {
      return json({ error: "You have already paid for this game" }, 409);
    }

    // Reserve a pending slot if not already in.
    if (!existing) {
      if (game.num_slots_filled >= game.num_players) {
        return json({ error: "This game is full" }, 409);
      }
      const { error: insErr } = await db.from("game_players").insert({
        game_id,
        player_id: user.id,
        payment_status: "pending",
      });
      if (insErr) return json({ error: "Could not reserve a slot" }, 500);
      await db
        .from("games")
        .update({ num_slots_filled: game.num_slots_filled + 1 })
        .eq("id", game_id);
    }

    // ── Create the Billplz bill ─────────────────────────────────────────────
    const secret = Deno.env.get("BILLPLZ_SECRET_KEY")!;
    const collectionId = Deno.env.get("BILLPLZ_COLLECTION_ID")!;
    const base = Deno.env.get("BILLPLZ_BASE_URL")!;
    const callbackUrl = Deno.env.get("PUBLIC_CALLBACK_URL")!;
    const redirectUrl = Deno.env.get("PAYMENT_REDIRECT_URL")!;

    const amountCents = Math.round(Number(game.price) * 100);
    const form = new URLSearchParams({
      collection_id: collectionId,
      email: user.email ?? "player@dreamingball.app",
      name: (user.user_metadata?.full_name as string) ?? "Player",
      amount: String(amountCents),
      callback_url: callbackUrl,
      redirect_url: redirectUrl,
      description: `Boundless — ${game.field_name}`,
      reference_1_label: "game_id",
      reference_1: game_id,
      reference_2_label: "player_id",
      reference_2: user.id,
    });

    const billRes = await fetch(`${base}/bills`, {
      method: "POST",
      headers: {
        Authorization: "Basic " + btoa(`${secret}:`),
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: form,
    });
    const bill = await billRes.json();
    if (!billRes.ok || !bill.id || !bill.url) {
      return json({ error: "Billplz error", detail: bill }, 502);
    }

    // Record the bill so the webhook + the app can reconcile it.
    await db.from("payments").insert({
      bill_id: bill.id,
      game_id,
      player_id: user.id,
      amount: Number(game.price),
      status: "pending",
    });

    return json({ url: bill.url, bill_id: bill.id });
  } catch (e) {
    return json({ error: "Unexpected error", detail: String(e) }, 500);
  }
});
