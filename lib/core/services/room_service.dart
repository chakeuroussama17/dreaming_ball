import 'game_service.dart' show GameServiceException;
import 'supabase_service.dart';

/// A private room row.
class Room {
  final String id;
  final String creatorId;
  final String name;
  final String? location;
  final int maxPlayers;
  final String code;
  final DateTime? scheduledAt; // match start time (local)

  const Room({
    required this.id,
    required this.creatorId,
    required this.name,
    this.location,
    required this.maxPlayers,
    required this.code,
    this.scheduledAt,
  });

  factory Room.fromRow(Map<String, dynamic> r) => Room(
        id: r['id'] as String,
        creatorId: r['creator_id'] as String,
        name: (r['name'] ?? 'Room') as String,
        location: r['location'] as String?,
        maxPlayers: (r['max_players'] ?? 10) as int,
        code: (r['code'] ?? '') as String,
        scheduledAt: r['scheduled_at'] == null
            ? null
            : DateTime.parse(r['scheduled_at'] as String).toLocal(),
      );

  /// A room is "ended" 2 hours after its scheduled start. Rooms with no date
  /// set are treated as always upcoming (never ended).
  bool get isEnded =>
      scheduledAt != null &&
      DateTime.now().isAfter(scheduledAt!.add(const Duration(hours: 2)));
}

/// A member of a room, with profile data for the roster list.
class RoomMember {
  final String userId;
  final String name;
  final String position;
  final String tier;
  final String? avatarUrl;
  final bool isCreator;

  const RoomMember({
    required this.userId,
    required this.name,
    required this.position,
    required this.tier,
    this.avatarUrl,
    required this.isCreator,
  });
}

/// A room in the "My Rooms" list, with how many have joined.
class RoomSummary {
  final Room room;
  final int memberCount;
  final bool isCreator;
  const RoomSummary({
    required this.room,
    required this.memberCount,
    required this.isCreator,
  });
}

class RoomService {
  static final _sb = SupabaseService.supabase;

  /// Every room the signed-in user created or joined, with member counts —
  /// powers the "My Rooms" list so they can return to a room any time.
  static Future<List<RoomSummary>> fetchMyRooms() async {
    final uid = SupabaseService.userId;
    if (uid == null) return const [];
    try {
      final rows = await _sb
          .from('room_players')
          .select('private_rooms!inner('
              'id, creator_id, name, location, max_players, code, scheduled_at)')
          .eq('player_id', uid);

      final result = <RoomSummary>[];
      for (final r in rows) {
        final rr = r['private_rooms'];
        if (rr is! Map) continue;
        final room = Room.fromRow(Map<String, dynamic>.from(rr));
        final count =
            await _sb.from('room_players').count().eq('room_id', room.id);
        result.add(RoomSummary(
          room: room,
          memberCount: count,
          isCreator: room.creatorId == uid,
        ));
      }
      return result;
    } catch (e) {
      throw GameServiceException('Could not load your rooms');
    }
  }

  /// Creates a room with a server-generated unique 6-char code and adds the
  /// creator as the first member.
  /// (The schema keeps rooms simple: no date/time columns yet — the room is
  /// a persistent squad; attach games to it later.)
  static Future<Room> createRoom({
    required String name,
    String? location,
    required int maxPlayers,
    DateTime? scheduledAt,
  }) async {
    final uid = SupabaseService.userId;
    if (uid == null) throw GameServiceException('You must be signed in');
    try {
      final code = await _sb.rpc('generate_room_code') as String;

      final row = await _sb
          .from('private_rooms')
          .insert({
            'creator_id': uid,
            'name': name,
            'location': location,
            'max_players': maxPlayers,
            'code': code,
            'scheduled_at': scheduledAt?.toUtc().toIso8601String(),
          })
          .select()
          .single();

      await _sb.from('room_players').insert({
        'room_id': row['id'],
        'player_id': uid,
      });

      return Room.fromRow(Map<String, dynamic>.from(row));
    } catch (e) {
      throw GameServiceException('Could not create the room — try again');
    }
  }

  /// Looks up a room by its 6-char code and joins it.
  static Future<Room> joinRoomByCode(String code) async {
    final uid = SupabaseService.userId;
    if (uid == null) throw GameServiceException('You must be signed in');
    try {
      final row = await _sb
          .from('private_rooms')
          .select()
          .eq('code', code.trim().toUpperCase())
          .maybeSingle();
      if (row == null) {
        throw GameServiceException('No room found with that code');
      }
      final room = Room.fromRow(Map<String, dynamic>.from(row));

      final existing = await _sb
          .from('room_players')
          .select('id')
          .eq('room_id', room.id)
          .eq('player_id', uid)
          .maybeSingle();
      if (existing == null) {
        final memberCount = await _sb
            .from('room_players')
            .count()
            .eq('room_id', room.id);
        if (memberCount >= room.maxPlayers) {
          throw GameServiceException('That room is full');
        }
        await _sb.from('room_players').insert({
          'room_id': room.id,
          'player_id': uid,
        });
      }
      return room;
    } on GameServiceException {
      rethrow;
    } catch (e) {
      throw GameServiceException('Could not join the room — try again');
    }
  }

  /// Room + members with tiers for the detail screen.
  static Future<(Room, List<RoomMember>)> fetchRoomDetails(
      String roomId) async {
    try {
      final roomRow = await _sb
          .from('private_rooms')
          .select()
          .eq('id', roomId)
          .single();
      final room = Room.fromRow(Map<String, dynamic>.from(roomRow));

      final memberRows = await _sb
          .from('room_players')
          .select('player_id, '
              'users!room_players_player_id_fkey(full_name, avatar_url, '
              'player_profiles(position, current_tier))')
          .eq('room_id', roomId);

      final members = [
        for (final r in memberRows)
          () {
            final user = (r['users'] ?? const {}) as Map;
            final profiles = user['player_profiles'];
            final profile = (profiles is List
                ? (profiles.isEmpty ? const {} : profiles.first)
                : (profiles ?? const {})) as Map;
            return RoomMember(
              userId: r['player_id'] as String,
              name: (user['full_name'] ?? 'Player') as String,
              position: (profile['position'] ?? 'Striker') as String,
              tier: (profile['current_tier'] ?? 'Beginner') as String,
              avatarUrl: user['avatar_url'] as String?,
              isCreator: r['player_id'] == room.creatorId,
            );
          }()
      ];
      return (room, members);
    } catch (e) {
      throw GameServiceException('Could not load the room');
    }
  }

  /// Same as fetchRoomDetails but addressed by invite code.
  static Future<(Room, List<RoomMember>)> fetchRoomByCode(String code) async {
    final row = await _sb
        .from('private_rooms')
        .select('id')
        .eq('code', code.trim().toUpperCase())
        .maybeSingle();
    if (row == null) throw GameServiceException('No room found with that code');
    return fetchRoomDetails(row['id'] as String);
  }

  /// Leaves a room. If the creator leaves, the room is deleted
  /// (cascade removes its members) — the schema has no cancelled status.
  static Future<void> leaveRoom(String roomId) async {
    final uid = SupabaseService.userId;
    if (uid == null) return;
    try {
      final room = await _sb
          .from('private_rooms')
          .select('creator_id')
          .eq('id', roomId)
          .single();
      if (room['creator_id'] == uid) {
        await _sb.from('private_rooms').delete().eq('id', roomId);
        return;
      }
      await _sb
          .from('room_players')
          .delete()
          .eq('room_id', roomId)
          .eq('player_id', uid);
    } catch (e) {
      throw GameServiceException('Could not leave the room — try again');
    }
  }
}
