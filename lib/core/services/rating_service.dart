import 'supabase_service.dart';

/// Players rate the agent 1–5 stars after a game. Backed by the agent_ratings
/// table (unique per game+player, so each player rates a game once).
class RatingService {
  static final _sb = SupabaseService.supabase;

  /// Whether the current player has already rated this game's agent.
  static Future<bool> hasRated(String gameId) async {
    final uid = SupabaseService.userId;
    if (uid == null) return true; // no session → don't prompt
    try {
      final row = await _sb
          .from('agent_ratings')
          .select('id')
          .eq('game_id', gameId)
          .eq('player_id', uid)
          .maybeSingle();
      return row != null;
    } catch (_) {
      // On error, assume rated so we don't nag the player.
      return true;
    }
  }

  /// Submits a 1–5 star rating (with optional comment) for the game's agent.
  static Future<void> rateAgent({
    required String gameId,
    required String agentId,
    required int rating,
    String? comment,
  }) async {
    final uid = SupabaseService.userId;
    if (uid == null) return;
    await _sb.from('agent_ratings').insert({
      'game_id': gameId,
      'agent_id': agentId,
      'player_id': uid,
      'rating': rating,
      'comment': (comment != null && comment.trim().isNotEmpty)
          ? comment.trim()
          : null,
    });
  }

  /// Average rating + count for an agent (for profiles / admin leaderboards).
  static Future<(double avg, int count)> agentRating(String agentId) async {
    try {
      final rows = await _sb
          .from('agent_ratings')
          .select('rating')
          .eq('agent_id', agentId);
      if (rows.isEmpty) return (0.0, 0);
      final total =
          rows.fold<int>(0, (sum, r) => sum + (r['rating'] as int? ?? 0));
      return (total / rows.length, rows.length);
    } catch (_) {
      return (0.0, 0);
    }
  }
}
