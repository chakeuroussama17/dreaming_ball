-- ─────────────────────────────────────────────────────────────────────────────
-- ADMIN PAYOUTS
--
-- Money model (beginning / manual payouts):
--   • Players pay the admin (via Billplz) → game_players.payment_status='paid'.
--   • The admin manually sends each agent (field_cost + commission) ~1h before
--     kickoff via DuitNow / bank transfer, then marks it paid out here.
--   • The platform keeps  collected − (field_cost + commission).
--
-- This adds the bookkeeping columns + an admin-only function to flip them.
-- HOW TO RUN: Supabase Dashboard → SQL Editor → paste this → Run.
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.games
  add column if not exists agent_paid_out boolean not null default false,
  add column if not exists paid_out_at    timestamptz,
  add column if not exists paid_out_method text;  -- 'duitnow' | 'bank' | 'tng'...

-- Admin marks an agent as paid out for a game (or un-marks it). When paid,
-- the agent gets a notification with the amount.
create or replace function public.mark_agent_paid_out(
  p_game_id uuid,
  p_paid    boolean default true,
  p_method  text default null
) returns void
language plpgsql security definer
set search_path = public
as $$
declare
  v_agent  uuid;
  v_field  text;
  v_amount numeric;
begin
  if not public.is_admin() then
    raise exception 'Admin only';
  end if;

  update public.games
  set agent_paid_out  = p_paid,
      paid_out_at     = case when p_paid then now() else null end,
      paid_out_method = case when p_paid then p_method else null end
  where id = p_game_id
  returning agent_id, field_name, (field_cost + commission)
  into v_agent, v_field, v_amount;

  if p_paid and v_agent is not null then
    insert into public.notifications (user_id, type, title, body)
    values (
      v_agent,
      'payment',
      'You''ve been paid 💸',
      format('RM %s for %s has been sent%s (field + commission).',
             to_char(v_amount, 'FM999990.00'),
             v_field,
             case when p_method is not null then ' via ' || p_method else '' end)
    );
  end if;
end $$;

-- Admin reads the full payout sheet for a game set: collected so far, how many
-- paid, what the agent is owed. (Admin already has read access to games and
-- game_players via is_admin() RLS, but this rolls it up in one call.)
create or replace function public.admin_payout_sheet()
returns table (
  game_id        uuid,
  field_name     text,
  kickoff        timestamptz,
  status         text,
  agent_id       uuid,
  agent_name     text,
  num_players    integer,
  paid_count     bigint,
  price          numeric,
  field_cost     numeric,
  commission     numeric,
  collected      numeric,
  agent_payout   numeric,
  platform_cut   numeric,
  agent_paid_out boolean,
  paid_out_at    timestamptz
)
language sql stable security definer
set search_path = public
as $$
  select
    g.id,
    g.field_name,
    g.kickoff,
    g.status,
    g.agent_id,
    u.full_name,
    g.num_players,
    coalesce(p.paid_count, 0),
    g.price,
    g.field_cost,
    g.commission,
    coalesce(p.collected, 0),
    (g.field_cost + g.commission)                              as agent_payout,
    coalesce(p.collected, 0) - (g.field_cost + g.commission)   as platform_cut,
    g.agent_paid_out,
    g.paid_out_at
  from public.games g
  join public.users u on u.id = g.agent_id
  left join (
    select game_id,
           count(*)                       as paid_count,
           coalesce(sum(amount_paid), 0)  as collected
    from public.game_players
    where payment_status = 'paid'
    group by game_id
  ) p on p.game_id = g.id
  where public.is_admin()
    and g.status <> 'cancelled'
  order by g.kickoff asc;
$$;
