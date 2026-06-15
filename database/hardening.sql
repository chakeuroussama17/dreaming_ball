-- ─────────────────────────────────────────────────────────────────────────────
-- SECURITY HARDENING (pre-launch)
--
--  #3  Players could insert a game_players row directly with
--      payment_status='paid' (free join) and skip the capacity check. We drop
--      the direct client INSERT so the only way in is join_game_safe() (a
--      security-definer RPC) and the create-bill Edge Function (service role).
--      Leaving/joining for self still works (delete policy kept; RPC inserts).
--
--  #4  An agent could UPDATE their own game's money columns (price,
--      field_cost, commission) or mark themselves agent_paid_out. A trigger now
--      blocks any non-admin from changing those after creation. Agents can
--      still update status / slots / timestamps (start, end match).
--
-- Safe to run repeatedly. HOW TO RUN: Supabase SQL Editor → paste → Run.
-- ─────────────────────────────────────────────────────────────────────────────

-- #3 — force joins through the RPC.
drop policy if exists "game_players_insert_self" on public.game_players;

-- (join_game_safe is SECURITY DEFINER so it still inserts; create-bill uses the
--  service-role key which bypasses RLS. No legitimate path is affected.)


-- #4 — protect the money columns on games from non-admin edits.
create or replace function public.guard_game_money_columns()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  if public.is_admin() then
    return new;  -- admin may fix anything (e.g. payouts)
  end if;
  if new.price          is distinct from old.price
     or new.field_cost  is distinct from old.field_cost
     or new.commission  is distinct from old.commission
     or new.agent_paid_out  is distinct from old.agent_paid_out
     or new.paid_out_at     is distinct from old.paid_out_at
     or new.paid_out_method is distinct from old.paid_out_method
  then
    raise exception 'Only an admin can change pricing or payout fields';
  end if;
  return new;
end $$;

drop trigger if exists guard_game_money on public.games;
create trigger guard_game_money
  before update on public.games
  for each row execute function public.guard_game_money_columns();
