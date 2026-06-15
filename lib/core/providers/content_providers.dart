import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/dispute_service.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../services/supabase_service.dart';
import '../widgets/tier_badge.dart';
import 'admin_providers.dart';

/// Clears every cached provider that is scoped to the signed-in user.
/// MUST be called after login, registration and logout — otherwise the new
/// session keeps seeing the previous user's profile, games and bell.
void resetUserScopedProviders(WidgetRef ref) {
  ref.invalidate(myProfileProvider);
  ref.invalidate(myRecentGamesProvider);
  ref.invalidate(myPendingStatsProvider);
  ref.invalidate(agentDisputesProvider);
  ref.invalidate(notificationsStreamProvider);
  ref.invalidate(leaderboardProvider); // isYou flag is per-user
  ref.invalidate(topPlayersProvider);
  ref.invalidate(announcementsRemoteProvider);
}

/// Realtime feed of the signed-in user's notifications (newest first).
final notificationsStreamProvider =
    StreamProvider<List<AppNotification>>((ref) =>
        NotificationService.myNotifications());

/// Unread count for the bell badge — updates live.
final unreadNotificationsProvider = Provider<int>((ref) =>
    ref
        .watch(notificationsStreamProvider)
        .valueOrNull
        ?.where((n) => !n.isRead)
        .length ??
    0);

/// Player's stat lines still inside the 3-hour dispute window.
final myPendingStatsProvider = FutureProvider<List<PendingStat>>(
    (ref) => DisputeService.fetchMyPendingStats());

/// Open disputes raised against the signed-in agent's games.
final agentDisputesProvider = FutureProvider<List<Dispute>>(
    (ref) => DisputeService.fetchAgentDisputes());

/// The signed-in player's merged users + player_profiles data.
final myProfileProvider = FutureProvider<PlayerProfile?>(
    (ref) => ProfileService.fetchMyProfile());

/// A specific player's profile (guest view from leaderboard/top players).
final playerProfileProvider = FutureProvider.family<PlayerProfile?, String>(
    (ref, userId) => ProfileService.fetchPlayerById(userId));

/// The signed-in player's latest stat lines with game context.
final myRecentGamesProvider = FutureProvider<List<RecentGame>>(
    (ref) => ProfileService.fetchMyRecentGames());

/// Ranked leaderboard. Family key: `'position|period|ageGroup'`.
final leaderboardProvider =
    FutureProvider.family<List<LeaderboardEntry>, String>((ref, key) {
  final parts = key.split('|');
  return ProfileService.fetchLeaderboard(
    position: parts[0] == 'All' ? null : parts[0],
    period: parts.length > 1 ? parts[1] : 'all_time',
    ageGroup: parts.length > 2 && parts[2] != 'All' ? parts[2] : null,
  );
});

/// Active announcements from Supabase — feed the home banner carousel.
final announcementsRemoteProvider =
    FutureProvider<List<Announcement>>((ref) async {
  final rows = await SupabaseService.supabase
      .from('announcements')
      .select()
      .eq('is_active', true)
      .order('created_at', ascending: false);
  return [
    for (final r in rows)
      Announcement(
        id: r['id'] as String,
        title: (r['title'] ?? '') as String,
        subtitle: (r['subtitle'] ?? '') as String,
        badge: _badgeFromString(r['badge'] as String?),
        photoUrl: r['photo_url'] as String?,
      )
  ];
});

BadgeType _badgeFromString(String? s) => switch (s) {
      'tournament' => BadgeType.tournament,
      'promo' => BadgeType.promo,
      'news' => BadgeType.news,
      _ => BadgeType.update,
    };

/// One row of the "Top Players This Week" rail.
class TopPlayer {
  final String userId;
  final String name;
  final String position;
  final PlayerTier tier;
  final int xp;
  final String? avatarUrl;

  const TopPlayer({
    required this.userId,
    required this.name,
    required this.position,
    required this.tier,
    required this.xp,
    this.avatarUrl,
  });
}

/// Top 5 players by lifetime XP (player_profiles joined with users).
final topPlayersProvider = FutureProvider<List<TopPlayer>>((ref) async {
  final rows = await SupabaseService.supabase
      .from('player_profiles')
      .select('user_id, position, current_tier, total_xp, '
          'users!player_profiles_user_id_fkey(full_name, avatar_url)')
      .order('total_xp', ascending: false)
      .limit(5);
  return [
    for (final r in rows)
      TopPlayer(
        userId: r['user_id'] as String,
        name: ((r['users'] as Map?)?['full_name'] ?? 'Player') as String,
        position: (r['position'] ?? 'Striker') as String,
        tier: playerTierFromLabel(r['current_tier'] as String?),
        xp: (r['total_xp'] ?? 0) as int,
        avatarUrl: (r['users'] as Map?)?['avatar_url'] as String?,
      )
  ];
});
