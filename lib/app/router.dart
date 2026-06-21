import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/providers/session_provider.dart';
import '../core/providers/admin_providers.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/auth/screens/welcome_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/game/screens/game_detail_screen.dart';
import '../features/game/screens/create_game_screen.dart';
import '../features/game/screens/attendance_screen.dart';
import '../features/game/screens/stats_entry_screen.dart';
import '../features/game/screens/live_match_screen.dart';
import '../features/payment/screens/payment_screen.dart';
import '../features/payment/screens/confirmed_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/leaderboard/screens/leaderboard_screen.dart';
import '../features/tournaments/screens/tournament_list_screen.dart';
import '../features/tournaments/screens/tournament_apply_screen.dart';
import '../features/tournaments/screens/tournament_detail_screen.dart';
import '../features/tournaments/screens/build_teams_screen.dart';
import '../features/tournaments/screens/bracket_view_screen.dart';
import '../features/tournaments/screens/schedule_matches_screen.dart';
import '../features/tournaments/screens/tournament_live_match_screen.dart';
import '../features/private_room/screens/private_room_screen.dart';
import '../features/private_room/screens/room_detail_screen.dart';
import '../features/dispute/screens/dispute_screen.dart';
import '../features/agent/screens/agent_dashboard_screen.dart';
import '../features/admin/screens/admin_dashboard_screen.dart';
import '../features/admin/screens/agent_management_screen.dart';
import '../features/admin/screens/admin_agent_stats_screen.dart';
import '../features/admin/screens/admin_tournament_approval_screen.dart';
import '../features/admin/screens/announcements_screen.dart';
import '../features/admin/screens/user_management_screen.dart';
import '../features/admin/screens/admin_disputes_screen.dart';
import '../features/admin/screens/admin_payouts_screen.dart';
import '../features/admin/screens/admin_payout_detail_screen.dart';

/// Router with role-based guards. Built as a provider so it can read session
/// state for redirects.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // Admin-only routes.
      if (loc.startsWith('/admin')) {
        return ref.read(isAdminProvider) ? null : '/home';
      }

      final role = ref.read(userRoleProvider);
      final approved = ref.read(agentVerificationProvider) ==
          AgentVerification.approved;

      // Approved-agent-only routes.
      const approvedAgentOnly = ['/create-game', '/attendance', '/stats'];
      if (approvedAgentOnly.any((p) => loc.startsWith(p))) {
        return (role == UserRole.agent && approved) ? null : '/home';
      }

      // Agent dashboard: any agent (shows verification banner if unapproved).
      if (loc.startsWith('/agent-dashboard')) {
        return role == UserRole.agent ? null : '/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', name: 'splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/onboarding', name: 'onboarding', builder: (c, s) => const OnboardingScreen()),
      GoRoute(path: '/welcome', name: 'welcome', builder: (c, s) => const WelcomeScreen()),
      GoRoute(path: '/login', name: 'login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/register', name: 'register', builder: (c, s) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', name: 'forgot-password', builder: (c, s) => const ForgotPasswordScreen()),
      GoRoute(path: '/home', name: 'home', builder: (c, s) => const HomeScreen()),
      GoRoute(path: '/game/:id', name: 'game-detail', builder: (c, s) => GameDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/create-game', name: 'create-game', builder: (c, s) => const CreateGameScreen()),
      GoRoute(path: '/attendance/:id', name: 'attendance', builder: (c, s) => AttendanceScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/stats/:id', name: 'stats-entry', builder: (c, s) => StatsEntryScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/live-match/:id', name: 'live-match', builder: (c, s) => LiveMatchScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/payment/:id', name: 'payment', builder: (c, s) => PaymentScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/confirmed', name: 'confirmed', builder: (c, s) => const ConfirmedScreen()),
      GoRoute(path: '/profile', name: 'profile', builder: (c, s) => const ProfileScreen()),
      GoRoute(path: '/profile/:id', name: 'profile-view', builder: (c, s) => ProfileScreen(viewUserId: s.pathParameters['id'])),
      GoRoute(path: '/edit-profile', name: 'edit-profile', builder: (c, s) => const EditProfileScreen()),
      GoRoute(path: '/settings', name: 'settings', builder: (c, s) => const SettingsScreen()),
      GoRoute(path: '/notifications', name: 'notifications', builder: (c, s) => const NotificationsScreen()),
      GoRoute(path: '/leaderboard', name: 'leaderboard', builder: (c, s) => const LeaderboardScreen()),
      GoRoute(path: '/tournaments', name: 'tournaments', builder: (c, s) => const TournamentListScreen()),
      GoRoute(path: '/tournament/apply', name: 'tournament-apply', builder: (c, s) => const TournamentApplyScreen()),
      GoRoute(path: '/tournament/:id', name: 'tournament-detail', builder: (c, s) => TournamentDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/tournament/:id/build-teams', name: 'tournament-build-teams', builder: (c, s) => BuildTeamsScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/tournament/:id/bracket', name: 'tournament-bracket', builder: (c, s) => BracketViewScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/tournament/:id/schedule', name: 'tournament-schedule', builder: (c, s) => ScheduleMatchesScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/tournament-match/:id', name: 'tournament-match', builder: (c, s) => TournamentLiveMatchScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/private-room', name: 'private-room', builder: (c, s) => const PrivateRoomScreen()),
      GoRoute(path: '/room/:id', name: 'room-detail', builder: (c, s) => RoomDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/dispute/:id', name: 'dispute', builder: (c, s) => DisputeScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/agent-dashboard', name: 'agent-dashboard', builder: (c, s) => const AgentDashboardScreen()),
      GoRoute(path: '/admin-dashboard', name: 'admin-dashboard', builder: (c, s) => const AdminDashboardScreen()),
      GoRoute(path: '/admin/agents', name: 'admin-agents', builder: (c, s) => const AgentManagementScreen()),
      GoRoute(path: '/admin/agent-stats', name: 'admin-agent-stats', builder: (c, s) => const AdminAgentStatsScreen()),
      GoRoute(path: '/admin/tournaments', name: 'admin-tournaments', builder: (c, s) => const AdminTournamentApprovalScreen()),
      GoRoute(path: '/admin/announcements', name: 'admin-announcements', builder: (c, s) => const AnnouncementsScreen()),
      GoRoute(path: '/admin/users', name: 'admin-users', builder: (c, s) => const UserManagementScreen()),
      GoRoute(path: '/admin/disputes', name: 'admin-disputes', builder: (c, s) => const AdminDisputesScreen()),
      GoRoute(path: '/admin/payouts', name: 'admin-payouts', builder: (c, s) => const AdminPayoutsScreen()),
      GoRoute(path: '/admin/payouts/:id', name: 'admin-payout-detail', builder: (c, s) => AdminPayoutDetailScreen(gameId: s.pathParameters['id']!)),
    ],
  );
});
