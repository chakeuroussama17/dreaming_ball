import 'package:intl/intl.dart';
import 'game_service.dart' show GameServiceException;
import 'notification_service.dart';
import 'supabase_service.dart';

/// A player_stats row still inside its 3-hour dispute window.
class PendingStat {
  final String statId;
  final String gameId;
  final String fieldName;
  final String dateLabel;
  final DateTime disputeDeadline;
  final int goals;
  final int assists;
  final int goalsConceded;
  final int goodBehavior;

  const PendingStat({
    required this.statId,
    required this.gameId,
    required this.fieldName,
    required this.dateLabel,
    required this.disputeDeadline,
    required this.goals,
    required this.assists,
    required this.goalsConceded,
    required this.goodBehavior,
  });
}

/// A dispute row with context for either side's list.
class Dispute {
  final String id;
  final String statId;
  final String gameId;
  final String fieldName;
  final String playerName;
  final String statType;
  final int recordedValue;
  final int claimedValue;
  final String reason;
  final String status; // open | resolved | escalated
  final String? resolution; // accepted_player | kept_agent

  const Dispute({
    required this.id,
    required this.statId,
    required this.gameId,
    required this.fieldName,
    required this.playerName,
    required this.statType,
    required this.recordedValue,
    required this.claimedValue,
    required this.reason,
    required this.status,
    this.resolution,
  });

  factory Dispute.fromRow(Map<String, dynamic> r) => Dispute(
        id: r['id'] as String,
        statId: r['player_stats_id'] as String,
        gameId: r['game_id'] as String,
        fieldName:
            ((r['games'] as Map?)?['field_name'] ?? 'Game') as String,
        playerName:
            ((r['users'] as Map?)?['full_name'] ?? 'Player') as String,
        statType: (r['stat_type'] ?? 'goals') as String,
        recordedValue: (r['recorded_value'] ?? 0) as int,
        claimedValue: (r['claimed_value'] ?? 0) as int,
        reason: (r['reason'] ?? '') as String,
        status: (r['status'] ?? 'open') as String,
        resolution: r['resolution'] as String?,
      );
}

class DisputeService {
  static final _sb = SupabaseService.supabase;

  /// Stats the player can still dispute (window closes at confirmed_at).
  static Future<List<PendingStat>> fetchMyPendingStats() async {
    final uid = SupabaseService.userId;
    if (uid == null) return const [];
    try {
      final rows = await _sb
          .from('player_stats')
          .select('id, game_id, goals, assists, goals_conceded, '
              'good_behavior, confirmed_at, games(field_name, kickoff)')
          .eq('player_id', uid)
          .eq('status', 'pending')
          .gt('confirmed_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false);
      return [
        for (final r in rows)
          () {
            final game = (r['games'] ?? const {}) as Map;
            final kickoffRaw = game['kickoff'] as String?;
            return PendingStat(
              statId: r['id'] as String,
              gameId: r['game_id'] as String,
              fieldName: (game['field_name'] ?? 'Game') as String,
              dateLabel: kickoffRaw == null
                  ? '—'
                  : DateFormat('MMM d')
                      .format(DateTime.parse(kickoffRaw).toLocal()),
              disputeDeadline:
                  DateTime.parse(r['confirmed_at'] as String).toLocal(),
              goals: (r['goals'] ?? 0) as int,
              assists: (r['assists'] ?? 0) as int,
              goalsConceded: (r['goals_conceded'] ?? 0) as int,
              goodBehavior: (r['good_behavior'] ?? 1) as int,
            );
          }()
      ];
    } catch (e) {
      throw GameServiceException('Could not load your pending stats');
    }
  }

  /// Player contests one stat value. The stat is marked disputed so the
  /// confirm cron skips it until the agent resolves.
  static Future<void> raiseDispute({
    required String statId,
    required String statType, // goals | assists | goals_conceded | good_behavior
    required int claimedValue,
    required String reason,
  }) async {
    final uid = SupabaseService.userId;
    if (uid == null) throw GameServiceException('You must be signed in');
    try {
      final stat = await _sb
          .from('player_stats')
          .select('id, game_id, goals, assists, goals_conceded, '
              'good_behavior, games(agent_id)')
          .eq('id', statId)
          .single();
      final recorded = (stat[statType] ?? 0) as int;
      final agentId = ((stat['games'] as Map?)?['agent_id']) as String?;
      if (agentId == null) throw GameServiceException('Game not found');

      await _sb.from('disputes').insert({
        'player_stats_id': statId,
        'game_id': stat['game_id'],
        'player_id': uid,
        'agent_id': agentId,
        'stat_type': statType,
        'recorded_value': recorded,
        'claimed_value': claimedValue,
        'reason': reason,
      });
      await _sb
          .from('player_stats')
          .update({'status': 'disputed'}).eq('id', statId);

      // In-app bell for the agent (notify_game_agent RPC).
      NotificationService.notifyGameAgent(
        gameId: stat['game_id'] as String,
        title: 'Stat disputed 🚩',
        body:
            'A player contested their ${_statLabel(statType)} ($recorded → $claimedValue). Open the match report to resolve it.',
      );
      // TODO: push notification via OneSignal on top of the in-app bell
    } on GameServiceException {
      rethrow;
    } catch (e) {
      throw GameServiceException('Could not submit the dispute — try again');
    }
  }

  static const _disputeSelect = '*, games(field_name), '
      'users!disputes_player_id_fkey(full_name)';

  /// Disputes raised by the signed-in player.
  static Future<List<Dispute>> fetchMyDisputes() async {
    final uid = SupabaseService.userId;
    if (uid == null) return const [];
    try {
      final rows = await _sb
          .from('disputes')
          .select(_disputeSelect)
          .eq('player_id', uid)
          .order('created_at', ascending: false);
      return [
        for (final r in rows) Dispute.fromRow(Map<String, dynamic>.from(r))
      ];
    } catch (e) {
      throw GameServiceException('Could not load your disputes');
    }
  }

  /// Open disputes against the signed-in agent's games.
  static Future<List<Dispute>> fetchAgentDisputes() async {
    final uid = SupabaseService.userId;
    if (uid == null) return const [];
    try {
      final rows = await _sb
          .from('disputes')
          .select(_disputeSelect)
          .eq('agent_id', uid)
          .eq('status', 'open')
          .order('created_at', ascending: false);
      return [
        for (final r in rows) Dispute.fromRow(Map<String, dynamic>.from(r))
      ];
    } catch (e) {
      throw GameServiceException('Could not load disputes');
    }
  }

  /// Agent resolves a dispute. Accepting writes the player's claimed value
  /// onto the stat line; either way the stat returns to 'pending' so the
  /// confirm cron can award XP. (Schema status stays 'resolved' — the
  /// outcome lives in the resolution column.)
  static Future<void> resolveDispute({
    required String disputeId,
    required bool accept,
    String? agentResponse,
  }) async {
    try {
      final dispute = await _sb
          .from('disputes')
          .select('player_stats_id, stat_type, claimed_value, game_id, '
              'player_id, recorded_value')
          .eq('id', disputeId)
          .single();

      if (accept) {
        await _sb.from('player_stats').update({
          dispute['stat_type'] as String: dispute['claimed_value'],
          'status': 'pending',
        }).eq('id', dispute['player_stats_id'] as String);
      } else {
        await _sb
            .from('player_stats')
            .update({'status': 'pending'})
            .eq('id', dispute['player_stats_id'] as String);
      }

      await _sb.from('disputes').update({
        'status': 'resolved',
        'resolution': accept ? 'accepted_player' : 'kept_agent',
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', disputeId);

      // In-app bell: outcome back to the player (notify_player RPC).
      final label = _statLabel(dispute['stat_type'] as String?);
      NotificationService.notifyPlayer(
        gameId: dispute['game_id'] as String,
        playerId: dispute['player_id'] as String,
        title: accept ? 'Dispute accepted ✅' : 'Dispute rejected',
        body: accept
            ? 'Your $label was corrected to ${dispute['claimed_value']}.'
            : 'The agent kept your $label at ${dispute['recorded_value']}.',
      );
      // TODO: push notification via OneSignal on top of the in-app bell
    } catch (e) {
      throw GameServiceException('Could not resolve the dispute — try again');
    }
  }

  static String _statLabel(String? t) => switch (t) {
        'goals' => 'goals',
        'assists' => 'assists',
        'goals_conceded' => 'goals conceded',
        'good_behavior' => 'good behavior',
        _ => 'stat',
      };
}
