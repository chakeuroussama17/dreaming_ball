-- ─────────────────────────────────────────────────────────────────────────────
-- POST-MATCH REVIEW COMMENTS
--
-- After the agent submits stats, the match panel stays open during the
-- 3-hour dispute window: players can comment to the agent and the agent can
-- still correct stats. Comments live here.
--
-- HOW TO RUN: Supabase Dashboard → SQL Editor → paste this → Run.
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.match_comments (
  id          uuid primary key default uuid_generate_v4(),
  game_id     uuid not null references public.games (id) on delete cascade,
  user_id     uuid not null references public.users (id) on delete cascade,
  message     text not null check (char_length(message) between 1 and 300),
  created_at  timestamptz not null default now()
);

create index if not exists idx_match_comments_game
  on public.match_comments (game_id, created_at);

alter table public.match_comments enable row level security;

-- Participants only: players who joined the game, the agent who runs it,
-- and the admin.
create policy "match_comments_read_participants"
  on public.match_comments for select
  using (
    exists (select 1 from public.game_players gp
            where gp.game_id = match_comments.game_id
              and gp.player_id = auth.uid())
    or exists (select 1 from public.games g
               where g.id = match_comments.game_id
                 and g.agent_id = auth.uid())
    or public.is_admin()
  );

create policy "match_comments_insert_participants"
  on public.match_comments for insert
  with check (
    user_id = auth.uid()
    and (
      exists (select 1 from public.game_players gp
              where gp.game_id = match_comments.game_id
                and gp.player_id = auth.uid())
      or exists (select 1 from public.games g
                 where g.id = match_comments.game_id
                   and g.agent_id = auth.uid())
    )
  );
