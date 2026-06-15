-- ─────────────────────────────────────────────────────────────────────────────
-- PUSH NOTIFICATIONS (FCM) — device token storage
--
-- Every in-app notification already funnels through one table: notifications.
-- So we get device push for FREE on every event (welcome, reminder, payment,
-- tier-up, XP, announcement, ...) by firing a single Database Webhook on
-- `notifications` INSERT that calls the `send-push` Edge Function. That function
-- looks up the recipient's device tokens here and delivers via FCM.
--
-- This file only creates the token table + RLS. The webhook is created in the
-- Supabase Dashboard (see FIREBASE_SETUP.md, step 6) and the Edge Function is
-- deployed from supabase/functions/send-push.
--
-- HOW TO RUN: Supabase Dashboard → SQL Editor → paste → Run. Safe to re-run.
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists public.device_tokens (
  user_id    uuid        not null references public.users(id) on delete cascade,
  token      text        not null,
  platform   text        not null default 'android',  -- 'android' | 'ios'
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);

create index if not exists device_tokens_user_idx
  on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

-- A user manages only their own tokens. The Edge Function uses the service-role
-- key, which bypasses RLS, so it can read every recipient's tokens to send.
drop policy if exists "device_tokens_select_own" on public.device_tokens;
create policy "device_tokens_select_own"
  on public.device_tokens for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "device_tokens_insert_own" on public.device_tokens;
create policy "device_tokens_insert_own"
  on public.device_tokens for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "device_tokens_update_own" on public.device_tokens;
create policy "device_tokens_update_own"
  on public.device_tokens for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "device_tokens_delete_own" on public.device_tokens;
create policy "device_tokens_delete_own"
  on public.device_tokens for delete to authenticated
  using (user_id = auth.uid());

-- Upsert helper called by the app after it gets/refreshes an FCM token.
create or replace function public.save_device_token(
  p_token text,
  p_platform text default 'android'
) returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  insert into public.device_tokens (user_id, token, platform, updated_at)
  values (auth.uid(), p_token, p_platform, now())
  on conflict (user_id, token)
  do update set updated_at = now(), platform = excluded.platform;
end $$;

-- Called on logout so a shared device doesn't keep pushing to the old user.
create or replace function public.delete_device_token(p_token text)
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  delete from public.device_tokens
  where token = p_token and user_id = auth.uid();
end $$;
