import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'core/services/push_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    // Legacy anon keys are accepted here; param was renamed from anonKey.
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Push notifications (FCM). Wrapped so a misconfig never blocks app start.
  try {
    await Firebase.initializeApp();
    await PushService.init();
  } catch (e) {
    debugPrint('Firebase/push init skipped: $e');
  }

  // Load the saved theme for the current session's user (per-user) before the
  // first frame so there's no flash. Falls back to the 'guest' scope.
  final prefs = await SharedPreferences.getInstance();
  final scope = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
  final initialTheme = ThemeModeNotifier.decode(
      prefs.getString(ThemeModeNotifier.keyFor(scope)));

  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider
            .overrideWith((ref) => ThemeModeNotifier(initialTheme, scope)),
      ],
      child: const DreamingBallApp(),
    ),
  );
}
