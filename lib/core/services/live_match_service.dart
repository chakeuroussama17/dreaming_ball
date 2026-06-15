import 'dart:async';
import 'game_service.dart' show GameServiceException;
import 'notification_service.dart';
import 'supabase_service.dart';

/// One live_match_stats row, as both agent (writer) and players (watchers)
/// see it.
class LiveStatRow {
  final String playerId;
  final bool isPresent;
  final int goals;
  final int assists;
  final int goalsConceded;
  final int goodBehavior;

  const LiveStatRow({
    required this.playerId,
    required this.isPresent,
    required this.goals,
    required this.assists,
    required this.goalsConceded,
    required this.goodBehavior,
  });

  factory LiveStatRow.fromRow(Map<String, dynamic> r) => LiveStatRow(
        playerId: r['player_id'] as String,
        isPresent: (r['is_present'] ?? true) as bool,
        goals: (r['goals'] ?? 0) as int,
        assists: (r['assists'] ?? 0) as int,
        goalsConceded: (r['goals_conceded'] ?? 0) as int,
        goodBehavior: (r['good_behavior'] ?? 1) as int,
      );
}

/// One player_stats row in the post-match review (the authoritative pending
/// values the confirm cron will award XP from).
class FinalStatRow {
  final String statId;
  final String playerId;
  final String name;
  final String? avatarUrl;
  final String position;
  int goals;
  int assists;
  int goalsConceded;
  int goodBehavior;
  String status; // pending | confirmed | disputed
  final DateTime? confirmedAt; // dispute-window deadline
  final int? xpEarned;

  FinalStatRow({
    required this.statId,
    required this.playerId,
    required this.name,
    this.avatarUrl,
    required this.position,
    required this.goals,
    required this.assists,
    required this.goalsConceded,
    required this.goodBehavior,
    required this.status,
    this.confirmedAt,
    this.xpEarned,
  });
}

/// One post-match comment from a player (or a reply from the agent).
class MatchComment {
  final String id;
  final String userId;
  final String name;
  final String message;
  final DateTime createdAt;

  const MatchComment({
    required this.id,
    required this.userId,
    required this.name,
    required this.message,
    required this.createdAt,
  });
}

class LiveMatchService {
  static final _sb = SupabaseService.supabase;

  /// Agent starts the match: game goes live and a live_match_stats row is
  /// created per present player. (Presence lives on live_match_stats —
  /// game_players has no attended column.)
  static Future<void> startMatch(
      String gameId, List<String> presentPlayerIds) async {
    try {
      final game = await _sb
          .from('games')
          .update({
            'status': 'live',
            'started_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', gameId)
          .select('field_name')
          .single();

      if (presentPlayerIds.isNotEmpty) {
        await _sb.from('live_match_stats').upsert(
          [
            for (final id in presentPlayerIds)
              {
                'game_id': gameId,
                'player_id': id,
                'is_present': true,
                'goals': 0,
                'assists': 0,
                'goals_conceded': 0,
                'good_behavior': 1,
              }
          ],
          onConflict: 'game_id,player_id',
        );
      }

      // In-app bell for every rostered player (best-effort).
      NotificationService.notifyGamePlayers(
        gameId: gameId,
        title: 'Match started ⚽',
        body:
            '${game['field_name'] ?? 'Your game'} is live — watch your stats in real time.',
        type: 'game',
      );
      // TODO: push notification via OneSignal on top of the in-app bell
    } catch (e) {
      throw GameServiceException('Could not start the match — try again');
    }
  }

  /// Agent records one stat value. Realtime fans it out to all watchers.
  /// statType: 'goals' | 'assists' | 'goals_conceded' | 'good_behavior'.
  static Future<void> updatePlayerStat({
    required String gameId,
    required String playerId,
    required String statType,
    required int value,
  }) async {
    try {
      await _sb.from('live_match_stats').upsert(
        {
          'game_id': gameId,
          'player_id': playerId,
          statType: value,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'game_id,player_id',
      );
    } catch (e) {
      throw GameServiceException('Could not save the stat — try again');
    }
  }

  /// Increments goals_conceded for every player in the game.
  /// (The UI currently records GC per player; this stays for team-mode.)
  static Future<void> addTeamConceded(String gameId) async {
    try {
      final rows = await _sb
          .from('live_match_stats')
          .select('player_id, goals_conceded')
          .eq('game_id', gameId);
      // TODO: replace with a team_conceded RPC for a single atomic update.
      for (final r in rows) {
        await _sb
            .from('live_match_stats')
            .update({'goals_conceded': ((r['goals_conceded'] ?? 0) as int) + 1})
            .eq('game_id', gameId)
            .eq('player_id', r['player_id'] as String);
      }
    } catch (e) {
      throw GameServiceException('Could not record the goal — try again');
    }
  }

  /// Live stats for a game right now (initial load before realtime kicks in).
  static Future<List<LiveStatRow>> fetchLiveStats(String gameId) async {
    try {
      final rows = await _sb
          .from('live_match_stats')
          .select()
          .eq('game_id', gameId);
      return [
        for (final r in rows) LiveStatRow.fromRow(Map<String, dynamic>.from(r))
      ];
    } catch (e) {
      throw GameServiceException('Could not load live stats');
    }
  }

  /// Realtime subscription to this game's live stats. Cancel it in dispose.
  static StreamSubscription<List<Map<String, dynamic>>> subscribeToLiveMatch(
    String gameId,
    void Function(List<LiveStatRow> rows) onUpdate,
  ) {
    return _sb
        .from('live_match_stats')
        .stream(primaryKey: ['id'])
        .eq('game_id', gameId)
        .listen((rows) =>
            onUpdate([for (final r in rows) LiveStatRow.fromRow(r)]));
  }

  /// Agent submits final stats: game completes and live stats are copied to
  /// player_stats with a 3-hour dispute window (confirmed_at DB default =
  /// now() + 3h; the confirm-pending-stats cron then awards XP).
  static Future<void> endMatch(String gameId) async {
    try {
      final game = await _sb
          .from('games')
          .update({
            'status': 'completed',
            'ended_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', gameId)
          .select('field_name')
          .single();

      final live = await _sb
          .from('live_match_stats')
          .select()
          .eq('game_id', gameId)
          .eq('is_present', true);
      if (live.isEmpty) return;

      // player_stats snapshots each player's position for the XP formula.
      final playerIds = [for (final r in live) r['player_id'] as String];
      final profiles = await _sb
          .from('player_profiles')
          .select('user_id, position')
          .inFilter('user_id', playerIds);
      final positions = {
        for (final p in profiles) p['user_id'] as String: p['position']
      };

      await _sb.from('player_stats').upsert(
        [
          for (final r in live)
            {
              'game_id': gameId,
              'player_id': r['player_id'],
              'position': positions[r['player_id']] ?? 'Striker',
              'goals': r['goals'] ?? 0,
              'assists': r['assists'] ?? 0,
              'goals_conceded': r['goals_conceded'] ?? 0,
              'good_behavior': r['good_behavior'] ?? 1,
              'status': 'pending',
            }
        ],
        onConflict: 'game_id,player_id',
      );
      // In-app bell: the 3-hour dispute window just opened.
      NotificationService.notifyGamePlayers(
        gameId: gameId,
        title: 'Your stats are in 📊',
        body:
            '${game['field_name'] ?? 'Your game'} finished — review your stats now. You have 3 hours to comment or dispute before XP is final.',
        type: 'stats',
      );
      // TODO: push notification via OneSignal on top of the in-app bell
    } catch (e) {
      throw GameServiceException('Could not submit stats — try again');
    }
  }

  // ── Post-match review (dispute window) ──────────────────────────────────

  /// The submitted stat lines for a game, with player names — what the
  /// review panel shows after End Match.
  static Future<List<FinalStatRow>> fetchFinalStats(String gameId) async {
    try {
      final rows = await _sb
          .from('player_stats')
          .select('id, player_id, position, goals, assists, goals_conceded, '
              'good_behavior, status, confirmed_at, xp_earned, '
              'users!player_stats_player_id_fkey(full_name, avatar_url)')
          .eq('game_id', gameId)
          .order('created_at', ascending: true);
      return [
        for (final r in rows)
          () {
            final user = (r['users'] ?? const {}) as Map;
            final confirmedRaw = r['confirmed_at'] as String?;
            return FinalStatRow(
              statId: r['id'] as String,
              playerId: r['player_id'] as String,
              name: (user['full_name'] ?? 'Player') as String,
              avatarUrl: user['avatar_url'] as String?,
              position: (r['position'] ?? 'Striker') as String,
              goals: (r['goals'] ?? 0) as int,
              assists: (r['assists'] ?? 0) as int,
              goalsConceded: (r['goals_conceded'] ?? 0) as int,
              goodBehavior: (r['good_behavior'] ?? 1) as int,
              status: (r['status'] ?? 'pending') as String,
              confirmedAt: confirmedRaw == null
                  ? null
                  : DateTime.parse(confirmedRaw).toLocal(),
              xpEarned: r['xp_earned'] as int?,
            );
          }()
      ];
    } catch (e) {
      throw GameServiceException('Could not load the match report');
    }
  }

  /// Agent corrects one submitted stat while the dispute window is open.
  /// The cron computes XP from these values when it confirms.
  static Future<void> updateFinalStat({
    required String statId,
    required String statType,
    required int value,
  }) async {
    try {
      await _sb
          .from('player_stats')
          .update({statType: value})
          .eq('id', statId)
          .eq('status', 'pending'); // never touch confirmed stats
    } catch (e) {
      throw GameServiceException('Could not save the correction — try again');
    }
  }

  /// Post-match comments (player ↔ agent), oldest first.
  static Future<List<MatchComment>> fetchComments(String gameId) async {
    try {
      final rows = await _sb
          .from('match_comments')
          .select('id, user_id, message, created_at, '
              'users!match_comments_user_id_fkey(full_name)')
          .eq('game_id', gameId)
          .order('created_at', ascending: true);
      return [
        for (final r in rows)
          MatchComment(
            id: r['id'] as String,
            userId: r['user_id'] as String,
            name: (((r['users'] ?? const {}) as Map)['full_name'] ?? 'Player')
                as String,
            message: (r['message'] ?? '') as String,
            createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
          )
      ];
    } catch (e) {
      throw GameServiceException('Could not load comments');
    }
  }

  static Future<void> addComment(String gameId, String message) async {
    final uid = SupabaseService.userId;
    if (uid == null) throw GameServiceException('You must be signed in');
    try {
      await _sb.from('match_comments').insert({
        'game_id': gameId,
        'user_id': uid,
        'message': message,
      });
    } catch (e) {
      throw GameServiceException('Could not post the comment — try again');
    }
  }
}
