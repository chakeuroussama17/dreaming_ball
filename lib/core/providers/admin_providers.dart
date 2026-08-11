import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/admin_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/tier_badge.dart';

/// True when the hardcoded admin is logged in. Drives admin route access.
final isAdminProvider = StateProvider<bool>((ref) => false);

/// Per-game payout sheet for the admin (collected, owed to agent, paid-out).
final adminPayoutsProvider = FutureProvider<List<PayoutRow>>(
    (ref) => AdminService.fetchPayouts());

/// Per-agent leaderboard for the admin (games, collected, commission).
final agentLeaderboardProvider = FutureProvider.autoDispose<List<AgentLeaderRow>>(
    (ref) => AdminService.fetchAgentLeaderboard());

// ─────────────────────────────────────────────────────────────────────────────
// ANNOUNCEMENTS (feed the home banners)
// ─────────────────────────────────────────────────────────────────────────────

enum BadgeType { tournament, promo, news, update }

BadgeType badgeFromString(String? s) => switch (s) {
      'tournament' => BadgeType.tournament,
      'promo' => BadgeType.promo,
      'news' => BadgeType.news,
      _ => BadgeType.update,
    };

extension BadgeTypeX on BadgeType {
  String get label => switch (this) {
        BadgeType.tournament => 'TOURNAMENT',
        BadgeType.promo => 'PROMO',
        BadgeType.news => 'NEWS',
        BadgeType.update => 'UPDATE',
      };

  /// Lowercase DB value (matches the announcements.badge check constraint).
  String get dbValue => name;

  List<Color> get gradient => switch (this) {
        BadgeType.tournament => const [AppColors.goldActionStart, AppColors.goldActionEnd],
        BadgeType.promo => const [AppColors.gold, AppColors.goldLight],
        BadgeType.news => const [Color(0xFF4A7BA7), AppColors.ice],
        BadgeType.update => const [Color(0xFF5A6780), Color(0xFF8B97AC)],
      };
}

class Announcement {
  final String id;
  final String title;
  final String subtitle;
  final BadgeType badge;
  final bool isActive;
  final Uint8List? photo; // freshly-picked image, pending upload
  final String? photoUrl; // persisted banner image (public storage URL)

  const Announcement({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badge,
    this.isActive = true,
    this.photo,
    this.photoUrl,
  });

  Announcement copyWith({
    String? title,
    String? subtitle,
    BadgeType? badge,
    bool? isActive,
    Uint8List? photo,
    String? photoUrl,
  }) =>
      Announcement(
        id: id,
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        badge: badge ?? this.badge,
        isActive: isActive ?? this.isActive,
        photo: photo ?? this.photo,
        photoUrl: photoUrl ?? this.photoUrl,
      );
}

class AnnouncementsNotifier extends StateNotifier<List<Announcement>> {
  AnnouncementsNotifier() : super(const []) {
    load();
  }

  Future<void> load() async {
    try {
      final rows = await AdminService.fetchAnnouncements();
      state = [
        for (final r in rows)
          Announcement(
            id: r['id'] as String,
            title: (r['title'] ?? '') as String,
            subtitle: (r['subtitle'] ?? '') as String,
            badge: badgeFromString(r['badge'] as String?),
            isActive: (r['is_active'] ?? true) as bool,
            photoUrl: r['photo_url'] as String?,
          )
      ];
    } catch (_) {
      // Keep whatever is in state on a transient failure.
    }
  }

  /// Returns false when the save (or image upload) failed, so the screen
  /// can tell the admin instead of failing silently.
  Future<bool> add(Announcement a) async {
    try {
      final row = await AdminService.addAnnouncement(
        title: a.title,
        subtitle: a.subtitle,
        badge: a.badge.dbValue,
        bannerBytes: a.photo,
      );
      state = [
        Announcement(
          id: row['id'] as String,
          title: a.title,
          subtitle: a.subtitle,
          badge: a.badge,
          isActive: (row['is_active'] ?? true) as bool,
          photoUrl: row['photo_url'] as String?,
        ),
        ...state,
      ];
      // Publishing a new active announcement rings every user's bell
      // (tournaments, promos...). Edits/toggles stay silent.
      if (a.isActive) {
        NotificationService.notifyAllUsersAsAdmin(
          title: a.title,
          body: a.subtitle,
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> update(Announcement a) async {
    state = [for (final x in state) if (x.id == a.id) a else x];
    try {
      await AdminService.updateAnnouncement(
        a.id,
        title: a.title,
        subtitle: a.subtitle,
        badge: a.badge.dbValue,
        isActive: a.isActive,
        bannerBytes: a.photo,
      );
      // Re-fetch so the freshly-uploaded photo URL replaces the local bytes.
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> remove(String id) async {
    state = state.where((x) => x.id != id).toList();
    try {
      await AdminService.removeAnnouncement(id);
    } catch (_) {/* local state already updated */}
  }

  Future<void> toggle(String id) async {
    final current = state.where((x) => x.id == id).firstOrNull;
    if (current == null) return;
    final next = current.copyWith(isActive: !current.isActive);
    state = [for (final x in state) if (x.id == id) next else x];
    try {
      await AdminService.updateAnnouncement(id, isActive: next.isActive);
    } catch (_) {/* local state already updated */}
  }
}

final announcementsProvider =
    StateNotifierProvider<AnnouncementsNotifier, List<Announcement>>(
        (ref) => AnnouncementsNotifier());

/// Only the active announcements, used by the home banner carousel.
final activeAnnouncementsProvider = Provider<List<Announcement>>(
    (ref) => ref.watch(announcementsProvider).where((a) => a.isActive).toList());

// ─────────────────────────────────────────────────────────────────────────────
// AGENT MANAGEMENT
// ─────────────────────────────────────────────────────────────────────────────

enum AdminAgentStatus { pending, approved, rejected, suspended }

extension AdminAgentStatusX on AdminAgentStatus {
  String get label => switch (this) {
        AdminAgentStatus.pending => 'Pending',
        AdminAgentStatus.approved => 'Approved',
        AdminAgentStatus.rejected => 'Rejected',
        AdminAgentStatus.suspended => 'Suspended',
      };

  Color get color => switch (this) {
        AdminAgentStatus.pending => AppColors.warning,
        AdminAgentStatus.approved => AppColors.success,
        AdminAgentStatus.rejected => AppColors.tierElite,
        AdminAgentStatus.suspended => AppColors.gold,
      };
}

class AgentRecord {
  final String id; // = agent_profiles.user_id
  final String name, email, phone, registeredAt, bankName, accountNumber;
  final AdminAgentStatus status;
  final String? rejectionReason;
  final String? idType;
  final String? idNumber;
  final String? accountHolder;
  final String? idFrontPath; // path in private kyc-documents bucket
  final String? idBackPath;

  const AgentRecord({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.registeredAt,
    required this.bankName,
    required this.accountNumber,
    required this.status,
    this.rejectionReason,
    this.idType,
    this.idNumber,
    this.accountHolder,
    this.idFrontPath,
    this.idBackPath,
  });

  AgentRecord copyWith({AdminAgentStatus? status, String? rejectionReason}) =>
      AgentRecord(
        id: id,
        name: name,
        email: email,
        phone: phone,
        registeredAt: registeredAt,
        bankName: bankName,
        accountNumber: accountNumber,
        status: status ?? this.status,
        rejectionReason: rejectionReason ?? this.rejectionReason,
        idType: idType,
        idNumber: idNumber,
        accountHolder: accountHolder,
        idFrontPath: idFrontPath,
        idBackPath: idBackPath,
      );
}

AdminAgentStatus _agentStatusFromString(String? s) => switch (s) {
      'approved' => AdminAgentStatus.approved,
      'rejected' => AdminAgentStatus.rejected,
      'suspended' => AdminAgentStatus.suspended,
      _ => AdminAgentStatus.pending,
    };

class AgentsNotifier extends StateNotifier<List<AgentRecord>> {
  AgentsNotifier() : super(const []) {
    load();
  }

  Future<void> load() async {
    try {
      final rows = await AdminService.fetchAgents();
      state = [
        for (final r in rows)
          () {
            final user = (r['users'] ?? const {}) as Map;
            return AgentRecord(
              id: r['user_id'] as String,
              name: (user['full_name'] ?? 'Agent') as String,
              email: (user['email'] ?? '') as String,
              phone: (user['phone'] ?? '—') as String,
              registeredAt: AdminService.dateLabel(r['created_at'] as String?),
              bankName: (r['bank_name'] ?? '—') as String,
              accountNumber: (r['account_number'] ?? '') as String,
              status: _agentStatusFromString(r['status'] as String?),
              rejectionReason: r['rejection_reason'] as String?,
              idType: r['id_type'] as String?,
              idNumber: r['id_number'] as String?,
              accountHolder: r['account_holder'] as String?,
              idFrontPath: r['id_front_url'] as String?,
              idBackPath: r['id_back_url'] as String?,
            );
          }()
      ];
    } catch (_) {
      // Keep current state on failure.
    }
  }

  Future<void> _set(String id, AdminAgentStatus status, String dbStatus,
      {String? reason}) async {
    state = [
      for (final a in state)
        if (a.id == id)
          a.copyWith(status: status, rejectionReason: reason)
        else
          a,
    ];
    try {
      await AdminService.setAgentStatus(id, dbStatus, reason: reason);
    } catch (_) {/* local state already updated */}
  }

  void approve(String id) {
    _set(id, AdminAgentStatus.approved, 'approved');
    NotificationService.notifyUserAsAdmin(
      userId: id,
      title: 'Verification approved 🎉',
      body: "You're now a verified agent — you can create games and earn.",
    );
  }

  void reject(String id, String reason) {
    _set(id, AdminAgentStatus.rejected, 'rejected', reason: reason);
    NotificationService.notifyUserAsAdmin(
      userId: id,
      title: 'Verification rejected',
      body: 'Reason: $reason. You can resubmit from your profile.',
    );
  }

  void suspend(String id) {
    _set(id, AdminAgentStatus.suspended, 'suspended');
    NotificationService.notifyUserAsAdmin(
      userId: id,
      title: 'Agent account suspended',
      body: 'Your agent privileges are paused. Contact support for details.',
    );
  }
}

final adminAgentsProvider =
    StateNotifierProvider<AgentsNotifier, List<AgentRecord>>(
        (ref) => AgentsNotifier());

// ─────────────────────────────────────────────────────────────────────────────
// USER MANAGEMENT
// ─────────────────────────────────────────────────────────────────────────────

class AppUserRecord {
  final String id, name, email, role; // role: 'Player' | 'Agent'
  final PlayerTier tier;
  final bool banned;
  // Lifetime stats from player_profiles.
  final int games, goals, assists, xp;
  // Profile / demographics (from users).
  final String? phone, gender, country, state, city, registeredAt;
  final int? age;

  const AppUserRecord({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.tier,
    this.banned = false,
    this.games = 0,
    this.goals = 0,
    this.assists = 0,
    this.xp = 0,
    this.phone,
    this.gender,
    this.country,
    this.state,
    this.city,
    this.registeredAt,
    this.age,
  });

  AppUserRecord copyWith({bool? banned}) => AppUserRecord(
        id: id,
        name: name,
        email: email,
        role: role,
        tier: tier,
        banned: banned ?? this.banned,
        games: games,
        goals: goals,
        assists: assists,
        xp: xp,
        phone: phone,
        gender: gender,
        country: country,
        state: state,
        city: city,
        registeredAt: registeredAt,
        age: age,
      );
}

/// Age in whole years from an ISO date string, or null.
int? _ageFromDob(String? iso) {
  if (iso == null) return null;
  final dob = DateTime.tryParse(iso);
  if (dob == null) return null;
  final now = DateTime.now();
  var a = now.year - dob.year;
  if (now.month < dob.month ||
      (now.month == dob.month && now.day < dob.day)) {
    a--;
  }
  return a < 0 || a > 120 ? null : a;
}

class UsersNotifier extends StateNotifier<List<AppUserRecord>> {
  UsersNotifier() : super(const []) {
    load();
  }

  Future<void> load() async {
    try {
      final rows = await AdminService.fetchUsers();
      state = [
        for (final r in rows)
          () {
            final profiles = r['player_profiles'];
            final profile = (profiles is List
                ? (profiles.isEmpty ? const {} : profiles.first)
                : (profiles ?? const {})) as Map;
            return AppUserRecord(
              id: r['id'] as String,
              name: (r['full_name'] ?? 'Player') as String,
              email: (r['email'] ?? '') as String,
              role: (r['role'] == 'agent') ? 'Agent' : 'Player',
              tier: playerTierFromLabel(profile['current_tier'] as String?),
              banned: (r['is_banned'] ?? false) as bool,
              games: (profile['total_games_played'] ?? 0) as int,
              goals: (profile['total_goals'] ?? 0) as int,
              assists: (profile['total_assists'] ?? 0) as int,
              xp: (profile['total_xp'] ?? 0) as int,
              phone: r['phone'] as String?,
              gender: r['gender'] as String?,
              country: r['country'] as String?,
              state: r['state'] as String?,
              city: r['city'] as String?,
              registeredAt: AdminService.dateLabel(r['created_at'] as String?),
              age: _ageFromDob(r['date_of_birth'] as String?),
            );
          }()
      ];
    } catch (_) {
      // Keep current state on failure.
    }
  }

  Future<void> setBanned(String id, bool banned) async {
    state = [
      for (final u in state) if (u.id == id) u.copyWith(banned: banned) else u,
    ];
    try {
      await AdminService.setBanned(id, banned);
    } catch (_) {/* local state already updated */}
  }
}

final adminUsersProvider =
    StateNotifierProvider<UsersNotifier, List<AppUserRecord>>(
        (ref) => UsersNotifier());

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN DISPUTES
// ─────────────────────────────────────────────────────────────────────────────

enum AdminDisputeStatus { open, resolved, escalated }

class AdminDispute {
  final String id, game, date, player, agent, statType, reason;
  final int recorded, claimed;
  final AdminDisputeStatus status;

  const AdminDispute({
    required this.id,
    required this.game,
    required this.date,
    required this.player,
    required this.agent,
    required this.statType,
    required this.reason,
    required this.recorded,
    required this.claimed,
    required this.status,
  });

  AdminDispute copyWith({AdminDisputeStatus? status}) => AdminDispute(
        id: id,
        game: game,
        date: date,
        player: player,
        agent: agent,
        statType: statType,
        reason: reason,
        recorded: recorded,
        claimed: claimed,
        status: status ?? this.status,
      );
}

AdminDisputeStatus _disputeStatusFromString(String? s) => switch (s) {
      'resolved' => AdminDisputeStatus.resolved,
      'escalated' => AdminDisputeStatus.escalated,
      _ => AdminDisputeStatus.open,
    };

String _statTypeLabel(String? t) => switch (t) {
      'goals' => 'Goals',
      'assists' => 'Assists',
      'goals_conceded' => 'Goals Conceded',
      'good_behavior' => 'Good Behavior',
      _ => t ?? '—',
    };

class AdminDisputesNotifier extends StateNotifier<List<AdminDispute>> {
  AdminDisputesNotifier() : super(const []) {
    load();
  }

  Future<void> load() async {
    try {
      final rows = await AdminService.fetchDisputes();
      state = [
        for (final r in rows)
          AdminDispute(
            id: r['id'] as String,
            game: ((r['games'] as Map?)?['field_name'] ?? 'Game') as String,
            date: AdminService.dateLabel(r['created_at'] as String?),
            player: ((r['player'] as Map?)?['full_name'] ?? 'Player') as String,
            agent: ((r['agent'] as Map?)?['full_name'] ?? 'Agent') as String,
            statType: _statTypeLabel(r['stat_type'] as String?),
            reason: (r['reason'] ?? '') as String,
            recorded: (r['recorded_value'] ?? 0) as int,
            claimed: (r['claimed_value'] ?? 0) as int,
            status: _disputeStatusFromString(r['status'] as String?),
          )
      ];
    } catch (_) {
      // Keep current state on failure.
    }
  }

  void _setLocal(String id, AdminDisputeStatus status) => state = [
        for (final d in state) if (d.id == id) d.copyWith(status: status) else d,
      ];

  Future<void> acceptPlayer(String id) async {
    _setLocal(id, AdminDisputeStatus.resolved);
    try {
      await AdminService.acceptPlayer(id);
    } catch (_) {/* local state already updated */}
  }

  Future<void> keepAgent(String id) async {
    _setLocal(id, AdminDisputeStatus.resolved);
    try {
      await AdminService.keepAgent(id);
    } catch (_) {/* local state already updated */}
  }

  Future<void> escalate(String id) async {
    _setLocal(id, AdminDisputeStatus.escalated);
    try {
      await AdminService.escalate(id);
    } catch (_) {/* local state already updated */}
  }
}

final adminDisputesProvider =
    StateNotifierProvider<AdminDisputesNotifier, List<AdminDispute>>(
        (ref) => AdminDisputesNotifier());
