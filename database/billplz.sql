-- ─────────────────────────────────────────────────────────────────────────────
-- BILLPLZ PAYMENTS
--
-- Players pay the admin's Billplz account. The create-bill Edge Function
-- reserves a pending slot + creates a Billplz bill; the billplz-callback
-- Edge Function (webhook) flips it to paid. This table tracks each bill.
--
-- HOW TO RUN: Supabase Dashboard → SQL Editor → paste this → Run.
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.payments (
  id          uuid primary key default uuid_generate_v4(),
  bill_id     text unique not null,           -- Billplz bill id
  game_id     uuid not null references public.games (id) on delete cascade,
  player_id   uuid not null references public.users (id) on delete cascade,
  amount      numeric(10,2) not null,
  status      text not null default 'pending'
                check (status in ('pending', 'paid', 'failed')),
  method      text,                           -- billplz reports fpx/card later
  created_at  timestamptz not null default now(),
  paid_at     timestamptz
);

create index if not exists idx_payments_game   on public.payments (game_id);
create index if not exists idx_payments_player on public.payments (player_id);

alter table public.payments enable row level security;

-- Players read their own payments (the app polls this after returning from
-- the Billplz page). All writes happen through the Edge Functions, which use
-- the service-role key and bypass RLS — so there are no insert/update policies
-- here on purpose.
create policy "payments_read_own"
  on public.payments for select
  using (player_id = auth.uid() or public.is_admin());
