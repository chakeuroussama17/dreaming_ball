// Web no-op push implementation. Native FCM / local notifications aren't
// available in the browser, so these do nothing (the app runs fine; push just
// isn't delivered on web). Selected via the conditional import in
// push_service.dart.

Future<void> initPush() async {}

Future<void> registerToken() async {}

Future<void> unregisterToken() async {}
