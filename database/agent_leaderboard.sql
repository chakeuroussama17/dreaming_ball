-- ─────────────────────────────────────────────────────────────────────────────
-- ADMIN: AGENT LEADERBOARD
--
-- Per-agent performance for the admin panel: games created, confirmed players,
-- money collected, and realized commission — ranked by commission so the admin
-- can spot the top-earning agents.
--
-- Money model (no platform cut): each player pays (pitch + commission)/players.
-- So per confirmed (paid) player:
--   collected  += price
--   commission += commission / num_players
--
-- HOW TO RUN: Supabase Dashboard → SQL Editor → paste this → Run.
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.agent_leaderboard()
returns table (
  agent_id          uuid,
  full_name         text,
  games_created     bigint,
  players_confirmed bigint,
  collected         numeric,
  commission        numeric
)
language plpgsql security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin only';
  end if;

  return query
  select
    g.agent_id,
    u.full_name,
    count(distinct g.id) as games_created,
    count(gp.id) filter (where gp.payment_status = 'paid') as players_confirmed,
    coalesce(sum(g.price)
             filter (where gp.payment_status = 'paid'), 0) as collected,
    coalesce(sum(g.commission / nullif(g.num_players, 0))
             filter (where gp.payment_status = 'paid'), 0) as commission
  from public.games g
  join public.users u on u.id = g.agent_id
  left join public.game_players gp on gp.game_id = g.id
  group by g.agent_id, u.full_name
  order by commission desc, collected desc;
end;
$$;

grant execute on function public.agent_leaderboard() to authenticated;
