import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'supabase_service.dart';

/// Background isolate handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  // The OS renders the tray entry itself for background/terminated messages;
  // nothing to do here unless we want to pre-process data payloads.
}

/// Firebase Cloud Messaging wiring: device-token registration + showing a
/// heads-up notification for foreground messages (which FCM does not show
/// automatically). See database/FIREBASE_SETUP.md for the full setup.
class PushService {
  static final _fln = FlutterLocalNotificationsPlugin();
  static const _channel = AndroidNotificationChannel(
    'dreaming_ball_default',
    'Dreaming Ball',
    description: 'Game reminders, payments and updates',
    importance: Importance.high,
  );

  /// Call once from main() after Firebase.initializeApp().
  static Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_bgHandler);

    await _fln.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    await _fln
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await FirebaseMessaging.instance.requestPermission();

    // Foreground messages don't show automatically — render them ourselves.
    FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      if (n == null) return;
      _fln.show(
        n.hashCode,
        n.title,
        n.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    });
  }

  /// Call after a successful login/registration to register this device.
  static Future<void> registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await SupabaseService.supabase.rpc('save_device_token', params: {
        'p_token': token,
        'p_platform': Platform.isIOS ? 'ios' : 'android',
      });
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        SupabaseService.supabase.rpc('save_device_token', params: {
          'p_token': t,
          'p_platform': Platform.isIOS ? 'ios' : 'android',
        });
      });
    } catch (e) {
      if (kDebugMode) debugPrint('registerToken failed: $e');
    }
  }

  /// Call on logout so a shared phone stops pushing to the old account.
  static Future<void> unregisterToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await SupabaseService.supabase
          .rpc('delete_device_token', params: {'p_token': token});
    } catch (_) {
      // Best effort — nothing actionable if it fails.
    }
  }
}
