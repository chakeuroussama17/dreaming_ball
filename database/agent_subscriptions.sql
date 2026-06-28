-- ─────────────────────────────────────────────────────────────────────────────
-- AGENT SUBSCRIPTIONS — game credits, plans & admin↔agent chat
--
-- Agents no longer create unlimited games. On approval they get 5 free games
-- (valid 30 days). When they run out they pick a plan in-app, which opens a
-- chat with the admin; payment is handled off-platform (bank transfer) and the
-- admin then grants the plan from the agents dashboard.
--
-- Quota model on agent_profiles:
--   • game_credits      — counted games left (BASIC/STANDARD/free trial)
--   • credits_expire_at — when those counted games lapse
--   • unlimited_until   — set for unlimited plans (PRO/ELITE/WEEKLY/...)
--   • current_plan      — label of the last granted plan
-- A game insert is allowed if unlimited_until is in the future, OR there are
-- counted credits that haven't expired (one is consumed per game).
--
-- HOW TO RUN: Supabase Dashboard → SQL Editor → paste → Run (after schema.sql).
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Quota columns ───────────────────────────────────────────────────────────
alter table public.agent_profiles
  add column if not exists game_credits      integer     not null default 0,
  add column if not exists credits_expire_at timestamptz,
  add column if not exists unlimited_until   timestamptz,
  add column if not exists current_plan      text;

-- 2. Free 5 games (30 days) the first time an agent is approved ───────────────
create or replace function public.grant_free_games_on_approval()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if NEW.status = 'approved'
     and OLD.status is distinct from 'approved'
     and NEW.current_plan is null then
    NEW.game_credits      := 5;
    NEW.credits_expire_at := now() + interval '30 days';
    NEW.current_plan      := 'free_trial';
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_grant_free_games on public.agent_profiles;
create trigger trg_grant_free_games
  before update on public.agent_profiles
  for each row execute function public.grant_free_games_on_approval();

-- 3. Enforce + consume quota on every game an agent creates ───────────────────
create or replace function public.enforce_game_quota()
returns trigger language plpgsql security definer set search_path = public as $$
declare prof public.agent_profiles%rowtype;
begin
  select * into prof from public.agent_profiles
    where user_id = NEW.agent_id for update;

  if not found then
    raise exception 'NO_AGENT_PROFILE';
  end if;

  -- Unlimited plan still active → allow, nothing to consume.
  if prof.unlimited_until is not null and prof.unlimited_until > now() then
    return NEW;
  end if;

  -- Counted credits still valid → allow and consume one.
  if prof.game_credits > 0
     and (prof.credits_expire_at is null or prof.credits_expire_at > now()) then
    update public.agent_profiles
      set game_credits = game_credits - 1
      where user_id = NEW.agent_id;
    return NEW;
  end if;

  raise exception 'NO_GAME_CREDITS';
end;
$$;

drop trigger if exists trg_enforce_game_quota on public.games;
create trigger trg_enforce_game_quota
  before insert on public.games
  for each row execute function public.enforce_game_quota();

-- 4. Admin grants a plan after off-platform payment ───────────────────────────
-- p_games/p_days come from the app's plan table; p_unlimited switches between
-- the two models. Counted credits stack; expiry windows reset to now()+days.
create or replace function public.grant_agent_plan(
  p_agent uuid, p_games integer, p_days integer,
  p_unlimited boolean, p_plan text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'admin only';
  end if;
  if p_unlimited then
    update public.agent_profiles set
      unlimited_until = now() + (p_days || ' days')::interval,
      current_plan    = p_plan,
      updated_at      = now()
    where user_id = p_agent;
  else
    update public.agent_profiles set
      game_credits      = game_credits + p_games,
      credits_expire_at = now() + (p_days || ' days')::interval,
      current_plan      = p_plan,
      updated_at        = now()
    where user_id = p_agent;
  end if;
end;
$$;

grant execute on function public.grant_agent_plan(uuid, integer, integer, boolean, text)
  to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Support chat (agent ↔ admin), one thread per agent
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.support_messages (
  id            uuid primary key default uuid_generate_v4(),
  agent_id      uuid not null references public.users (id) on delete cascade, -- thread owner
  is_admin      boolean not null default false,   -- authored by admin?
  body          text not null,
  read_by_admin boolean not null default false,
  read_by_agent boolean not null default false,
  created_at    timestamptz not null default now()
);

create index if not exists idx_support_messages_agent
  on public.support_messages (agent_id, created_at);

alter table public.support_messages enable row level security;

drop policy if exists sm_select on public.support_messages;
drop policy if exists sm_insert on public.support_messages;
drop policy if exists sm_update on public.support_messages;

-- Agent sees only their own thread; admin sees every thread.
create policy sm_select on public.support_messages for select to authenticated
  using (agent_id = auth.uid() or public.is_admin());

-- Agent posts to their own thread (is_admin=false); admin posts as admin.
create policy sm_insert on public.support_messages for insert to authenticated
  with check (
    (is_admin = false and agent_id = auth.uid())
    or (is_admin = true and public.is_admin())
  );

-- Marking messages read.
create policy sm_update on public.support_messages for update to authenticated
  using (agent_id = auth.uid() or public.is_admin())
  with check (agent_id = auth.uid() or public.is_admin());

-- Admin inbox: one row per agent thread with the latest message + unread count.
create or replace function public.admin_support_threads()
returns table (
  agent_id  uuid,
  full_name text,
  last_body text,
  last_at   timestamptz,
  unread    integer
) language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'admin only';
  end if;
  return query
    select m.agent_id,
           u.full_name,
           (array_agg(m.body order by m.created_at desc))[1],
           max(m.created_at),
           count(*) filter (where m.is_admin = false and m.read_by_admin = false)::int
    from public.support_messages m
    join public.users u on u.id = m.agent_id
    group by m.agent_id, u.full_name
    order by max(m.created_at) desc;
end;
$$;

grant execute on function public.admin_support_threads() to authenticated;

-- Realtime so chats update live.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'support_messages'
  ) then
    alter publication supabase_realtime add table public.support_messages;
  end if;
end $$;
