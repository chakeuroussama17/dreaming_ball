-- ─────────────────────────────────────────────────────────────────────────────
-- TERMS OF USE — consent record
--
-- Records which version of the Terms of Use each user accepted at registration,
-- and when. Gives you proof of agreement (version + timestamp) per user.
--
-- HOW TO RUN: Supabase Dashboard → SQL Editor → paste → Run.
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.users
  add column if not exists terms_version     text,
  add column if not exists terms_accepted_at timestamptz;
