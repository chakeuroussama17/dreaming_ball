-- ─────────────────────────────────────────────────────────────────────────────
-- TOURNAMENTS — winner advancement trigger
--
-- When a match is completed with a winner, the winner is auto-placed into the
-- next match's slot (next_match_id + next_slot). When the final completes, the
-- tournament is marked completed.
--
-- (Bracket GENERATION is done in the app's TournamentService so non-power-of-2
-- even counts can be handled with byes; this trigger only handles advancement.)
--
-- HOW TO RUN: Supabase Dashboard → SQL Editor → paste → Run (after tournaments.sql).
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.tournament_advance_winner()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  -- Only act when a match transitions INTO completed with a winner.
  if NEW.status = 'completed'
     and NEW.winner_team_id is not null
     and OLD.status is distinct from 'completed' then

    -- Place the winner into the next match's slot.
    if NEW.next_match_id is not null and NEW.next_slot is not null then
      if NEW.next_slot = 'a' then
        update public.tournament_matches
          set team_a_id = NEW.winner_team_id, updated_at = now()
          where id = NEW.next_match_id;
      else
        update public.tournament_matches
          set team_b_id = NEW.winner_team_id, updated_at = now()
          where id = NEW.next_match_id;
      end if;
    end if;

    -- No next match → this was the final → the tournament is done.
    if NEW.next_match_id is null then
      update public.tournaments
        set status = 'completed', updated_at = now()
        where id = NEW.tournament_id and status <> 'completed';
    end if;
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_tournament_advance on public.tournament_matches;
create trigger trg_tournament_advance
  after update on public.tournament_matches
  for each row execute function public.tournament_advance_winner();
