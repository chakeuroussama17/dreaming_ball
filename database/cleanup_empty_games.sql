-- ─────────────────────────────────────────────────────────────────────────────
-- AUTO-CLEANUP OF ABANDONED GAMES
--
-- A scheduled game whose kick-off has passed with nobody joined is dead weight:
-- it lingers in the agent's "Starting Soon" panel forever. This removes them.
--
-- Safe to expose: it only ever deletes games that are still 'scheduled', have
-- zero players, and whose kick-off is already in the past. Games with players,
-- live/finished games, and future games are never touched.
--
-- The app calls this (via the cleanup_empty_games RPC) whenever the feed loads,
-- so cleanup happens without any cron setup. If you also want a server-side
-- safety net, schedule it with pg_cron (commented out at the bottom).
--
-- HOW TO RUN: Supabase Dashboard → SQL Editor → paste this → Run.
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.cleanup_empty_games()
returns integer
language plpgsql security definer
set search_path = public
as $$
declare
  v_deleted integer;
begin
  with gone as (
    delete from public.games
    where status = 'scheduled'
      and num_slots_filled = 0
      and kickoff < now()
    returning id
  )
  select count(*) into v_deleted from gone;
  return v_deleted;
end;
$$;

-- Let any signed-in client trigger the cleanup (it can only remove abandoned
-- games, never anything that matters).
grant execute on function public.cleanup_empty_games() to authenticated, anon;

-- Optional server-side safety net (requires the pg_cron extension):
-- select cron.schedule('cleanup-empty-games', '*/30 * * * *',
--   $$ select public.cleanup_empty_games(); $$);
