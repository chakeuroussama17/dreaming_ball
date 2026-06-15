-- ═══════════════════════════════════════════════════════════════════════════
-- DREAMING BALL — Complete Supabase schema
-- Generated from the Flutter codebase (lib/core/providers + feature screens).
-- Run this once in the Supabase SQL editor (or psql) on a fresh project.
-- ═══════════════════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────────────────────
-- 1. EXTENSIONS
-- ─────────────────────────────────────────────────────────────────────────────
create extension if not exists "uuid-ossp";
create extension if not exists pg_cron;


-- ─────────────────────────────────────────────────────────────────────────────
-- HELPER FUNCTIONS (used by RLS policies below)
-- ─────────────────────────────────────────────────────────────────────────────

-- Hardcoded admin, mirrors AuthService in the app. The admin logs in as
-- chakeur@gmail.com but the backing Supabase session uses the
-- admin.dreamingball@gmail.com account (see fix_admin.sql).
create or replace function public.is_admin()
returns boolean
language sql stable
set search_path = public
as $$
  select coalesce(auth.jwt() ->> 'email', '')
         in ('chakeur@gmail.com', 'admin.dreamingball@gmail.com');
$$;

-- Generic updated_at maintenance.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 2. TABLES
-- ─────────────────────────────────────────────────────────────────────────────

-- users — mirrors register_screen.dart (full name, email, phone, role)
-- and user_management_screen.dart (banned flag).
-- id matches auth.users.id so auth.uid() works directly in policies.
create table public.users (
  id            uuid primary key references auth.users (id) on delete cascade,
  full_name     text not null,
  email         text not null unique,
  phone         text,
  role          text not null default 'player'
                  check (role in ('player', 'agent')),
  avatar_url    text,
  is_banned     boolean not null default false,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- player_profiles — mirrors edit_profile_screen.dart (position, age group),
-- tier_badge.dart (PlayerTier enum) and player_stat_card.dart totals.
create table public.player_profiles (
  id                  uuid primary key default uuid_generate_v4(),
  user_id             uuid not null unique references public.users (id) on delete cascade,
  position            text not null default 'Striker'
                        check (position in ('GK', 'Defender', 'Midfielder', 'Striker')),
  age_group           text default '21-25'
                        check (age_group in ('Under 16', '16-20', '21-25', '26-30', '30+')),
  total_xp            integer not null default 0 check (total_xp >= 0),
  current_tier        text not null default 'Beginner'
                        check (current_tier in ('Beginner', 'Bronze', 'Silver', 'Gold',
                                                'Platinum', 'Diamond', 'Elite', 'Legend')),
  total_goals         integer not null default 0,
  total_assists       integer not null default 0,
  total_games_played  integer not null default 0,
  clean_sheets        integer not null default 0,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- agent_profiles — mirrors the verification form in profile_screen.dart
-- (MyKad/Passport + DuitNow bank) and AgentRecord in admin_providers.dart.
-- AgentVerification.notSubmitted + AdminAgentStatus merge into one status.
create table public.agent_profiles (
  id                    uuid primary key default uuid_generate_v4(),
  user_id               uuid not null unique references public.users (id) on delete cascade,
  id_type               text check (id_type in ('MyKad', 'Passport')),
  id_number             text,
  id_front_url          text,   -- file in kyc-documents bucket
  id_back_url           text,   -- MyKad only
  bank_name             text,   -- DuitNow-supporting Malaysian bank
  account_number        text,
  account_holder        text,
  status                text not null default 'not_submitted'
                          check (status in ('not_submitted', 'pending', 'approved',
                                            'rejected', 'suspended')),
  rejection_reason      text,
  total_earnings        numeric(10,2) not null default 0,
  total_games_organized integer not null default 0,
  verified_at           timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

-- games — mirrors Game in games_provider.dart. live/ended booleans become a
-- status column; mine becomes agent_id; photo bytes become photo_url.
create table public.games (
  id                uuid primary key default uuid_generate_v4(),
  agent_id          uuid not null references public.users (id) on delete cascade,
  field_name        text not null,
  location          text not null,
  format            text not null
                      check (format in ('5-aside', '6-aside', '7-aside', '11-aside')),
  kickoff           timestamptz not null,
  age_group         text not null default 'Open',
  details           text,
  contact           text,
  num_players       integer not null check (num_players >= 4),     -- totalSlots
  num_slots_filled  integer not null default 0
                      check (num_slots_filled >= 0 and num_slots_filled <= num_players),
  price             numeric(10,2) not null,      -- per-player, auto-calculated
  field_cost        numeric(10,2) not null,      -- pitch rental the agent pays
  commission        numeric(10,2) not null default 0,
  photo_url         text,
  status            text not null default 'scheduled'
                      check (status in ('scheduled', 'live', 'completed', 'cancelled')),
  is_private        boolean not null default false,
  invite_code       text unique,                 -- private games only
  started_at        timestamptz,
  ended_at          timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

-- game_players — who joined & paid (joined flag + payment_screen.dart:
-- method Card/FPX/E-Wallet, booking ref, paid date).
create table public.game_players (
  id              uuid primary key default uuid_generate_v4(),
  game_id         uuid not null references public.games (id) on delete cascade,
  player_id       uuid not null references public.users (id) on delete cascade,
  payment_status  text not null default 'pending'
                    check (payment_status in ('pending', 'paid', 'refunded')),
  payment_method  text check (payment_method in ('card', 'fpx', 'ewallet')),
  amount_paid     numeric(10,2),
  booking_ref     text,
  paid_at         timestamptz,
  joined_at       timestamptz not null default now(),
  unique (game_id, player_id)
);

-- live_match_stats — mirrors _LivePlayer in live_match_screen.dart:
-- per-player goals / assists / goals_conceded (subjective) / good_behavior,
-- plus the attendance checkbox. Updated in realtime by the agent.
create table public.live_match_stats (
  id              uuid primary key default uuid_generate_v4(),
  game_id         uuid not null references public.games (id) on delete cascade,
  player_id       uuid not null references public.users (id) on delete cascade,
  is_present      boolean not null default true,
  goals           integer not null default 0 check (goals >= 0),
  assists         integer not null default 0 check (assists >= 0),
  goals_conceded  integer not null default 0 check (goals_conceded >= 0),
  good_behavior   integer not null default 1 check (good_behavior in (0, 1)),
  updated_at      timestamptz not null default now(),
  unique (game_id, player_id)
);

-- player_stats — final stats submitted at "Submit Stats". status stays
-- 'pending' for the 3-hour dispute window; confirmed_at holds the moment the
-- row becomes confirmable (now() + 3h on insert), then the cron confirms it.
create table public.player_stats (
  id              uuid primary key default uuid_generate_v4(),
  game_id         uuid not null references public.games (id) on delete cascade,
  player_id       uuid not null references public.users (id) on delete cascade,
  position        text not null
                    check (position in ('GK', 'Defender', 'Midfielder', 'Striker')),
  goals           integer not null default 0 check (goals >= 0),
  assists         integer not null default 0 check (assists >= 0),
  goals_conceded  integer not null default 0 check (goals_conceded >= 0),
  good_behavior   integer not null default 1 check (good_behavior in (0, 1)),
  xp_earned       integer,
  status          text not null default 'pending'
                    check (status in ('pending', 'confirmed', 'disputed')),
  confirmed_at    timestamptz not null default (now() + interval '3 hours'),
  created_at      timestamptz not null default now(),
  unique (game_id, player_id)
);

-- disputes — mirrors _Dispute (dispute_screen.dart) and AdminDispute
-- (admin_providers.dart): stat type, recorded vs claimed, reason, status.
create table public.disputes (
  id              uuid primary key default uuid_generate_v4(),
  player_stats_id uuid not null references public.player_stats (id) on delete cascade,
  game_id         uuid not null references public.games (id) on delete cascade,
  player_id       uuid not null references public.users (id) on delete cascade,
  agent_id        uuid not null references public.users (id) on delete cascade,
  stat_type       text not null
                    check (stat_type in ('goals', 'assists', 'goals_conceded', 'good_behavior')),
  recorded_value  integer not null,
  claimed_value   integer not null,
  reason          text not null,
  status          text not null default 'open'
                    check (status in ('open', 'resolved', 'escalated')),
  resolution      text,           -- e.g. 'accepted_player' | 'kept_agent'
  created_at      timestamptz not null default now(),
  resolved_at     timestamptz
);

-- agent_ratings — players rate the agent after a game (1–5 stars).
create table public.agent_ratings (
  id          uuid primary key default uuid_generate_v4(),
  agent_id    uuid not null references public.users (id) on delete cascade,
  player_id   uuid not null references public.users (id) on delete cascade,
  game_id     uuid not null references public.games (id) on delete cascade,
  rating      integer not null check (rating between 1 and 5),
  comment     text,
  created_at  timestamptz not null default now(),
  unique (game_id, player_id)
);

-- private_rooms — mirrors private_room_screen.dart (room name, location,
-- max players, 6-char shareable code).
create table public.private_rooms (
  id          uuid primary key default uuid_generate_v4(),
  creator_id  uuid not null references public.users (id) on delete cascade,
  name        text not null,
  location    text,
  max_players integer not null default 10 check (max_players >= 2),
  code        text not null unique check (char_length(code) = 6),
  created_at  timestamptz not null default now()
);

-- room_players — mirrors _RoomMember in room_detail_screen.dart.
create table public.room_players (
  id          uuid primary key default uuid_generate_v4(),
  room_id     uuid not null references public.private_rooms (id) on delete cascade,
  player_id   uuid not null references public.users (id) on delete cascade,
  joined_at   timestamptz not null default now(),
  unique (room_id, player_id)
);

-- announcements — mirrors Announcement + BadgeType in admin_providers.dart.
create table public.announcements (
  id          uuid primary key default uuid_generate_v4(),
  title       text not null,
  subtitle    text not null,
  badge       text not null
                check (badge in ('tournament', 'promo', 'news', 'update')),
  photo_url   text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

-- notifications — mirrors _Notif in notifications_screen.dart.
create table public.notifications (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references public.users (id) on delete cascade,
  type        text not null default 'system'
                check (type in ('game', 'stats', 'dispute', 'payment',
                                'announcement', 'system')),
  title       text not null,
  body        text not null,
  is_read     boolean not null default false,
  created_at  timestamptz not null default now()
);

-- agent_bans — audit log of agent suspensions issued by the admin panel.
create table public.agent_bans (
  id          uuid primary key default uuid_generate_v4(),
  agent_id    uuid not null references public.users (id) on delete cascade,
  reason      text not null,
  banned_by   uuid references public.users (id) on delete set null,
  created_at  timestamptz not null default now(),
  lifted_at   timestamptz
);


-- ─────────────────────────────────────────────────────────────────────────────
-- 3. updated_at TRIGGERS (constraints are inline above)
-- ─────────────────────────────────────────────────────────────────────────────
create trigger users_updated_at            before update on public.users            for each row execute function public.set_updated_at();
create trigger player_profiles_updated_at  before update on public.player_profiles  for each row execute function public.set_updated_at();
create trigger agent_profiles_updated_at   before update on public.agent_profiles   for each row execute function public.set_updated_at();
create trigger games_updated_at            before update on public.games            for each row execute function public.set_updated_at();
create trigger live_match_stats_updated_at before update on public.live_match_stats for each row execute function public.set_updated_at();


-- ─────────────────────────────────────────────────────────────────────────────
-- 4. INDEXES
-- ─────────────────────────────────────────────────────────────────────────────

-- Foreign keys
create index idx_player_profiles_user_id   on public.player_profiles (user_id);
create index idx_agent_profiles_user_id    on public.agent_profiles (user_id);
create index idx_games_agent_id            on public.games (agent_id);
create index idx_game_players_game_id      on public.game_players (game_id);
create index idx_game_players_player_id    on public.game_players (player_id);
create index idx_live_stats_game_id        on public.live_match_stats (game_id);
create index idx_live_stats_player_id      on public.live_match_stats (player_id);
create index idx_player_stats_game_id      on public.player_stats (game_id);
create index idx_player_stats_player_id    on public.player_stats (player_id);
create index idx_disputes_player_stats_id  on public.disputes (player_stats_id);
create index idx_disputes_game_id          on public.disputes (game_id);
create index idx_disputes_player_id        on public.disputes (player_id);
create index idx_disputes_agent_id         on public.disputes (agent_id);
create index idx_agent_ratings_agent_id    on public.agent_ratings (agent_id);
create index idx_agent_ratings_game_id     on public.agent_ratings (game_id);
create index idx_private_rooms_creator_id  on public.private_rooms (creator_id);
create index idx_room_players_room_id      on public.room_players (room_id);
create index idx_room_players_player_id    on public.room_players (player_id);
create index idx_notifications_user_id     on public.notifications (user_id, is_read);
create index idx_agent_bans_agent_id       on public.agent_bans (agent_id);

-- Status columns
create index idx_games_status              on public.games (status);
create index idx_agent_profiles_status     on public.agent_profiles (status);
create index idx_disputes_status           on public.disputes (status);
create index idx_game_players_pay_status   on public.game_players (payment_status);
-- Partial index: exactly what the confirm-pending-stats cron scans.
create index idx_player_stats_pending      on public.player_stats (confirmed_at)
                                           where status = 'pending';

-- Date columns
create index idx_games_kickoff             on public.games (kickoff);
create index idx_notifications_created_at  on public.notifications (created_at desc);
create index idx_announcements_active      on public.announcements (is_active, created_at desc);

-- Leaderboard
create index idx_player_profiles_total_xp  on public.player_profiles (total_xp desc);

-- Private game / room code lookup
create index idx_games_invite_code         on public.games (invite_code) where invite_code is not null;
create index idx_private_rooms_code        on public.private_rooms (code);


-- ─────────────────────────────────────────────────────────────────────────────
-- 5. FUNCTIONS
-- ─────────────────────────────────────────────────────────────────────────────

-- XP for one game, per position. Mirrors the agreed formula:
--   goal:   Striker 10 · Midfielder 10 · Defender 12 · GK 16
--   assist: Striker 5  · Midfielder 5  · Defender 5  · GK 7
--   good behavior: +20 if 1, -10 if 0
--   goals conceded bonus:
--     0–2:  Striker 2 · Mid 3 · Defender 5 · GK 8
--     3–6:  Striker 1 · Mid 1 · Defender 3 · GK 4
--     7+:   Striker 0 · Mid 0 · Defender 1 · GK 2
--   floor: 5 XP (attendance)
create or replace function public.calculate_xp(
  p_position       text,
  p_goals          integer,
  p_assists        integer,
  p_goals_conceded integer,
  p_good_behavior  integer
) returns integer
language plpgsql immutable
as $$
declare
  v_goal_pts   integer;
  v_assist_pts integer;
  v_gc_bonus   integer;
  v_gb_bonus   integer;
  v_total      integer;
begin
  case p_position
    when 'Striker'    then v_goal_pts := 10; v_assist_pts := 5;
    when 'Midfielder' then v_goal_pts := 10; v_assist_pts := 5;
    when 'Defender'   then v_goal_pts := 12; v_assist_pts := 5;
    when 'GK'         then v_goal_pts := 16; v_assist_pts := 7;
    else                   v_goal_pts := 10; v_assist_pts := 5;
  end case;

  if p_goals_conceded >= 0 and p_goals_conceded < 3 then
    v_gc_bonus := case p_position
      when 'Striker' then 2 when 'Midfielder' then 3
      when 'Defender' then 5 when 'GK' then 8 else 2 end;
  elsif p_goals_conceded >= 3 and p_goals_conceded <= 6 then
    v_gc_bonus := case p_position
      when 'Striker' then 1 when 'Midfielder' then 1
      when 'Defender' then 3 when 'GK' then 4 else 1 end;
  else -- more than 6 conceded
    v_gc_bonus := case p_position
      when 'Striker' then 0 when 'Midfielder' then 0
      when 'Defender' then 1 when 'GK' then 2 else 0 end;
  end if;

  v_gb_bonus := case when p_good_behavior = 1 then 20 else -10 end;

  v_total := p_goals * v_goal_pts
           + p_assists * v_assist_pts
           + v_gc_bonus
           + v_gb_bonus;

  return greatest(v_total, 5);  -- attendance floor
end;
$$;

-- Tier from lifetime XP. Mirrors PlayerTier in tier_badge.dart.
create or replace function public.get_tier_from_xp(xp integer)
returns text
language sql immutable
as $$
  select case
    when xp >= 3000 then 'Legend'
    when xp >= 2000 then 'Elite'
    when xp >= 1500 then 'Diamond'
    when xp >= 1000 then 'Platinum'
    when xp >= 600  then 'Gold'
    when xp >= 300  then 'Silver'
    when xp >= 100  then 'Bronze'
    else                 'Beginner'
  end;
$$;

-- Confirms every pending stat line whose 3-hour dispute window has passed:
-- awards XP, rolls totals into the player profile, recomputes the tier and
-- notifies the player. Called by the pg_cron job below.
create or replace function public.confirm_pending_stats()
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  r     record;
  v_xp  integer;
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

    update public.player_profiles
    set total_goals        = total_goals + r.goals,
        total_assists      = total_assists + r.assists,
        total_games_played = total_games_played + 1,
        clean_sheets       = clean_sheets
                             + case when r.goals_conceded = 0 then 1 else 0 end,
        total_xp           = total_xp + v_xp,
        current_tier       = public.get_tier_from_xp(total_xp + v_xp),
        updated_at         = now()
    where user_id = r.player_id;

    insert into public.notifications (user_id, type, title, body)
    values (
      r.player_id,
      'stats',
      'Match stats confirmed',
      format('You earned +%s XP — %s goals, %s assists. Keep chasing!',
             v_xp, r.goals, r.assists)
    );
  end loop;
end;
$$;

-- Race-safe join: locks the game row so two players grabbing the last slot
-- can't both get in. Call via supabase.rpc('join_game_safe', {...}).
create or replace function public.join_game_safe(
  p_game_id   uuid,
  p_player_id uuid
) returns json
language plpgsql security definer
set search_path = public
as $$
declare
  v_game public.games%rowtype;
begin
  if p_player_id <> auth.uid() then
    return json_build_object('success', false, 'error', 'You can only join for yourself');
  end if;

  select * into v_game
  from public.games
  where id = p_game_id
  for update;  -- lock: serializes concurrent joins on this game

  if not found then
    return json_build_object('success', false, 'error', 'Game not found');
  end if;

  if v_game.status <> 'scheduled' then
    return json_build_object('success', false, 'error', 'Game is not open for joining');
  end if;

  if v_game.num_slots_filled >= v_game.num_players then
    return json_build_object('success', false, 'error', 'Game is full');
  end if;

  if exists (
    select 1 from public.game_players
    where game_id = p_game_id and player_id = p_player_id
  ) then
    return json_build_object('success', false, 'error', 'Already joined this game');
  end if;

  insert into public.game_players (game_id, player_id)
  values (p_game_id, p_player_id);

  update public.games
  set num_slots_filled = num_slots_filled + 1
  where id = p_game_id;

  return json_build_object('success', true);
end;
$$;

-- Unique 6-char room code. Uppercase letters + digits, skipping the
-- confusable 0, O, I and 1. Loops until the code is free.
create or replace function public.generate_room_code()
returns text
language plpgsql volatile
set search_path = public
as $$
declare
  chars  constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code text;
begin
  loop
    v_code := '';
    for i in 1..6 loop
      v_code := v_code || substr(chars, 1 + floor(random() * length(chars))::int, 1);
    end loop;

    exit when not exists (
      select 1 from public.private_rooms where code = v_code
    );
  end loop;

  return v_code;
end;
$$;

-- Invite-code lookup for private games (RLS hides them from normal selects,
-- so the client fetches a private game through this instead).
create or replace function public.get_game_by_code(p_code text)
returns setof public.games
language sql stable security definer
set search_path = public
as $$
  select * from public.games where invite_code = upper(p_code);
$$;

-- After a row lands in public.users: every user gets a player profile
-- (everyone starts at Beginner and plays), agents also get an agent profile
-- starting at not_submitted (verification gate for create-game).
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  insert into public.player_profiles (user_id)
  values (new.id);

  if new.role = 'agent' then
    insert into public.agent_profiles (user_id)
    values (new.id);
  end if;

  return new;
end;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 6. TRIGGERS
-- ─────────────────────────────────────────────────────────────────────────────
create trigger on_user_created
  after insert on public.users
  for each row execute function public.handle_new_user();


-- ─────────────────────────────────────────────────────────────────────────────
-- 7. CRON JOB — confirm stats whose 3-hour dispute window has closed
-- ─────────────────────────────────────────────────────────────────────────────
select cron.schedule(
  'confirm-pending-stats',
  '*/15 * * * *',
  $$select public.confirm_pending_stats()$$
);


-- ─────────────────────────────────────────────────────────────────────────────
-- 8. STORAGE BUCKETS
-- ─────────────────────────────────────────────────────────────────────────────
insert into storage.buckets (id, name, public) values
  ('avatars',       'avatars',       true),
  ('field-photos',  'field-photos',  true),
  ('announcements', 'announcements', true),
  ('kyc-documents', 'kyc-documents', false)
on conflict (id) do nothing;

-- Storage policies: public buckets are world-readable; uploads go into a
-- folder named after the uploader's uid. KYC documents are owner+admin only.
create policy "Public read for public buckets"
  on storage.objects for select
  using (bucket_id in ('avatars', 'field-photos', 'announcements'));

create policy "Users upload to own folder in public buckets"
  on storage.objects for insert to authenticated
  with check (
    bucket_id in ('avatars', 'field-photos', 'announcements')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users update own files in public buckets"
  on storage.objects for update to authenticated
  using (
    bucket_id in ('avatars', 'field-photos', 'announcements')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users upload own KYC documents"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'kyc-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Owner or admin reads KYC documents"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'kyc-documents'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin())
  );


-- ─────────────────────────────────────────────────────────────────────────────
-- 9. ROW LEVEL SECURITY
-- ─────────────────────────────────────────────────────────────────────────────

-- Approved agents are the only users allowed to create games
-- (mirrors canCreateGamesProvider in the app).
create or replace function public.is_approved_agent()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.agent_profiles
    where user_id = auth.uid() and status = 'approved'
  );
$$;

-- Membership check for room_players policies. SECURITY DEFINER so the
-- policy doesn't query room_players under its own RLS (infinite recursion).
create or replace function public.is_room_member(p_room_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.room_players
    where room_id = p_room_id and player_id = auth.uid()
  );
$$;

alter table public.users            enable row level security;
alter table public.player_profiles  enable row level security;
alter table public.agent_profiles   enable row level security;
alter table public.games            enable row level security;
alter table public.game_players     enable row level security;
alter table public.live_match_stats enable row level security;
alter table public.player_stats     enable row level security;
alter table public.disputes         enable row level security;
alter table public.agent_ratings    enable row level security;
alter table public.private_rooms    enable row level security;
alter table public.room_players     enable row level security;
alter table public.announcements    enable row level security;
alter table public.notifications    enable row level security;
alter table public.agent_bans       enable row level security;

-- users: public read (leaderboard / profiles show names); own row insert at
-- signup; only the owner (or admin, who bans) may update.
create policy "users_read_all"
  on public.users for select using (true);
create policy "users_insert_self"
  on public.users for insert with check (id = auth.uid());
create policy "users_update_own"
  on public.users for update using (id = auth.uid() or public.is_admin());

-- player_profiles: public read for the leaderboard, owner-only update.
-- (Rows are created by the on_user_created trigger, not the client.)
create policy "player_profiles_read_all"
  on public.player_profiles for select using (true);
create policy "player_profiles_update_own"
  on public.player_profiles for update using (user_id = auth.uid());

-- agent_profiles: contains bank + ID data, so owner and admin only.
create policy "agent_profiles_read_own_or_admin"
  on public.agent_profiles for select
  using (user_id = auth.uid() or public.is_admin());
create policy "agent_profiles_update_own_or_admin"
  on public.agent_profiles for update
  using (user_id = auth.uid() or public.is_admin());

-- games: public games are world-readable; private games visible to the
-- owning agent or joined players (invite-code lookup uses get_game_by_code).
create policy "games_read_public_or_involved"
  on public.games for select
  using (
    is_private = false
    or agent_id = auth.uid()
    or public.is_admin()
    or exists (
      select 1 from public.game_players gp
      where gp.game_id = games.id and gp.player_id = auth.uid()
    )
  );
create policy "games_insert_approved_agent"
  on public.games for insert to authenticated
  with check (agent_id = auth.uid() and public.is_approved_agent());
create policy "games_update_owner_or_admin"
  on public.games for update
  using (agent_id = auth.uid() or public.is_admin());

-- game_players: roster is public (game detail shows who joined);
-- players join/leave only for themselves.
create policy "game_players_read_all"
  on public.game_players for select using (true);
create policy "game_players_insert_self"
  on public.game_players for insert to authenticated
  with check (player_id = auth.uid());
create policy "game_players_delete_self"
  on public.game_players for delete
  using (player_id = auth.uid());

-- live_match_stats: anyone can read (the app gates watching to joined
-- players client-side; numbers aren't sensitive). Only the game's agent
-- writes — that's the live-scoring permission rule.
create policy "live_stats_read_all"
  on public.live_match_stats for select using (true);
create policy "live_stats_insert_game_agent"
  on public.live_match_stats for insert to authenticated
  with check (exists (
    select 1 from public.games g
    where g.id = live_match_stats.game_id and g.agent_id = auth.uid()
  ));
create policy "live_stats_update_game_agent"
  on public.live_match_stats for update
  using (exists (
    select 1 from public.games g
    where g.id = live_match_stats.game_id and g.agent_id = auth.uid()
  ));

-- player_stats: readable by all (profiles/leaderboard); written only by the
-- agent who ran the game. XP/status changes come from confirm_pending_stats
-- (security definer), which bypasses RLS.
create policy "player_stats_read_all"
  on public.player_stats for select using (true);
create policy "player_stats_insert_game_agent"
  on public.player_stats for insert to authenticated
  with check (exists (
    select 1 from public.games g
    where g.id = player_stats.game_id and g.agent_id = auth.uid()
  ));
create policy "player_stats_update_game_agent"
  on public.player_stats for update
  using (exists (
    select 1 from public.games g
    where g.id = player_stats.game_id and g.agent_id = auth.uid()
  ));

-- disputes: visible to the disputing player, the accused agent, and admin.
-- Players open disputes about their own stats; agents/admin resolve them.
create policy "disputes_read_involved"
  on public.disputes for select
  using (player_id = auth.uid() or agent_id = auth.uid() or public.is_admin());
create policy "disputes_insert_own"
  on public.disputes for insert to authenticated
  with check (player_id = auth.uid());
create policy "disputes_update_agent_or_admin"
  on public.disputes for update
  using (agent_id = auth.uid() or public.is_admin());

-- agent_ratings: public read (agent reputation), players rate as themselves.
create policy "agent_ratings_read_all"
  on public.agent_ratings for select using (true);
create policy "agent_ratings_insert_self"
  on public.agent_ratings for insert to authenticated
  with check (player_id = auth.uid());

-- private_rooms: readable by everyone (code lookup), any signed-in user can
-- create; only the creator manages the room.
create policy "private_rooms_read_all"
  on public.private_rooms for select using (true);
create policy "private_rooms_insert_auth"
  on public.private_rooms for insert to authenticated
  with check (creator_id = auth.uid());
create policy "private_rooms_update_creator"
  on public.private_rooms for update
  using (creator_id = auth.uid());
create policy "private_rooms_delete_creator"
  on public.private_rooms for delete
  using (creator_id = auth.uid());

-- room_players: members see the roster; users join/leave as themselves.
create policy "room_players_read_members"
  on public.room_players for select
  using (
    public.is_room_member(room_id)
    or exists (
      select 1 from public.private_rooms r
      where r.id = room_players.room_id and r.creator_id = auth.uid()
    )
  );
create policy "room_players_insert_self"
  on public.room_players for insert to authenticated
  with check (player_id = auth.uid());
create policy "room_players_delete_self"
  on public.room_players for delete
  using (player_id = auth.uid());

-- notifications: strictly private to the recipient.
create policy "notifications_read_own"
  on public.notifications for select
  using (user_id = auth.uid());
create policy "notifications_update_own"
  on public.notifications for update
  using (user_id = auth.uid());

-- announcements: active ones are public; writes only via admin
-- (service key bypasses RLS, plus the hardcoded admin email).
create policy "announcements_read_active"
  on public.announcements for select
  using (is_active = true or public.is_admin());
create policy "announcements_admin_write"
  on public.announcements for all
  using (public.is_admin()) with check (public.is_admin());

-- agent_bans: admin-only audit table.
create policy "agent_bans_admin_only"
  on public.agent_bans for all
  using (public.is_admin()) with check (public.is_admin());


-- ─────────────────────────────────────────────────────────────────────────────
-- 10. SEED DATA — the three banners hardcoded in admin_providers.dart
-- ─────────────────────────────────────────────────────────────────────────────
insert into public.announcements (title, subtitle, badge) values
  ('Season 2 is Live',   'New tier rewards unlocked',   'update'),
  ('Weekend Tournament', 'RM500 prize pool',            'tournament'),
  ('Bring a Friend',     'Both get 50 XP bonus',        'promo');
