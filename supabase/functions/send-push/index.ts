// send-push — delivers a push notification to a user's devices via FCM HTTP v1.
//
// Triggered by a Supabase Database Webhook on `notifications` INSERT (so every
// in-app notification also becomes a device push). It can also be invoked
// directly with { user_id, title, body, type }.
//
// Secrets required (set with `supabase secrets set`):
//   FCM_PROJECT_ID         — your Firebase project id (e.g. dreaming-ball-1234)
//   FCM_SERVICE_ACCOUNT    — the full service-account JSON (one line), from
//                            Firebase → Project settings → Service accounts →
//                            Generate new private key.
//   SUPABASE_URL           — auto-provided in the Functions runtime
//   SUPABASE_SERVICE_ROLE_KEY — auto-provided in the Functions runtime
//
// Deploy:  supabase functions deploy send-push
//
// See FIREBASE_SETUP.md for the full walkthrough.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface Notification {
  user_id: string;
  title?: string;
  body?: string;
  type?: string;
}

// ── Mint a short-lived OAuth token from the service account ──────────────────
async function getAccessToken(serviceAccount: {
  client_email: string;
  private_key: string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claim = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const enc = (obj: unknown) =>
    btoa(JSON.stringify(obj)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const unsigned = `${enc(header)}.${enc(claim)}`;

  // Import the PEM private key and RS256-sign the JWT.
  const pem = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${
    btoa(String.fromCharCode(...new Uint8Array(sig)))
      .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_")
  }`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const json = await res.json();
  if (!json.access_token) {
    throw new Error(`OAuth failed: ${JSON.stringify(json)}`);
  }
  return json.access_token;
}

Deno.serve(async (req) => {
  try {
    const payload = await req.json();
    // Database Webhook sends { type, table, record, ... }; direct calls send
    // the notification fields at the top level.
    const note: Notification = payload.record ?? payload;
    if (!note?.user_id) {
      return new Response("no user_id", { status: 200 });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: tokens } = await supabase
      .from("device_tokens")
      .select("token")
      .eq("user_id", note.user_id);

    if (!tokens || tokens.length === 0) {
      return new Response("no devices", { status: 200 });
    }

    const serviceAccount = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);
    const projectId = Deno.env.get("FCM_PROJECT_ID")!;
    const accessToken = await getAccessToken(serviceAccount);

    const url =
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    const results = await Promise.all(
      tokens.map(async ({ token }) => {
        const message = {
          message: {
            token,
            notification: {
              title: note.title ?? "Dreaming Ball",
              body: note.body ?? "",
            },
            data: { type: note.type ?? "system" },
            android: {
              priority: "high",
              notification: { channel_id: "dreaming_ball_default" },
            },
          },
        };
        const r = await fetch(url, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(message),
        });
        // Clean up tokens FCM reports as dead so we stop pushing to them.
        if (r.status === 404 || r.status === 400) {
          await supabase.from("device_tokens").delete().eq("token", token);
        }
        return r.status;
      }),
    );

    return new Response(JSON.stringify({ sent: results }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("send-push error", e);
    return new Response(`error: ${e}`, { status: 500 });
  }
});
