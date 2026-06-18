-- ─────────────────────────────────────────────────────────────────────────────
-- MANUAL QR PAYMENT + AGENT CONFIRMATION
--
-- Flow:
--   1. Agent creates a game and uploads a TNG / bank QR (games.payment_qr_url).
--   2. Player scans the QR, pays in their own app, taps "I've Paid" → a
--      game_players row is created with payment_status 'pending' (slot held).
--   3. Agent checks their bank, then Confirm (→ 'paid', player notified
--      "you're in") or Reject (→ row removed, slot freed, player notified).
--   4. Free games (price = 0) skip all of this: the join is instant 'paid'.
--
-- HOW TO RUN: Supabase Dashboard → SQL Editor → paste this → Run.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. The agent's payment QR image, shown to players on the game's detail page.
alter table public.games
  add column if not exists payment_qr_url text;

-- 2. join_game_safe — free games join as 'paid' (instant, officially in);
--    paid games join as 'pending' (slot held, awaiting agent confirmation).
create or replace function public.join_game_safe(
  p_game_id   uuid,
  p_player_id uuid
) returns json
language plpgsql security definer
set search_path = public
as $$
declare
  v_game public.games%rowtype;
  v_status text;
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

  -- Free game → officially in right away; paid game → awaiting confirmation.
  v_status := case when coalesce(v_game.price, 0) <= 0 then 'paid' else 'pending' end;

  insert into public.game_players (game_id, player_id, payment_status, paid_at)
  values (p_game_id, p_player_id, v_status,
          case when v_status = 'paid' then now() else null end);

  update public.games
  set num_slots_filled = num_slots_filled + 1
  where id = p_game_id;

  return json_build_object('success', true, 'status', v_status);
end;
$$;

-- 3. confirm_payment — agent marks a pending player as paid (officially in)
--    and notifies them. Slot was already held, so no counter change.
create or replace function public.confirm_payment(
  p_game_id   uuid,
  p_player_id uuid
) returns void
language plpgsql security definer
set search_path = public
as $$
declare
  v_field text;
begin
  select field_name into v_field
  from public.games
  where id = p_game_id and agent_id = auth.uid();

  if not found then
    raise exception 'Only the game agent can confirm payments';
  end if;

  update public.game_players
  set payment_status = 'paid',
      paid_at = now()
  where game_id = p_game_id and player_id = p_player_id;

  if not found then
    raise exception 'That player is not in this game';
  end if;

  insert into public.notifications (user_id, type, title, body)
  values (p_player_id, 'payment', 'Payment confirmed ✅',
          'You''re officially in for ' || coalesce(v_field, 'your game') || '. See you on the pitch!');
end;
$$;

-- 4. reject_payment — agent removes a player whose payment never arrived,
--    freeing the slot and notifying them.
create or replace function public.reject_payment(
  p_game_id   uuid,
  p_player_id uuid
) returns void
language plpgsql security definer
set search_path = public
as $$
declare
  v_field text;
begin
  select field_name into v_field
  from public.games
  where id = p_game_id and agent_id = auth.uid();

  if not found then
    raise exception 'Only the game agent can reject payments';
  end if;

  delete from public.game_players
  where game_id = p_game_id and player_id = p_player_id;

  if not found then
    raise exception 'That player is not in this game';
  end if;

  update public.games
  set num_slots_filled = greatest(num_slots_filled - 1, 0)
  where id = p_game_id;

  insert into public.notifications (user_id, type, title, body)
  values (p_player_id, 'payment', 'Payment not confirmed',
          'We couldn''t confirm your payment for ' || coalesce(v_field, 'the game') ||
          ', so your spot was released. Please pay and try again, or contact the agent.');
end;
$$;
