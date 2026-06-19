import 'supabase_service.dart';

/// An agent's aggregate rating (average stars + how many ratings).
class AgentRating {
  final double avg;
  final int count;
  const AgentRating(this.avg, this.count);
}

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

  /// Aggregate ratings for every agent, keyed by agent id — powers the star
  /// badge shown on game cards. (agent_ratings is public-read.)
  static Future<Map<String, AgentRating>> allAgentRatings() async {
    try {
      final rows = await _sb.from('agent_ratings').select('agent_id, rating');
      final sums = <String, int>{};
      final counts = <String, int>{};
      for (final r in rows) {
        final id = r['agent_id'] as String?;
        if (id == null) continue;
        sums[id] = (sums[id] ?? 0) + (r['rating'] as int? ?? 0);
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return {
        for (final id in counts.keys)
          id: AgentRating(sums[id]! / counts[id]!, counts[id]!)
      };
    } catch (_) {
      return const {};
    }
  }
}
