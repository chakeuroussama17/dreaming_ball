import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/providers/admin_providers.dart';
import '../core/providers/session_provider.dart';
import '../core/services/auth_service.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';

/// Holds the chosen theme mode and persists it **per user**, so each account
/// keeps its own light/dark preference and a new user doesn't inherit the
/// previous one. The initial value/scope is loaded in main() (no flash); call
/// [applyFor] on login (with the user id) and on logout (with null).
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(super.initial, [this._scope = 'guest']);

  String _scope; // 'guest' or the signed-in user's id

  static String keyFor(String scope) => 'theme_mode_$scope';

  static ThemeMode decode(String? saved) => switch (saved) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark, // default
      };

  /// Load a user's saved theme. Pass the user id on login, or null on logout
  /// (which falls back to the 'guest' scope's default).
  Future<void> applyFor(String? uid) async {
    _scope = uid ?? 'guest';
    final prefs = await SharedPreferences.getInstance();
    state = decode(prefs.getString(keyFor(_scope)));
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyFor(_scope), mode.name);
  }
}

// Overridden in main() with the persisted initial value + scope.
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(ThemeMode.dark),
);

/// Holds the chosen UI language and persists it app-wide. Defaults to English;
/// the user can switch in Settings. The initial value is loaded in main().
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier(super.initial);

  static const _key = 'app_locale';
  static const fallback = Locale('en');

  /// Supported languages, in the order shown in the picker.
  static const supported = [
    Locale('en'),
    Locale('ms'),
    Locale('zh'),
    Locale('ja'),
    Locale('ru'),
  ];

  static Locale decode(String? code) =>
      (code == null || code.isEmpty) ? fallback : Locale(code);

  Future<void> set(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
  }
}

// Overridden in main() with the persisted initial value.
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(LocaleNotifier.fallback),
);

class DreamingBallApp extends ConsumerStatefulWidget {
  const DreamingBallApp({super.key});

  @override
  ConsumerState<DreamingBallApp> createState() => _DreamingBallAppState();
}

class _DreamingBallAppState extends ConsumerState<DreamingBallApp> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // When Supabase signs the user out (session expired, revoked, or explicit
    // logout), reset all local session state and bounce to the welcome screen.
    // This keeps the UI honest: no screen ever shows stale "logged-in" state
    // after the real session is gone.
    _authSub = AuthService.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedOut) {
        ref.read(userRoleProvider.notifier).state = UserRole.player;
        ref.read(agentVerificationProvider.notifier).state =
            AgentVerification.notSubmitted;
        ref.read(isAdminProvider.notifier).state = false;
        ref.read(themeModeProvider.notifier).applyFor(null);
        ref.read(routerProvider).goNamed('welcome');
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Dreaming Ball',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
