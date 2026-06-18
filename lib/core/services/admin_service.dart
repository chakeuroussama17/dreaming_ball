import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'supabase_service.dart';

/// One player's line in the payout detail (payment + stats).
class PayoutPlayer {
  final String userId;
  final String name;
  final bool paid;
  final double amountPaid;
  final int goals, assists, xp;
  final String? statStatus; // pending | confirmed | disputed | null
  const PayoutPlayer({
    required this.userId,
    required this.name,
    required this.paid,
    required this.amountPaid,
    required this.goals,
    required this.assists,
    required this.xp,
    this.statStatus,
  });
}

/// Everything behind one payout row, for the detail screen.
class PayoutDetail {
  final String gameId, fieldName, location, format, status, agentName;
  final DateTime kickoff;
  final double price, fieldCost, commission;
  final int numPlayers;
  final bool paidOut;
  final String? agentPhone, bankName, accountNumber, accountHolder,
      verificationStatus;
  final List<PayoutPlayer> players;

  const PayoutDetail({
    required this.gameId,
    required this.fieldName,
    required this.location,
    required this.format,
    required this.status,
    required this.agentName,
    required this.kickoff,
    required this.price,
    required this.fieldCost,
    required this.commission,
    required this.numPlayers,
    required this.paidOut,
    this.agentPhone,
    this.bankName,
    this.accountNumber,
    this.accountHolder,
    this.verificationStatus,
    required this.players,
  });

  int get paidCount => players.where((p) => p.paid).length;
  bool get allPaid => numPlayers > 0 && paidCount >= numPlayers;
  double get collected =>
      players.where((p) => p.paid).fold(0.0, (s, p) => s + p.amountPaid);
  double get agentPayout => fieldCost + commission;
}

/// One game's payout summary for the admin (from admin_payout_sheet()).
class PayoutRow {
  final String gameId;
  final String fieldName;
  final DateTime kickoff;
  final String status; // scheduled | live | completed
  final String agentId;
  final String agentName;
  final int numPlayers;
  final int paidCount;
  final double price; // per-player price
  final double collected; // actually received from paid players
  final double agentPayout; // field_cost + commission, what admin sends
  final bool paidOut;
  final DateTime? paidOutAt;

  const PayoutRow({
    required this.gameId,
    required this.fieldName,
    required this.kickoff,
    required this.status,
    required this.agentId,
    required this.agentName,
    required this.numPlayers,
    required this.paidCount,
    required this.price,
    required this.collected,
    required this.agentPayout,
    required this.paidOut,
    this.paidOutAt,
  });

  bool get allPaid => numPlayers > 0 && paidCount >= numPlayers;

  /// Margin once the game is fully paid (price × slots − agent payout). Used
  /// for the projected "your cut" so it never shows a scary negative before
  /// players have paid.
  double get projectedCut => price * numPlayers - agentPayout;

  /// Actual margin on money already in hand.
  double get currentCut => collected - agentPayout;

  factory PayoutRow.fromRow(Map<String, dynamic> r) => PayoutRow(
        gameId: r['game_id'] as String,
        fieldName: (r['field_name'] ?? 'Game') as String,
        kickoff: DateTime.parse(r['kickoff'] as String).toLocal(),
        status: (r['status'] ?? 'scheduled') as String,
        agentId: r['agent_id'] as String,
        agentName: (r['agent_name'] ?? 'Agent') as String,
        numPlayers: (r['num_players'] ?? 0) as int,
        paidCount: (r['paid_count'] ?? 0) as int,
        price: ((r['price'] ?? 0) as num).toDouble(),
        collected: ((r['collected'] ?? 0) as num).toDouble(),
        agentPayout: ((r['agent_payout'] ?? 0) as num).toDouble(),
        paidOut: (r['agent_paid_out'] ?? false) as bool,
        paidOutAt: r['paid_out_at'] == null
            ? null
            : DateTime.parse(r['paid_out_at'] as String).toLocal(),
      );
}

/// One agent's line in the admin leaderboard (from agent_leaderboard()).
class AgentLeaderRow {
  final String agentId;
  final String name;
  final int gamesCreated;
  final int playersConfirmed;
  final double collected;
  final double commission;

  const AgentLeaderRow({
    required this.agentId,
    required this.name,
    required this.gamesCreated,
    required this.playersConfirmed,
    required this.collected,
    required this.commission,
  });

  factory AgentLeaderRow.fromRow(Map<String, dynamic> r) => AgentLeaderRow(
        agentId: r['agent_id'] as String,
        name: (r['full_name'] ?? 'Agent') as String,
        gamesCreated: (r['games_created'] ?? 0) as int,
        playersConfirmed: (r['players_confirmed'] ?? 0) as int,
        collected: ((r['collected'] ?? 0) as num).toDouble(),
        commission: ((r['commission'] ?? 0) as num).toDouble(),
      );
}

/// Supabase queries + mutations for the admin panel. Every call here is
/// authorized by the is_admin() RLS policies (the admin signs into a real
/// Supabase session whose JWT email is chakeur@gmail.com).
class AdminService {
  static final _sb = SupabaseService.supabase;

  // ── Agents ────────────────────────────────────────────────────────────────

  /// Agents who have submitted verification (any status but not_submitted).
  static Future<List<Map<String, dynamic>>> fetchAgents() async {
    final rows = await _sb
        .from('agent_profiles')
        .select('*, users!agent_profiles_user_id_fkey(full_name, email, phone)')
        .neq('status', 'not_submitted')
        .order('created_at', ascending: false);
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  }

  static Future<void> setAgentStatus(String userId, String status,
      {String? reason}) async {
    await _sb.from('agent_profiles').update({
      'status': status,
      'rejection_reason': reason,
      if (status == 'approved')
        'verified_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('user_id', userId);
  }

  /// Signed URL (private kyc-documents bucket) for an uploaded ID image.
  static Future<String?> kycSignedUrl(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      return await _sb.storage
          .from('kyc-documents')
          .createSignedUrl(path, 60 * 10); // 10-minute link
    } catch (_) {
      return null;
    }
  }

  /// Per-agent performance leaderboard (games, confirmed players, money
  /// collected, realized commission) — ranked by commission. Admin only.
  static Future<List<AgentLeaderRow>> fetchAgentLeaderboard() async {
    final rows = await _sb.rpc('agent_leaderboard');
    return [
      for (final r in (rows as List))
        AgentLeaderRow.fromRow(Map<String, dynamic>.from(r))
    ];
  }

  // ── Users ───────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchUsers() async {
    final rows = await _sb
        .from('users')
        .select('id, full_name, email, role, is_banned, phone, created_at, '
            'date_of_birth, gender, country, state, city, '
            'player_profiles(current_tier, total_games_played, total_goals, '
            'total_assists, total_xp)')
        .order('created_at', ascending: false);
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  }

  static Future<void> setBanned(String userId, bool banned) async {
    await _sb.from('users').update({'is_banned': banned}).eq('id', userId);
  }

  // ── Disputes ──────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchDisputes() async {
    final rows = await _sb
        .from('disputes')
        .select('*, games(field_name), '
            'player:users!disputes_player_id_fkey(full_name), '
            'agent:users!disputes_agent_id_fkey(full_name)')
        .order('created_at', ascending: false);
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  }

  /// Admin accepts the player's claim: write it onto the stat and resolve.
  static Future<void> acceptPlayer(String disputeId) async {
    final d = await _sb
        .from('disputes')
        .select('player_stats_id, stat_type, claimed_value')
        .eq('id', disputeId)
        .single();
    await _sb.from('player_stats').update({
      d['stat_type'] as String: d['claimed_value'],
      'status': 'pending',
    }).eq('id', d['player_stats_id'] as String);
    await _sb.from('disputes').update({
      'status': 'resolved',
      'resolution': 'accepted_player',
      'resolved_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', disputeId);
  }

  /// Admin sides with the agent: stat stands, dispute resolved.
  static Future<void> keepAgent(String disputeId) async {
    final d = await _sb
        .from('disputes')
        .select('player_stats_id')
        .eq('id', disputeId)
        .single();
    await _sb
        .from('player_stats')
        .update({'status': 'pending'}).eq('id', d['player_stats_id'] as String);
    await _sb.from('disputes').update({
      'status': 'resolved',
      'resolution': 'kept_agent',
      'resolved_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', disputeId);
  }

  static Future<void> escalate(String disputeId) async {
    await _sb
        .from('disputes')
        .update({'status': 'escalated'}).eq('id', disputeId);
  }

  // ── Announcements ─────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchAnnouncements() async {
    final rows = await _sb
        .from('announcements')
        .select()
        .order('created_at', ascending: false);
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  }

  /// Uploads a banner image into the admin's folder of the public
  /// announcements bucket — the storage policy requires the first path
  /// segment to be the uploader's uid. Returns the public URL.
  static Future<String> _uploadBanner(Uint8List bytes) async {
    final uid = SupabaseService.userId;
    if (uid == null) throw StateError('No Supabase session');
    final storage = _sb.storage.from('announcements');
    final path = '$uid/banner_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await storage.uploadBinary(path, bytes,
        fileOptions:
            const FileOptions(upsert: true, contentType: 'image/jpeg'));
    return storage.getPublicUrl(path);
  }

  static Future<Map<String, dynamic>> addAnnouncement({
    required String title,
    required String subtitle,
    required String badge,
    Uint8List? bannerBytes,
  }) async {
    final photoUrl =
        bannerBytes == null ? null : await _uploadBanner(bannerBytes);
    final row = await _sb
        .from('announcements')
        .insert({
          'title': title,
          'subtitle': subtitle,
          'badge': badge,
          // Column is photo_url (see schema.sql announcements table).
          'photo_url': ?photoUrl,
        })
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  static Future<void> updateAnnouncement(
    String id, {
    String? title,
    String? subtitle,
    String? badge,
    bool? isActive,
    Uint8List? bannerBytes,
  }) async {
    final photoUrl =
        bannerBytes == null ? null : await _uploadBanner(bannerBytes);
    await _sb.from('announcements').update({
      'title': ?title,
      'subtitle': ?subtitle,
      'badge': ?badge,
      'is_active': ?isActive,
      'photo_url': ?photoUrl,
    }).eq('id', id);
  }

  static Future<void> removeAnnouncement(String id) async {
    await _sb.from('announcements').delete().eq('id', id);
  }

  // ── Payouts ───────────────────────────────────────────────────────────

  /// One row of the admin payout sheet (per game).
  static Future<List<PayoutRow>> fetchPayouts() async {
    final rows = await _sb.rpc('admin_payout_sheet');
    return [
      for (final r in (rows as List))
        PayoutRow.fromRow(Map<String, dynamic>.from(r))
    ];
  }

  /// Marks (or un-marks) an agent as paid out for a game.
  static Future<void> markAgentPaidOut(String gameId,
      {required bool paid, String? method}) async {
    await _sb.rpc('mark_agent_paid_out', params: {
      'p_game_id': gameId,
      'p_paid': paid,
      'p_method': method,
    });
  }

  /// Full detail behind one payout row: game, agent + bank details, the
  /// per-player payment list, and match stats (if played).
  static Future<PayoutDetail> fetchPayoutDetail(String gameId) async {
    final game = await _sb
        .from('games')
        .select('field_name, location, format, kickoff, price, field_cost, '
            'commission, num_players, status, agent_paid_out, paid_out_at, '
            'agent_id, users!games_agent_id_fkey(full_name, phone)')
        .eq('id', gameId)
        .single();

    final agentId = game['agent_id'] as String;
    final bank = await _sb
        .from('agent_profiles')
        .select('bank_name, account_number, account_holder, status')
        .eq('user_id', agentId)
        .maybeSingle();

    final players = await _sb
        .from('game_players')
        .select('player_id, payment_status, amount_paid, '
            'users!game_players_player_id_fkey(full_name)')
        .eq('game_id', gameId);

    final stats = await _sb
        .from('player_stats')
        .select('player_id, goals, assists, xp_earned, status')
        .eq('game_id', gameId);
    final statByPlayer = {
      for (final s in stats) s['player_id'] as String: s,
    };

    final agentUser = (game['users'] ?? const {}) as Map;
    return PayoutDetail(
      gameId: gameId,
      fieldName: (game['field_name'] ?? 'Game') as String,
      location: (game['location'] ?? '') as String,
      format: (game['format'] ?? '') as String,
      kickoff: DateTime.parse(game['kickoff'] as String).toLocal(),
      status: (game['status'] ?? 'scheduled') as String,
      price: ((game['price'] ?? 0) as num).toDouble(),
      fieldCost: ((game['field_cost'] ?? 0) as num).toDouble(),
      commission: ((game['commission'] ?? 0) as num).toDouble(),
      numPlayers: (game['num_players'] ?? 0) as int,
      paidOut: (game['agent_paid_out'] ?? false) as bool,
      agentName: (agentUser['full_name'] ?? 'Agent') as String,
      agentPhone: agentUser['phone'] as String?,
      bankName: bank?['bank_name'] as String?,
      accountNumber: bank?['account_number'] as String?,
      accountHolder: bank?['account_holder'] as String?,
      verificationStatus: bank?['status'] as String?,
      players: [
        for (final p in players)
          () {
            final pid = p['player_id'] as String;
            final st = statByPlayer[pid];
            return PayoutPlayer(
              userId: pid,
              name: (((p['users'] ?? const {}) as Map)['full_name'] ??
                  'Player') as String,
              paid: p['payment_status'] == 'paid',
              amountPaid: ((p['amount_paid'] ?? 0) as num).toDouble(),
              goals: (st?['goals'] ?? 0) as int,
              assists: (st?['assists'] ?? 0) as int,
              xp: (st?['xp_earned'] ?? 0) as int,
              statStatus: st?['status'] as String?,
            );
          }()
      ],
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  static String dateLabel(String? iso) {
    if (iso == null) return '—';
    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return '—';
    }
  }
}
