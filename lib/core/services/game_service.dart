import 'dart:typed_data';
import '../providers/games_provider.dart';
import 'supabase_service.dart';

/// Thrown by GameService with a message safe to show in the UI.
class GameServiceException implements Exception {
  final String message;
  GameServiceException(this.message);

  @override
  String toString() => message;
}

/// A player on a game's roster (game_players joined with profile data).
class SquadPlayer {
  final String userId;
  final String name;
  final String position;
  final String tier;
  final int totalXp;
  final String? avatarUrl;
  final String paymentStatus; // 'pending' | 'paid' | 'refunded'

  const SquadPlayer({
    required this.userId,
    required this.name,
    required this.position,
    required this.tier,
    required this.totalXp,
    this.avatarUrl,
    required this.paymentStatus,
  });

  /// Officially in (agent confirmed, or a free game).
  bool get paid => paymentStatus == 'paid';

  /// Paid externally, waiting for the agent to confirm.
  bool get pending => paymentStatus == 'pending';
}

class GameService {
  static final _sb = SupabaseService.supabase;

  // Game row + agent info + roster (for mine/joined flags).
  static const _gameSelect = '*, '
      'users!games_agent_id_fkey(full_name, avatar_url), '
      'game_players(player_id, payment_status)';

  /// Public feed: non-private games from today onward, scheduled or live.
  /// (Live ones stay visible so the LIVE badge and Watch Live work.)
  static Future<List<Game>> fetchPublicGames({
    String? format,
    String? ageGroup,
  }) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toUtc();

      var query = _sb
          .from('games')
          .select(_gameSelect)
          .eq('is_private', false)
          .inFilter('status', ['scheduled', 'live'])
          .gte('kickoff', todayStart.toIso8601String());
      if (format != null && format != 'All') {
        query = query.eq('format', format);
      }
      if (ageGroup != null && ageGroup != 'Open') {
        query = query.eq('age_group', ageGroup);
      }

      final rows = await query.order('kickoff', ascending: true);
      final uid = SupabaseService.userId;
      return [
        for (final r in rows) Game.fromRow(Map<String, dynamic>.from(r), uid: uid)
      ];
    } catch (e) {
      throw GameServiceException(friendlyError(e));
    }
  }

  /// One game with agent + roster info, or null if not found/visible.
  static Future<Game?> fetchGameById(String gameId) async {
    try {
      final row = await _sb
          .from('games')
          .select(_gameSelect)
          .eq('id', gameId)
          .maybeSingle();
      if (row == null) return null;
      return Game.fromRow(
          Map<String, dynamic>.from(row), uid: SupabaseService.userId);
    } catch (e) {
      throw GameServiceException(friendlyError(e));
    }
  }

  /// Roster with each player's tier (game detail squad list, attendance).
  static Future<List<SquadPlayer>> fetchGamePlayers(String gameId) async {
    try {
      final rows = await _sb
          .from('game_players')
          .select('player_id, payment_status, '
              'users!game_players_player_id_fkey(full_name, avatar_url, '
              'player_profiles(position, current_tier, total_xp))')
          .eq('game_id', gameId);

      return [
        for (final r in rows)
          () {
            final user = (r['users'] ?? const {}) as Map;
            final profiles = user['player_profiles'];
            // Embedded 1:1 may come back as a map or a one-element list.
            final profile = (profiles is List
                ? (profiles.isEmpty ? const {} : profiles.first)
                : (profiles ?? const {})) as Map;
            return SquadPlayer(
              userId: r['player_id'] as String,
              name: (user['full_name'] ?? 'Player') as String,
              position: (profile['position'] ?? 'Striker') as String,
              tier: (profile['current_tier'] ?? 'Beginner') as String,
              totalXp: (profile['total_xp'] ?? 0) as int,
              avatarUrl: user['avatar_url'] as String?,
              paymentStatus: (r['payment_status'] ?? 'pending') as String,
            );
          }()
      ];
    } catch (e) {
      throw GameServiceException(friendlyError(e));
    }
  }

  /// Race-safe join via the join_game_safe RPC (locks the game row).
  /// Returns null on success, or a friendly error message.
  static Future<String?> joinGame(String gameId) async {
    final uid = SupabaseService.userId;
    if (uid == null) return 'You must be signed in to join';
    try {
      final res = await _sb.rpc('join_game_safe', params: {
        'p_game_id': gameId,
        'p_player_id': uid,
      });
      final map = res is Map ? Map<String, dynamic>.from(res) : null;
      if (map?['success'] == true) return null;
      return (map?['error'] as String?) ?? 'Could not join this game';
    } catch (e) {
      return friendlyError(e);
    }
  }

  /// Agent confirms a pending player's payment → they become officially in
  /// and get a push notification. Agent-only (enforced in the RPC).
  static Future<void> confirmPayment(String gameId, String playerId) async {
    try {
      await _sb.rpc('confirm_payment', params: {
        'p_game_id': gameId,
        'p_player_id': playerId,
      });
    } catch (e) {
      throw GameServiceException(friendlyError(e));
    }
  }

  /// Agent rejects a pending player (payment never arrived) → slot freed,
  /// player notified. Agent-only (enforced in the RPC).
  static Future<void> rejectPayment(String gameId, String playerId) async {
    try {
      await _sb.rpc('reject_payment', params: {
        'p_game_id': gameId,
        'p_player_id': playerId,
      });
    } catch (e) {
      throw GameServiceException(friendlyError(e));
    }
  }

  /// Leaves a game and frees the slot.
  static Future<String?> leaveGame(String gameId) async {
    final uid = SupabaseService.userId;
    if (uid == null) return 'You must be signed in';
    try {
      await _sb
          .from('game_players')
          .delete()
          .eq('game_id', gameId)
          .eq('player_id', uid);
      // TODO: move the decrement into a leave_game_safe RPC (same locking
      // pattern as join_game_safe) to make this fully race-proof.
      final row = await _sb
          .from('games')
          .select('num_slots_filled')
          .eq('id', gameId)
          .single();
      final filled = (row['num_slots_filled'] ?? 0) as int;
      if (filled > 0) {
        await _sb
            .from('games')
            .update({'num_slots_filled': filled - 1}).eq('id', gameId);
      }
      return null;
    } catch (e) {
      return friendlyError(e);
    }
  }

  /// Games the current player joined, newest first.
  static Future<List<Game>> fetchMyGames() async {
    final uid = SupabaseService.userId;
    if (uid == null) return const [];
    try {
      final rows = await _sb
          .from('games')
          .select('*, users!games_agent_id_fkey(full_name, avatar_url), '
              'game_players!inner(player_id, payment_status)')
          .eq('game_players.player_id', uid)
          .order('kickoff', ascending: false);
      return [
        for (final r in rows)
          Game.fromRow(Map<String, dynamic>.from(r), uid: uid)
      ];
    } catch (e) {
      throw GameServiceException(friendlyError(e));
    }
  }

  /// Games created by the current agent (dashboard + Live panel).
  static Future<List<Game>> fetchMyCreatedGames() async {
    final uid = SupabaseService.userId;
    if (uid == null) return const [];
    try {
      final rows = await _sb
          .from('games')
          .select(_gameSelect)
          .eq('agent_id', uid)
          .order('kickoff', ascending: false);
      return [
        for (final r in rows)
          Game.fromRow(Map<String, dynamic>.from(r), uid: uid)
      ];
    } catch (e) {
      throw GameServiceException(friendlyError(e));
    }
  }

  /// The QR image URL from this agent's most recent game, so the create form
  /// can pre-fill it (they rarely change their TNG/bank QR between games).
  static Future<String?> fetchLastQrUrl() async {
    final uid = SupabaseService.userId;
    if (uid == null) return null;
    try {
      final row = await _sb
          .from('games')
          .select('payment_qr_url')
          .eq('agent_id', uid)
          .not('payment_qr_url', 'is', null)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return row?['payment_qr_url'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Inserts a new game (agent), uploading the field photo + payment QR first.
  /// For paid games a QR is required so players know where to pay; pass either
  /// fresh [qrBytes] to upload, or [qrUrl] to reuse a previously uploaded one.
  static Future<void> createGame({
    required String fieldName,
    required String location,
    required String format,
    required DateTime kickoff,
    required String ageGroup,
    required String details,
    required String contact,
    required int numPlayers,
    required double price,
    required double fieldCost,
    required double commission,
    Uint8List? photoBytes,
    Uint8List? qrBytes,
    String? qrUrl,
  }) async {
    final uid = SupabaseService.userId;
    if (uid == null) throw GameServiceException('You must be signed in');
    try {
      final storage = _sb.storage.from('field-photos');

      String? photoUrl;
      if (photoBytes != null) {
        final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await storage.uploadBinary(path, photoBytes);
        photoUrl = storage.getPublicUrl(path);
      }

      // Newly picked QR uploads; otherwise reuse the passed-through URL.
      String? paymentQrUrl = qrUrl;
      if (qrBytes != null) {
        final path = '$uid/qr_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await storage.uploadBinary(path, qrBytes);
        paymentQrUrl = storage.getPublicUrl(path);
      }

      await _sb.from('games').insert({
        'agent_id': uid,
        'field_name': fieldName,
        'location': location,
        'format': format,
        'kickoff': kickoff.toUtc().toIso8601String(),
        'age_group': ageGroup,
        'details': details,
        'contact': contact,
        'num_players': numPlayers,
        'price': price,
        'field_cost': fieldCost,
        'commission': commission,
        'photo_url': photoUrl,
        'payment_qr_url': paymentQrUrl,
      });
    } catch (e) {
      throw GameServiceException(friendlyError(e));
    }
  }

  /// Match status transitions (agent only — enforced by RLS).
  static Future<void> setStatus(String gameId, String status) async {
    try {
      final patch = <String, dynamic>{'status': status};
      if (status == 'live') {
        patch['started_at'] = DateTime.now().toUtc().toIso8601String();
      }
      if (status == 'completed') {
        patch['ended_at'] = DateTime.now().toUtc().toIso8601String();
      }
      await _sb.from('games').update(patch).eq('id', gameId);
    } catch (e) {
      throw GameServiceException(friendlyError(e));
    }
  }

  /// Maps raw Postgrest/storage/network errors to UI-safe messages.
  static String friendlyError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('socketexception') ||
        m.contains('failed host lookup') ||
        m.contains('connection') ||
        m.contains('network')) {
      return 'Check your connection and try again';
    }
    if (m.contains('row-level security') || m.contains('permission')) {
      return "You don't have permission to do that";
    }
    if (m.contains('duplicate key')) {
      return 'Already done — refresh and try again';
    }
    return 'Something went wrong — please try again';
  }
}
