import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'game_service.dart' show GameServiceException;
import 'supabase_service.dart';

/// users + player_profiles merged into one view of a player.
class PlayerProfile {
  final String userId;
  final String fullName;
  final String email;
  final String? phone;
  final String role;
  final String? avatarUrl;
  final String position;
  final String ageGroup;
  final String tier;
  final int totalXp;
  final int totalGoals;
  final int totalAssists;
  final int totalGamesPlayed;
  final int cleanSheets;
  final String? city;
  final String? state;

  const PlayerProfile({
    required this.userId,
    required this.fullName,
    required this.email,
    this.phone,
    required this.role,
    this.avatarUrl,
    required this.position,
    required this.ageGroup,
    required this.tier,
    required this.totalXp,
    required this.totalGoals,
    required this.totalAssists,
    required this.totalGamesPlayed,
    required this.cleanSheets,
    this.city,
    this.state,
  });

  factory PlayerProfile.fromRow(Map<String, dynamic> profile) {
    final user = (profile['users'] ?? const {}) as Map;
    return PlayerProfile(
      userId: profile['user_id'] as String,
      fullName: (user['full_name'] ?? 'Player') as String,
      email: (user['email'] ?? '') as String,
      phone: user['phone'] as String?,
      role: (user['role'] ?? 'player') as String,
      avatarUrl: user['avatar_url'] as String?,
      position: (profile['position'] ?? 'Striker') as String,
      ageGroup: (profile['age_group'] ?? '21-25') as String,
      tier: (profile['current_tier'] ?? 'Beginner') as String,
      totalXp: (profile['total_xp'] ?? 0) as int,
      totalGoals: (profile['total_goals'] ?? 0) as int,
      totalAssists: (profile['total_assists'] ?? 0) as int,
      totalGamesPlayed: (profile['total_games_played'] ?? 0) as int,
      cleanSheets: (profile['clean_sheets'] ?? 0) as int,
      city: user['city'] as String?,
      state: user['state'] as String?,
    );
  }
}

/// One row of "My Games" — a confirmed/pending stat line with game context.
class RecentGame {
  final String gameId;
  final String fieldName;
  final String dateLabel;
  final int goals;
  final int assists;
  final int xp;
  final String status; // pending | confirmed | disputed

  const RecentGame({
    required this.gameId,
    required this.fieldName,
    required this.dateLabel,
    required this.goals,
    required this.assists,
    required this.xp,
    required this.status,
  });
}

/// One ranked row of the leaderboard.
class LeaderboardEntry {
  final int rank;
  final String userId;
  final String name;
  final String position;
  final String tier;
  final int xp;
  final String? avatarUrl;
  final bool isYou;

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.name,
    required this.position,
    required this.tier,
    required this.xp,
    this.avatarUrl,
    required this.isYou,
  });
}

class ProfileService {
  static final _sb = SupabaseService.supabase;

  static const _profileSelect = '*, '
      'users!player_profiles_user_id_fkey(full_name, email, phone, role, '
      'avatar_url, city, state)';

  static Future<PlayerProfile?> fetchMyProfile() async {
    final uid = SupabaseService.userId;
    if (uid == null) return null;
    return fetchPlayerById(uid);
  }

  static Future<PlayerProfile?> fetchPlayerById(String userId) async {
    try {
      final row = await _sb
          .from('player_profiles')
          .select(_profileSelect)
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return null;
      return PlayerProfile.fromRow(Map<String, dynamic>.from(row));
    } catch (e) {
      throw GameServiceException(
          'Could not load profile — check your connection');
    }
  }

  /// Updates name/phone on users and position/age group on player_profiles;
  /// uploads a new avatar when provided.
  static Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? position,
    String? ageGroup,
    Uint8List? avatarBytes,
  }) async {
    final uid = SupabaseService.userId;
    if (uid == null) throw GameServiceException('You must be signed in');
    try {
      final userPatch = <String, dynamic>{
        'full_name': ?fullName,
        'phone': ?phone,
      };
      if (avatarBytes != null) {
        final storage = _sb.storage.from('avatars');
        final path = '$uid/avatar.jpg';
        await storage.uploadBinary(path, avatarBytes,
            fileOptions: const FileOptions(
                upsert: true, contentType: 'image/jpeg'));
        // Cache-bust: same path, new content.
        userPatch['avatar_url'] =
            '${storage.getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
      }
      if (userPatch.isNotEmpty) {
        await _sb.from('users').update(userPatch).eq('id', uid);
      }

      final profilePatch = <String, dynamic>{
        'position': ?position,
        'age_group': ?ageGroup,
      };
      if (profilePatch.isNotEmpty) {
        await _sb
            .from('player_profiles')
            .update(profilePatch)
            .eq('user_id', uid);
      }
    } catch (e) {
      throw GameServiceException('Could not save profile — try again');
    }
  }

  /// Latest stat lines for the signed-in player, with game context.
  static Future<List<RecentGame>> fetchMyRecentGames({int limit = 5}) async {
    final uid = SupabaseService.userId;
    if (uid == null) return const [];
    try {
      final rows = await _sb
          .from('player_stats')
          .select('game_id, goals, assists, xp_earned, status, created_at, '
              'games(field_name, kickoff)')
          .eq('player_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);
      return [
        for (final r in rows)
          () {
            final game = (r['games'] ?? const {}) as Map;
            final kickoffRaw = game['kickoff'] as String?;
            final kickoff =
                kickoffRaw != null ? DateTime.parse(kickoffRaw).toLocal() : null;
            return RecentGame(
              gameId: r['game_id'] as String,
              fieldName: (game['field_name'] ?? 'Game') as String,
              dateLabel: kickoff != null
                  ? DateFormat('MMM d, yyyy').format(kickoff)
                  : '—',
              goals: (r['goals'] ?? 0) as int,
              assists: (r['assists'] ?? 0) as int,
              xp: (r['xp_earned'] ?? 0) as int,
              status: (r['status'] ?? 'pending') as String,
            );
          }()
      ];
    } catch (e) {
      throw GameServiceException('Could not load recent games');
    }
  }

  /// Ranked players. All-time ranks by player_profiles.total_xp; 'this_week'
  /// re-ranks by xp_earned summed from player_stats since Monday.
  static Future<List<LeaderboardEntry>> fetchLeaderboard({
    String? position,
    String? ageGroup,
    String period = 'all_time',
    int limit = 100,
  }) async {
    try {
      var query = _sb.from('player_profiles').select(_profileSelect);
      if (position != null && position != 'All') {
        query = query.eq('position', position);
      }
      if (ageGroup != null && ageGroup != 'All') {
        query = query.eq('age_group', ageGroup);
      }
      final rows =
          await query.order('total_xp', ascending: false).limit(limit);
      final profiles = [
        for (final r in rows)
          PlayerProfile.fromRow(Map<String, dynamic>.from(r))
      ];

      Map<String, int>? weeklyXp;
      if (period == 'this_week') {
        final now = DateTime.now();
        final monday = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        final statRows = await _sb
            .from('player_stats')
            .select('player_id, xp_earned')
            .eq('status', 'confirmed')
            .gte('created_at', monday.toUtc().toIso8601String());
        weeklyXp = {};
        for (final r in statRows) {
          final pid = r['player_id'] as String;
          weeklyXp[pid] = (weeklyXp[pid] ?? 0) + ((r['xp_earned'] ?? 0) as int);
        }
      }

      final uid = SupabaseService.userId;
      var entries = [
        for (final p in profiles)
          (
            profile: p,
            xp: weeklyXp == null ? p.totalXp : (weeklyXp[p.userId] ?? 0)
          )
      ];
      if (weeklyXp != null) {
        entries.sort((a, b) => b.xp.compareTo(a.xp));
      }

      return [
        for (var i = 0; i < entries.length; i++)
          LeaderboardEntry(
            rank: i + 1,
            userId: entries[i].profile.userId,
            name: entries[i].profile.fullName,
            position: entries[i].profile.position,
            tier: entries[i].profile.tier,
            xp: entries[i].xp,
            avatarUrl: entries[i].profile.avatarUrl,
            isYou: entries[i].profile.userId == uid,
          )
      ];
    } catch (e) {
      throw GameServiceException('Could not load leaderboard');
    }
  }
}
