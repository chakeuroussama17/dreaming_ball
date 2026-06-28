import 'supabase_service.dart';

/// One message in an agent↔admin support thread.
class SupportMessage {
  final String id;
  final String agentId;
  final bool isAdmin; // authored by the admin?
  final String body;
  final DateTime createdAt;

  const SupportMessage({
    required this.id,
    required this.agentId,
    required this.isAdmin,
    required this.body,
    required this.createdAt,
  });

  factory SupportMessage.fromRow(Map<String, dynamic> r) => SupportMessage(
        id: r['id'] as String,
        agentId: r['agent_id'] as String,
        isAdmin: (r['is_admin'] ?? false) as bool,
        body: (r['body'] ?? '') as String,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
      );
}

/// Admin inbox row: one per agent thread (latest message + unread count).
class SupportThread {
  final String agentId;
  final String fullName;
  final String lastBody;
  final DateTime lastAt;
  final int unread;

  const SupportThread({
    required this.agentId,
    required this.fullName,
    required this.lastBody,
    required this.lastAt,
    required this.unread,
  });

  factory SupportThread.fromRow(Map<String, dynamic> r) => SupportThread(
        agentId: r['agent_id'] as String,
        fullName: (r['full_name'] ?? 'Agent') as String,
        lastBody: (r['last_body'] ?? '') as String,
        lastAt: DateTime.parse(r['last_at'] as String).toLocal(),
        unread: (r['unread'] ?? 0) as int,
      );
}

/// Agent↔admin support chat, backed by support_messages (one thread per agent).
class ChatService {
  static final _sb = SupabaseService.supabase;

  // ── Agent side (own thread) ────────────────────────────────────────────────

  static Stream<List<SupportMessage>> myThreadStream() {
    final uid = SupabaseService.userId;
    if (uid == null) return Stream.value(const []);
    return _sb
        .from('support_messages')
        .stream(primaryKey: ['id'])
        .eq('agent_id', uid)
        .order('created_at')
        .map((rows) => [
              for (final r in rows)
                SupportMessage.fromRow(Map<String, dynamic>.from(r))
            ]);
  }

  static Future<void> sendAsAgent(String body) async {
    final uid = SupabaseService.userId;
    if (uid == null || body.trim().isEmpty) return;
    await _sb.from('support_messages').insert({
      'agent_id': uid,
      'is_admin': false,
      'body': body.trim(),
      'read_by_agent': true,
    });
  }

  /// Marks the admin's replies as read by the agent.
  static Future<void> markReadAsAgent() async {
    final uid = SupabaseService.userId;
    if (uid == null) return;
    await _sb
        .from('support_messages')
        .update({'read_by_agent': true})
        .eq('agent_id', uid)
        .eq('is_admin', true)
        .eq('read_by_agent', false);
  }

  static Stream<int> myUnreadStream() {
    final uid = SupabaseService.userId;
    if (uid == null) return Stream.value(0);
    return _sb
        .from('support_messages')
        .stream(primaryKey: ['id'])
        .eq('agent_id', uid)
        .map((rows) => rows
            .where((r) => (r['is_admin'] ?? false) == true && (r['read_by_agent'] ?? false) == false)
            .length);
  }

  // ── Admin side (any thread) ────────────────────────────────────────────────

  static Future<List<SupportThread>> adminThreads() async {
    final rows = await _sb.rpc('admin_support_threads');
    return [
      for (final r in (rows as List))
        SupportThread.fromRow(Map<String, dynamic>.from(r))
    ];
  }

  static Stream<List<SupportMessage>> threadStream(String agentId) {
    return _sb
        .from('support_messages')
        .stream(primaryKey: ['id'])
        .eq('agent_id', agentId)
        .order('created_at')
        .map((rows) => [
              for (final r in rows)
                SupportMessage.fromRow(Map<String, dynamic>.from(r))
            ]);
  }

  static Future<void> sendAsAdmin(String agentId, String body) async {
    if (body.trim().isEmpty) return;
    await _sb.from('support_messages').insert({
      'agent_id': agentId,
      'is_admin': true,
      'body': body.trim(),
      'read_by_admin': true,
    });
  }

  static Future<void> markReadAsAdmin(String agentId) async {
    await _sb
        .from('support_messages')
        .update({'read_by_admin': true})
        .eq('agent_id', agentId)
        .eq('is_admin', false)
        .eq('read_by_admin', false);
  }
}
