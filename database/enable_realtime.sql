-- ─────────────────────────────────────────────────────────────────────────────
-- ENABLE REALTIME on the tables the app subscribes to:
--   games             → game detail slot counter, status changes
--   live_match_stats  → players watching the agent's live stat edits
--   room_players      → private room roster growing live
--
-- Safe to run repeatedly — tables already in the publication are skipped.
-- HOW TO RUN: Supabase Dashboard → SQL Editor → paste this → Run.
-- Verify after: the query at the bottom should list all three tables.
-- ─────────────────────────────────────────────────────────────────────────────
do $$
declare
  t text;
begin
  foreach t in array array['games', 'live_match_stats', 'room_players'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- Shows which tables are realtime-enabled (expect the three above):
select tablename
from pg_publication_tables
where pubname = 'supabase_realtime' and schemaname = 'public'
order by tablename;
