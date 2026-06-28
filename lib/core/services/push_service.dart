// Firebase Cloud Messaging wiring (device-token registration + foreground
// notifications). The real work lives in push_service_io.dart on mobile; the
// web build swaps in push_service_web.dart (no-op) so it never imports the
// native-only firebase_messaging / flutter_local_notifications / dart:io.
// See database/FIREBASE_SETUP.md for the full native setup.
import 'push_service_io.dart' if (dart.library.html) 'push_service_web.dart'
    as impl;

class PushService {
  /// Call once from main() after Firebase.initializeApp().
  static Future<void> init() => impl.initPush();

  /// Call after a successful login/registration to register this device.
  static Future<void> registerToken() => impl.registerToken();

  /// Call on logout so a shared phone stops pushing to the old account.
  static Future<void> unregisterToken() => impl.unregisterToken();
}
