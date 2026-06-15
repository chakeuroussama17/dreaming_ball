import 'supabase_service.dart';

/// One row of public.notifications, owned by the signed-in user.
class AppNotification {
  final String id;
  final String type; // game | stats | dispute | payment | announcement | system
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromRow(Map<String, dynamic> r) => AppNotification(
        id: r['id'] as String,
        type: (r['type'] ?? 'system') as String,
        title: (r['title'] ?? '') as String,
        body: (r['body'] ?? '') as String,
        isRead: (r['is_read'] ?? false) as bool,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
      );

  /// '12m ago', '2h ago', '3d ago'...
  String get timeLabel {
    final d = DateTime.now().difference(createdAt);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

class NotificationService {
  static final _sb = SupabaseService.supabase;

  /// Realtime stream of the signed-in user's notifications, newest first.
  static Stream<List<AppNotification>> myNotifications() {
    final uid = SupabaseService.userId;
    if (uid == null) return Stream.value(const []);
    return _sb
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(50)
        .map((rows) =>
            [for (final r in rows) AppNotification.fromRow(r)]);
  }

  static Future<void> markAllRead() async {
    final uid = SupabaseService.userId;
    if (uid == null) return;
    try {
      await _sb
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', uid)
          .eq('is_read', false);
    } catch (_) {
      // Badge clears on the next successful pass.
    }
  }

  // ── Senders (security-definer RPCs; guards live in the database) ────────

  /// Agent → everyone on their game's roster. Fire-and-forget.
  static Future<void> notifyGamePlayers({
    required String gameId,
    required String title,
    required String body,
    String type = 'game',
  }) async {
    try {
      await _sb.rpc('notify_game_players', params: {
        'p_game_id': gameId,
        'p_title': title,
        'p_body': body,
        'p_type': type,
      });
    } catch (_) {
      // Notifications are best-effort; the feature works without them.
    }
  }

  /// Player → the game's agent.
  static Future<void> notifyGameAgent({
    required String gameId,
    required String title,
    required String body,
    String type = 'dispute',
  }) async {
    try {
      await _sb.rpc('notify_game_agent', params: {
        'p_game_id': gameId,
        'p_title': title,
        'p_body': body,
        'p_type': type,
      });
    } catch (_) {}
  }

  /// Agent → one player of their game.
  static Future<void> notifyPlayer({
    required String gameId,
    required String playerId,
    required String title,
    required String body,
    String type = 'dispute',
  }) async {
    try {
      await _sb.rpc('notify_player', params: {
        'p_game_id': gameId,
        'p_player_id': playerId,
        'p_title': title,
        'p_body': body,
        'p_type': type,
      });
    } catch (_) {}
  }

  /// Admin → every active user (tournament / announcement blast).
  static Future<void> notifyAllUsersAsAdmin({
    required String title,
    required String body,
    String type = 'announcement',
  }) async {
    try {
      await _sb.rpc('notify_all_users_admin', params: {
        'p_title': title,
        'p_body': body,
        'p_type': type,
      });
    } catch (_) {}
  }

  /// Admin → anyone (verification results, bans...).
  static Future<void> notifyUserAsAdmin({
    required String userId,
    required String title,
    required String body,
    String type = 'system',
  }) async {
    try {
      await _sb.rpc('notify_user_admin', params: {
        'p_user_id': userId,
        'p_title': title,
        'p_body': body,
        'p_type': type,
      });
    } catch (_) {}
  }
}
