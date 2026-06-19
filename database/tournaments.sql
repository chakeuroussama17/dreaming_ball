-- ─────────────────────────────────────────────────────────────────────────────
-- TOURNAMENTS MODULE — schema
--
-- Separate from regular games. An agent applies to run a tournament, admin
-- approves, the agent builds even-numbered teams from real player accounts,
-- a bracket is generated (knockout or group stage), matches are scheduled,
-- and played as TEAM-SCORE-ONLY live matches. Winners auto-advance.
--
-- HOW TO RUN: Supabase Dashboard → SQL Editor → paste → Run.
-- Then also run tournament_functions.sql (bracket advancement trigger).
--
-- STORAGE: create two PUBLIC buckets in the dashboard:
--   • tournament-banners
--   • team-logos
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. tournaments ─────────────────────────────────────────────────────────────
create table if not exists public.tournaments (
  id               uuid primary key default uuid_generate_v4(),
  agent_id         uuid not null references public.users (id) on delete cascade,
  name             text not null,
  description      text,
  game_format      text not null default '5-aside'
                     check (game_format in ('5-aside','6-aside','7-aside','11-aside')),
  mode             text not null default 'knockout'
                     check (mode in ('group_stage','knockout')),
  num_teams        integer not null
                     check (num_teams >= 4 and num_teams % 2 = 0),
  status           text not null default 'pending_approval'
                     check (status in ('pending_approval','approved','rejected',
                       'building_teams','bracket_generated','in_progress','completed')),
  approved_by      uuid references public.users (id) on delete set null,
  approved_at      timestamptz,
  rejection_reason text,
  start_date       date,
  banner_image_url text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- 2. tournament_groups (group_stage mode only) ───────────────────────────────
create table if not exists public.tournament_groups (
  id            uuid primary key default uuid_generate_v4(),
  tournament_id uuid not null references public.tournaments (id) on delete cascade,
  group_name    text not null,            -- 'A', 'B', 'C' ...
  created_at    timestamptz not null default now()
);

-- 3. tournament_teams ────────────────────────────────────────────────────────
create table if not exists public.tournament_teams (
  id            uuid primary key default uuid_generate_v4(),
  tournament_id uuid not null references public.tournaments (id) on delete cascade,
  team_name     text not null,
  team_logo_url text,
  group_id      uuid references public.tournament_groups (id) on delete set null,
  created_at    timestamptz not null default now()
);

-- 4. tournament_team_players ─────────────────────────────────────────────────
create table if not exists public.tournament_team_players (
  id            uuid primary key default uuid_generate_v4(),
  team_id       uuid not null references public.tournament_teams (id) on delete cascade,
  player_id     uuid not null references public.users (id) on delete cascade,
  position      text,
  jersey_number integer,
  added_at      timestamptz not null default now(),
  unique (team_id, player_id)
);

-- 5. tournament_matches ──────────────────────────────────────────────────────
create table if not exists public.tournament_matches (
  id             uuid primary key default uuid_generate_v4(),
  tournament_id  uuid not null references public.tournaments (id) on delete cascade,
  round_name     text not null,           -- 'Group A', 'Quarter Final', 'Final'...
  team_a_id      uuid references public.tournament_teams (id) on delete set null,
  team_b_id      uuid references public.tournament_teams (id) on delete set null,
  team_a_score   integer,
  team_b_score   integer,
  -- Scheduling: a single timestamp (date + time combined) keeps sorting and the
  -- "30 min before" window simple. The schedule screen builds it from a date +
  -- time picker, mirroring create-game / private rooms.
  scheduled_at   timestamptz,
  status         text not null default 'unscheduled'
                   check (status in ('unscheduled','scheduled','live','completed')),
  winner_team_id uuid references public.tournament_teams (id) on delete set null,
  next_match_id  uuid references public.tournament_matches (id) on delete set null,
  -- which slot of next_match this match's winner fills ('a' or 'b')
  next_slot      text check (next_slot in ('a','b')),
  group_name     text,                    -- set for group-stage matches
  round_order    integer not null default 0, -- ordering of rounds (1 = first)
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- Indexes ────────────────────────────────────────────────────────────────────
create index if not exists idx_tournaments_agent    on public.tournaments (agent_id);
create index if not exists idx_tournaments_status    on public.tournaments (status);
create index if not exists idx_t_teams_tournament    on public.tournament_teams (tournament_id);
create index if not exists idx_t_players_team        on public.tournament_team_players (team_id);
create index if not exists idx_t_matches_tournament  on public.tournament_matches (tournament_id);
create index if not exists idx_t_groups_tournament   on public.tournament_groups (tournament_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- RLS
-- ─────────────────────────────────────────────────────────────────────────────
alter table public.tournaments             enable row level security;
alter table public.tournament_groups       enable row level security;
alter table public.tournament_teams        enable row level security;
alter table public.tournament_team_players enable row level security;
alter table public.tournament_matches      enable row level security;

-- Helper note: public.is_admin() already exists (see notifications_rpc.sql).

-- tournaments: everyone reads; the organising agent creates/edits their own;
-- admin can edit any (approve/reject).
drop policy if exists "t_read" on public.tournaments;
create policy "t_read" on public.tournaments for select using (true);

drop policy if exists "t_insert_self" on public.tournaments;
create policy "t_insert_self" on public.tournaments for insert to authenticated
  with check (agent_id = auth.uid());

drop policy if exists "t_update_owner_admin" on public.tournaments;
create policy "t_update_owner_admin" on public.tournaments for update to authenticated
  using (agent_id = auth.uid() or public.is_admin())
  with check (agent_id = auth.uid() or public.is_admin());

drop policy if exists "t_delete_owner_admin" on public.tournaments;
create policy "t_delete_owner_admin" on public.tournaments for delete to authenticated
  using (agent_id = auth.uid() or public.is_admin());

-- Ownership helper used by child tables: is the caller the organising agent of
-- the given tournament?
create or replace function public.is_tournament_owner(p_tournament_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.tournaments t
    where t.id = p_tournament_id and t.agent_id = auth.uid()
  );
$$;

-- tournament_groups
drop policy if exists "tg_read" on public.tournament_groups;
create policy "tg_read" on public.tournament_groups for select using (true);
drop policy if exists "tg_manage" on public.tournament_groups;
create policy "tg_manage" on public.tournament_groups for all to authenticated
  using (public.is_tournament_owner(tournament_id))
  with check (public.is_tournament_owner(tournament_id));

-- tournament_teams
drop policy if exists "tt_read" on public.tournament_teams;
create policy "tt_read" on public.tournament_teams for select using (true);
drop policy if exists "tt_manage" on public.tournament_teams;
create policy "tt_manage" on public.tournament_teams for all to authenticated
  using (public.is_tournament_owner(tournament_id))
  with check (public.is_tournament_owner(tournament_id));

-- tournament_team_players (ownership via the team's tournament)
create or replace function public.is_team_owner(p_team_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.tournament_teams tt
    join public.tournaments t on t.id = tt.tournament_id
    where tt.id = p_team_id and t.agent_id = auth.uid()
  );
$$;

drop policy if exists "ttp_read" on public.tournament_team_players;
create policy "ttp_read" on public.tournament_team_players for select using (true);
drop policy if exists "ttp_manage" on public.tournament_team_players;
create policy "ttp_manage" on public.tournament_team_players for all to authenticated
  using (public.is_team_owner(team_id))
  with check (public.is_team_owner(team_id));

-- tournament_matches
drop policy if exists "tm_read" on public.tournament_matches;
create policy "tm_read" on public.tournament_matches for select using (true);
drop policy if exists "tm_manage" on public.tournament_matches;
create policy "tm_manage" on public.tournament_matches for all to authenticated
  using (public.is_tournament_owner(tournament_id))
  with check (public.is_tournament_owner(tournament_id));

-- Overview view: tournament + organiser + team/player counts (powers the
-- tournament list cards). Read-only; underlying tables are public-read.
create or replace view public.tournament_overview as
select
  t.*,
  u.full_name  as agent_name,
  u.avatar_url as agent_avatar_url,
  (select count(*) from public.tournament_teams tt
     where tt.tournament_id = t.id) as team_count,
  (select count(*) from public.tournament_team_players ttp
     join public.tournament_teams tt2 on tt2.id = ttp.team_id
     where tt2.tournament_id = t.id) as player_count
from public.tournaments t
join public.users u on u.id = t.agent_id;

grant select on public.tournament_overview to anon, authenticated;

-- Realtime for live match scores + bracket updates (idempotent).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'tournament_matches'
  ) then
    alter publication supabase_realtime add table public.tournament_matches;
  end if;
end $$;
