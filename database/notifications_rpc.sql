-- ─────────────────────────────────────────────────────────────────────────────
-- IN-APP NOTIFICATIONS
--
-- Clients can't insert notifications for other users (RLS — by design).
-- These security-definer functions do it safely, each with a guard that the
-- caller actually has the right to notify the target:
--   notify_game_players  agent → everyone on their game's roster
--   notify_game_agent    rostered player → the game's agent
--   notify_player        agent → one rostered player of their game
--   notify_user_admin    admin → anyone
-- Also adds the notifications table to the realtime publication so the bell
-- badge updates live.
--
-- HOW TO RUN: Supabase Dashboard → SQL Editor → paste this → Run.
-- ─────────────────────────────────────────────────────────────────────────────

-- Agent → their game's roster (excluding themselves if they also play).
create or replace function public.notify_game_players(
  p_game_id uuid,
  p_title   text,
  p_body    text,
  p_type    text default 'game'
) returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from games where id = p_game_id and agent_id = auth.uid()
  ) then
    raise exception 'Only the game agent can notify its players';
  end if;
  insert into notifications (user_id, type, title, body)
  select gp.player_id, p_type, p_title, p_body
  from game_players gp
  where gp.game_id = p_game_id
    and gp.player_id <> auth.uid();
end $$;

-- Rostered player → the game's agent (e.g. a dispute was raised).
create or replace function public.notify_game_agent(
  p_game_id uuid,
  p_title   text,
  p_body    text,
  p_type    text default 'dispute'
) returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from game_players
    where game_id = p_game_id and player_id = auth.uid()
  ) then
    raise exception 'Only players of this game can notify its agent';
  end if;
  insert into notifications (user_id, type, title, body)
  select g.agent_id, p_type, p_title, p_body
  from games g where g.id = p_game_id;
end $$;

-- Agent → one rostered player of their game (e.g. dispute resolved).
create or replace function public.notify_player(
  p_game_id   uuid,
  p_player_id uuid,
  p_title     text,
  p_body      text,
  p_type      text default 'dispute'
) returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from games where id = p_game_id and agent_id = auth.uid()
  ) then
    raise exception 'Only the game agent can notify its players';
  end if;
  if not exists (
    select 1 from game_players
    where game_id = p_game_id and player_id = p_player_id
  ) then
    raise exception 'Target is not in this game';
  end if;
  insert into notifications (user_id, type, title, body)
  values (p_player_id, p_type, p_title, p_body);
end $$;

-- Admin → anyone (agent approved/rejected, bans, announcements...).
create or replace function public.notify_user_admin(
  p_user_id uuid,
  p_title   text,
  p_body    text,
  p_type    text default 'system'
) returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin only';
  end if;
  insert into notifications (user_id, type, title, body)
  values (p_user_id, p_type, p_title, p_body);
end $$;

-- Realtime for the live bell badge (idempotent).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;
