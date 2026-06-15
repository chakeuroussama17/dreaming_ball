# Push Notifications (FCM) — Setup Guide

This makes notifications **pop up on the phone even when the app is closed**
(welcome, kick-off reminders, payment confirmed, tier-up, XP, announcements — all
of them, automatically, because every notification already flows through the
`notifications` table).

There are two halves:

- **You do once:** create a free Firebase project and download two files
  (`google-services.json` + a service-account key). ~15 minutes. **Steps 1–2.**
- **Already written for you:** the Supabase backend (`push_notifications.sql`,
  `supabase/functions/send-push`) and all the Flutter code (below, **Step 3**).

> ⚠️ **Build order matters.** The moment the Flutter app has Firebase wired in,
> it will **not compile** until `google-services.json` exists in `android/app/`.
> So do Step 1 first, drop in the file, *then* apply Step 3. Until then, the app
> builds and runs normally without push.

---

## Step 1 — Create the Firebase project

1. Go to <https://console.firebase.google.com> → **Add project** → name it
   `Dreaming Ball` → continue (you can disable Analytics) → **Create**.
2. On the project dashboard, click the **Android** icon ("Add app").
   - **Android package name:** `com.example.dreaming_ball`
     *(must match exactly — it's your `applicationId`)*
   - Nickname / debug SHA-1: optional, skip.
   - **Register app** → **Download `google-services.json`**.
3. Put that file at:
   ```
   dreaming_ball/android/app/google-services.json
   ```
   *(Already git-ignored — it won't be committed.)*

## Step 2 — Get the service-account key (for the server to send pushes)

1. Firebase Console → ⚙️ **Project settings** → **Service accounts** tab.
2. **Generate new private key** → confirm → a `.json` file downloads.
3. Note your **Project ID** (top of Project settings, e.g. `dreaming-ball-abc12`).

Keep that JSON handy for Step 4 (we paste it into a Supabase secret — never into
the app or git).

---

## Step 3 — Flutter wiring  ✅ ALREADY DONE (applied 2026-06-15)

> All of 3a–3g below are already in the codebase (pubspec, both Gradle files,
> AndroidManifest, `lib/core/services/push_service.dart`, `main.dart`, and the
> token register/unregister in `auth_service.dart`). Kept here for reference.
> `flutter analyze` is clean; the only build step left is yours: `flutter build apk`.

### 3a. Dependencies — `pubspec.yaml`
Add under `dependencies:`
```yaml
  firebase_core: ^3.6.0
  firebase_messaging: ^15.1.3
  flutter_local_notifications: ^18.0.1
```
then `flutter pub get`.

### 3b. Gradle — `android/settings.gradle.kts`
In the `plugins { }` block, add the last line:
```kotlin
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
```

### 3c. Gradle — `android/app/build.gradle.kts`
In the top `plugins { }` block, add the google-services line:
```kotlin
plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}
```

### 3d. Manifest — `android/app/src/main/AndroidManifest.xml`
Add the permission just inside `<manifest …>` (before `<application>`):
```xml
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

### 3e. Dart — create `lib/core/services/push_service.dart`
```dart
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'supabase_service.dart';

/// Background isolate handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  // The OS shows the notification tray entry itself for background messages.
}

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
        SupabaseService.supabase.rpc('save_device_token',
            params: {'p_token': t, 'p_platform': 'android'});
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
    } catch (_) {}
  }
}
```

### 3f. Dart — `lib/main.dart`
After `Supabase.initialize(...)` add:
```dart
  await Firebase.initializeApp();
  await PushService.init();
```
(and `import 'package:firebase_core/firebase_core.dart';` +
`import 'core/services/push_service.dart';`)

### 3g. Register / unregister the device token
- In `auth_service.dart` (or right after a successful sign-in/sign-up in the
  login & register screens): call `PushService.registerToken();`
- In `AuthService.signOut()`: call `await PushService.unregisterToken();`
  *(before `_sb.auth.signOut()`)*

I'll wire 3f–3g precisely when we flip this on.

---

## Step 4 — Deploy the Supabase backend

1. **Token table** — SQL Editor → run `database/push_notifications.sql`.
2. **Edge Function secrets** (CLI):
   ```bash
   supabase secrets set FCM_PROJECT_ID="your-project-id"
   supabase secrets set FCM_SERVICE_ACCOUNT="$(cat path/to/service-account.json)"
   ```
   *(`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided automatically.)*
3. **Deploy the function:**
   ```bash
   supabase functions deploy send-push
   ```

## Step 5 — (optional) Verify the function
```bash
supabase functions invoke send-push --no-verify-jwt \
  --body '{"user_id":"<a-user-uuid>","title":"Test","body":"It works!"}'
```
(With that user logged in on a phone, the push should appear.)

## Step 6 — Hook every notification to push (Database Webhook)

Supabase Dashboard → **Database** → **Webhooks** → **Create a new hook**:
- **Name:** `notify-push`
- **Table:** `notifications`
- **Events:** `Insert`
- **Type:** *Supabase Edge Functions* → **send-push**
- Method `POST`, leave headers default (it auto-includes the service-role key).

Save. From now on, **any** row inserted into `notifications` (welcome, reminder,
payment, tier-up, XP, announcement, dispute, etc.) is delivered to the user's
phone automatically — no per-event code needed.

---

## How it flows
```
event happens → notifications row inserted (existing triggers/RPCs)
            → Database Webhook fires → send-push Edge Function
            → looks up device_tokens for that user → FCM HTTP v1
            → phone shows the notification (open OR closed)
```
