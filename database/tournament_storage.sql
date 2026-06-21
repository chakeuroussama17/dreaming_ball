-- ─────────────────────────────────────────────────────────────────────────────
-- TOURNAMENT STORAGE — buckets + upload policies
--
-- Creates the two PUBLIC buckets the tournament feature uploads to, and the
-- policies so a signed-in agent can upload into their own folder (paths are
-- "<uid>/<file>", matching TournamentService).
--
-- HOW TO RUN: Supabase Dashboard → SQL Editor → paste → Run.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Public buckets
insert into storage.buckets (id, name, public)
values
  ('tournament-banners', 'tournament-banners', true),
  ('team-logos',         'team-logos',         true)
on conflict (id) do nothing;

-- 2. Object policies (idempotent)
drop policy if exists "tourn_read"   on storage.objects;
drop policy if exists "tourn_insert" on storage.objects;
drop policy if exists "tourn_update" on storage.objects;
drop policy if exists "tourn_delete" on storage.objects;

-- Anyone can read (the buckets are public anyway).
create policy "tourn_read" on storage.objects for select
  using (bucket_id in ('tournament-banners', 'team-logos'));

-- Signed-in users can upload/update/delete inside their own folder.
create policy "tourn_insert" on storage.objects for insert to authenticated
  with check (
    bucket_id in ('tournament-banners', 'team-logos')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "tourn_update" on storage.objects for update to authenticated
  using (
    bucket_id in ('tournament-banners', 'team-logos')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "tourn_delete" on storage.objects for delete to authenticated
  using (
    bucket_id in ('tournament-banners', 'team-logos')
    and (storage.foldername(name))[1] = auth.uid()::text
  );
