-- ─────────────────────────────────────────────────────────────────────────────
-- PRIVATE ROOM SCHEDULE
--
-- Gives private rooms a match date/time so the app can tell upcoming rooms from
-- finished ones. A room is considered "ended" 2 hours after scheduled_at
-- (that rule lives in the app, so no status column is needed).
--
-- HOW TO RUN: Supabase Dashboard → SQL Editor → paste → Run. Safe to re-run.
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.private_rooms
  add column if not exists scheduled_at timestamptz;
