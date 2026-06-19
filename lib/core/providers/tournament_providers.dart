import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/tournament_service.dart';

/// All tournaments (overview), newest first. Refetched when invalidated.
final tournamentsProvider =
    FutureProvider.autoDispose<List<Tournament>>((ref) {
  return TournamentService.fetchTournaments();
});

/// Tournaments awaiting admin approval.
final pendingTournamentsProvider =
    FutureProvider.autoDispose<List<Tournament>>((ref) {
  return TournamentService.fetchPending();
});

/// One tournament by id.
final tournamentProvider =
    FutureProvider.autoDispose.family<Tournament?, String>((ref, id) {
  return TournamentService.fetchTournament(id);
});

/// Teams (with players) for a tournament.
final tournamentTeamsProvider =
    FutureProvider.autoDispose.family<List<TournamentTeam>, String>((ref, id) {
  return TournamentService.fetchTeams(id);
});

/// Matches for a tournament.
final tournamentMatchesProvider =
    FutureProvider.autoDispose.family<List<TournamentMatch>, String>((ref, id) {
  return TournamentService.fetchMatches(id);
});
