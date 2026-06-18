-- ─────────────────────────────────────────────────────────────────────────────
-- USER DEMOGRAPHICS (for analytics / ad monetization later)
--
-- Extra profile details collected at signup. Stored on public.users so they
-- apply to players and agents alike, and are visible to the admin user list.
--
-- HOW TO RUN: Supabase Dashboard → SQL Editor → paste this → Run.
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.users
  add column if not exists date_of_birth date,
  add column if not exists gender         text,
  add column if not exists country        text,  -- country of origin
  add column if not exists state          text,  -- state / region of residence
  add column if not exists city           text;  -- city / area of residence
