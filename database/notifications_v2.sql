-- ─────────────────────────────────────────────────────────────────────────────
-- NOTIFICATIONS V2 — full event coverage, fired by the database itself so
-- they work even when no app is open:
--   1. Welcome on signup                        (trigger on users)
--   2. Game reminder ~2h before kickoff         (pg_cron every 10 min)
--   3. Payment confirmed → player + agent       (trigger on game_players)
--   4. Tier upgrade (Beginner → Bronze ...)     (patched confirm function)
--   5. XP awarded                               (already in confirm function)
--   6. notify_all_users_admin() for tournament / announcement blasts
--   7. Extras: player joined → agent, game full → agent,
--      game cancelled → roster
--
-- HOW TO RUN: Supabase Dashboard → SQL Editor → paste this → Run.
-- Requires notifications_rpc.sql to have been run first (it has been).
-- ─────────────────────────────────────────────────────────────────────────────


-- ── 1. WELCOME on signup ─────────────────────────────────────────────────────
create or replace function public.notify_welcome()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  insert into notifications (user_id, type, title, body)
  values (
    new.id,
    'system',
    'Welcome to Dreaming Ball ⚽',
    case when new.role = 'agent'
      then 'Complete your verification from your profile to start creating games and earning.'
      else 'Join your first game from the Home screen and start earning XP!'
    end
  );
  return new;
end $$;

drop trigger if exists on_user_welcome on public.users;
create trigger on_user_welcome
  after insert on public.users
  for each row execute function public.notify_welcome();


-- ── 2. GAME REMINDER ~2 hours before kickoff ────────────────────────────────
alter table public.games
  add column if not exists reminder_sent boolean not null default false;

create or replace function public.send_game_reminders()
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  r record;
begin
  for r in
    select g.id, g.field_name, g.location, g.kickoff, g.agent_id
    from games g
    where g.status = 'scheduled'
      and not g.reminder_sent
      and g.kickoff > now()
      and g.kickoff <= now() + interval '2 hours'
  loop
    -- every rostered player
    insert into notifications (user_id, type, title, body)
    select gp.player_id, 'game', 'Kick-off soon ⏰',
           format('%s starts at %s — see you at %s!',
                  r.field_name,
                  to_char(r.kickoff at time zone 'Asia/Kuala_Lumpur', 'HH12:MI AM'),
                  coalesce(r.location, 'the field'))
    from game_players gp
    where gp.game_id = r.id;

    -- and the agent
    insert into notifications (user_id, type, title, body)
    values (r.agent_id, 'game', 'Your game starts soon ⏰',
            format('%s kicks off at %s. Attendance opens 30 minutes before.',
                   r.field_name,
                   to_char(r.kickoff at time zone 'Asia/Kuala_Lumpur', 'HH12:MI AM')));

    update games set reminder_sent = true where id = r.id;
  end loop;
end $$;

do $$ begin
  perform cron.unschedule('game-reminders');
exception when others then null; end $$;
select cron.schedule(
  'game-reminders',
  '*/10 * * * *',
  $$select public.send_game_reminders()$$
);


-- ── 3. PAYMENT CONFIRMED → player + agent ───────────────────────────────────
create or replace function public.notify_payment()
returns trigger
language plpgsql security definer
set search_path = public
as $$
declare
  v_field text;
  v_agent uuid;
  v_name  text;
begin
  if new.payment_status = 'paid'
     and coalesce(old.payment_status, '') <> 'paid' then
    select g.field_name, g.agent_id into v_field, v_agent
    from games g where g.id = new.game_id;
    select u.full_name into v_name from users u where u.id = new.player_id;

    insert into notifications (user_id, type, title, body) values
      (new.player_id, 'payment', 'Payment confirmed ✅',
       format('Your spot at %s is locked in. See you on the pitch!',
              coalesce(v_field, 'the game'))),
      (v_agent, 'payment', 'Player paid 💰',
       format('%s paid for %s.',
              coalesce(v_name, 'A player'), coalesce(v_field, 'your game')));
  end if;
  return new;
end $$;

drop trigger if exists on_player_paid on public.game_players;
create trigger on_player_paid
  after update on public.game_players
  for each row execute function public.notify_payment();


-- ── 4 + 5. TIER UPGRADE added to the confirm function (XP was already there)
create or replace function public.confirm_pending_stats()
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  r          record;
  v_xp       integer;
  v_old_tier text;
  v_new_tier text;
begin
  for r in
    select ps.id, ps.player_id, ps.position, ps.goals, ps.assists,
           ps.goals_conceded, ps.good_behavior
    from public.player_stats ps
    where ps.status = 'pending'
      and ps.confirmed_at <= now()
  loop
    v_xp := public.calculate_xp(
      r.position, r.goals, r.assists, r.goals_conceded, r.good_behavior);

    update public.player_stats
    set status = 'confirmed', xp_earned = v_xp
    where id = r.id;

    select current_tier into v_old_tier
    from public.player_profiles where user_id = r.player_id;

    update public.player_profiles
    set total_goals        = total_goals + r.goals,
        total_assists      = total_assists + r.assists,
        total_games_played = total_games_played + 1,
        clean_sheets       = clean_sheets
                             + case when r.goals_conceded = 0 then 1 else 0 end,
        total_xp           = total_xp + v_xp,
        current_tier       = public.get_tier_from_xp(total_xp + v_xp),
        updated_at         = now()
    where user_id = r.player_id
    returning current_tier into v_new_tier;

    insert into public.notifications (user_id, type, title, body)
    values (
      r.player_id,
      'stats',
      'Match stats confirmed',
      format('You earned +%s XP — %s goals, %s assists. Keep chasing!',
             v_xp, r.goals, r.assists)
    );

    -- Tier upgrade 🎉
    if v_new_tier is distinct from v_old_tier then
      insert into public.notifications (user_id, type, title, body)
      values (
        r.player_id,
        'stats',
        format('Tier up — %s! 🏆', v_new_tier),
        format('You climbed from %s to %s. Keep going!',
               coalesce(v_old_tier, 'Beginner'), v_new_tier)
      );
    end if;
  end loop;
end $$;


-- ── 6. ADMIN BLAST — tournaments / announcements to every active user ───────
create or replace function public.notify_all_users_admin(
  p_title text,
  p_body  text,
  p_type  text default 'announcement'
) returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin only';
  end if;
  insert into notifications (user_id, type, title, body)
  select id, p_type, p_title, p_body
  from users
  where coalesce(is_banned, false) = false;
end $$;


-- ── 7a. PLAYER JOINED → agent ────────────────────────────────────────────────
create or replace function public.notify_player_joined()
returns trigger
language plpgsql security definer
set search_path = public
as $$
declare
  v_field text;
  v_agent uuid;
  v_name  text;
  v_count int;
  v_total int;
begin
  select g.field_name, g.agent_id, g.num_players
  into v_field, v_agent, v_total
  from games g where g.id = new.game_id;
  select u.full_name into v_name from users u where u.id = new.player_id;
  select count(*) into v_count
  from game_players where game_id = new.game_id;

  insert into notifications (user_id, type, title, body)
  values (v_agent, 'game', 'New player joined',
          format('%s joined %s (%s/%s).',
                 coalesce(v_name, 'A player'), coalesce(v_field, 'your game'),
                 v_count, v_total));

  -- Game full 🎉
  if v_count >= v_total then
    insert into notifications (user_id, type, title, body)
    values (v_agent, 'game', 'Your game is full 🎉',
            format('%s has all %s slots filled.',
                   coalesce(v_field, 'Your game'), v_total));
  end if;
  return new;
end $$;

drop trigger if exists on_player_joined on public.game_players;
create trigger on_player_joined
  after insert on public.game_players
  for each row execute function public.notify_player_joined();


-- ── 7b. GAME CANCELLED → whole roster ───────────────────────────────────────
create or replace function public.notify_game_cancelled()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  if new.status = 'cancelled' and old.status <> 'cancelled' then
    insert into notifications (user_id, type, title, body)
    select gp.player_id, 'game', 'Game cancelled ❌',
           format('%s on %s was cancelled by the agent.',
                  new.field_name,
                  to_char(new.kickoff at time zone 'Asia/Kuala_Lumpur',
                          'Mon DD, HH12:MI AM'))
    from game_players gp
    where gp.game_id = new.id;
  end if;
  return new;
end $$;

drop trigger if exists on_game_cancelled on public.games;
create trigger on_game_cancelled
  after update on public.games
  for each row execute function public.notify_game_cancelled();
