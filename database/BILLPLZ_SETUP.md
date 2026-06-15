# Billplz Payments — Setup Guide

Players pay **your** Billplz account. You pay agents manually (field cost +
commission) from the admin **Payouts** screen. This guide gets real payments
working end to end.

The app currently runs in **mock mode** (`PaymentConfig.billplzEnabled = false`)
so everything is testable without an account. Do the steps below, then flip
that flag to `true`.

---

## 1. Create a Billplz account (sandbox first)

1. Go to **https://www.billplz-sandbox.com** and sign up (sandbox is free, no
   business verification needed — perfect for testing).
2. After login: **Billing → Collections → New Collection**. Name it
   "Dreaming Ball". Copy the **Collection ID**.
3. **Settings → Account Settings**: copy your **API Secret Key**.
4. **Settings → X Signature**: enable it and copy the **X Signature Key**.

When you're ready for real money, repeat on **https://www.billplz.com** (the
live site, needs business/bank details) and swap the keys + base URL.

> **Payment methods (TNG priority):** which methods show on the payment page —
> FPX banks, cards, e-wallets like Touch 'n Go — is controlled in the Billplz
> dashboard under your Collection / payment gateway settings, **not** in the
> app. Enable the ones you want there and set TNG as default. (Confirm TNG
> eWallet is available on your Billplz plan; FPX + card always are.)

---

## 2. Run the SQL

In **Supabase → SQL Editor**, run (if you haven't already):

- `database/billplz.sql` — the `payments` table.

(You've already run `notifications_v2.sql`, which includes the
`on_player_paid` trigger that notifies the player + agent when a payment lands.)

---

## 3. Deploy the Edge Functions

Install the Supabase CLI if needed, then from the project root:

```bash
supabase login
supabase link --project-ref bcvkhfrdsmgtkwhrmapm

# Billplz can't send a Supabase JWT, so the callback must skip JWT verification.
supabase functions deploy create-bill
supabase functions deploy billplz-callback --no-verify-jwt
```

The callback's public URL will be:
`https://bcvkhfrdsmgtkwhrmapm.supabase.co/functions/v1/billplz-callback`

---

## 4. Set the secrets

```bash
supabase secrets set \
  BILLPLZ_SECRET_KEY="your-api-secret-key" \
  BILLPLZ_COLLECTION_ID="your-collection-id" \
  BILLPLZ_XSIGNATURE_KEY="your-x-signature-key" \
  BILLPLZ_BASE_URL="https://www.billplz-sandbox.com/api/v3" \
  PUBLIC_CALLBACK_URL="https://bcvkhfrdsmgtkwhrmapm.supabase.co/functions/v1/billplz-callback" \
  PAYMENT_REDIRECT_URL="https://bcvkhfrdsmgtkwhrmapm.supabase.co/functions/v1/billplz-callback"
```

(`PAYMENT_REDIRECT_URL` is just where the browser lands after paying — any
page is fine for now; the webhook is what actually confirms payment. Later you
can point it at a nice "thank you" page or an app deep link.)

For **live** mode later, change `BILLPLZ_BASE_URL` to
`https://www.billplz.com/api/v3` and swap in the live keys.

---

## 5. Turn it on in the app

In `lib/core/config/payment_config.dart`:

```dart
static const bool billplzEnabled = true;
```

Rebuild. Now "Join Game" → Review → **Pay RM X** opens the Billplz page; once
paid, the webhook flips the slot to paid and the app's confirmation screen
appears automatically (it polls every few seconds).

---

## How the flow works

1. Player taps **Pay** → app calls the **create-bill** function (with their
   login token).
2. The function reserves a *pending* slot, creates a Billplz bill, returns the
   payment URL. The app opens it.
3. Player pays on Billplz (TNG / DuitNow / card).
4. Billplz calls **billplz-callback** → it verifies the X-Signature → marks the
   payment + slot **paid** → the `on_player_paid` trigger notifies player + agent.
5. The app polls, sees "paid", shows the confirmation.
6. You (admin) see the collected money in **Payouts** and send the agent their
   share before kickoff.

---

## Testing in sandbox

Billplz sandbox shows a **"Pay"/"Fail"** toggle on the bill page — no real
money. Use it to simulate success and failure.

If the webhook ever logs `Signature mismatch` (Supabase → Edge Functions →
billplz-callback → Logs), send me the logged `expected` vs `received` values
and I'll correct the signature format — it's the one part I couldn't test from
here without your keys.
