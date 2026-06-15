-- ─────────────────────────────────────────────────────────────────────────────
-- FIX: admin writes were rejected by RLS.
--
-- Why: is_admin() only accepted chakeur@gmail.com, but that auth account is
-- stuck with an unknown password, so the app now backs the admin session
-- with admin.dreamingball@gmail.com (same admin123 password, already
-- created). This makes is_admin() accept both emails.
--
-- HOW TO RUN: Supabase Dashboard → SQL Editor → paste this → Run.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.is_admin()
returns boolean
language sql stable
set search_path = public
as $$
  select coalesce(auth.jwt() ->> 'email', '')
         in ('chakeur@gmail.com', 'admin.dreamingball@gmail.com');
$$;
