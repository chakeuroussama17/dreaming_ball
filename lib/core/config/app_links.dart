/// Deep-link configuration for shareable game links.
///
/// Shared links look like `https://HOST/game/ID`. The app already routes
/// `/game/:id` (see router.dart), and the Android manifest declares an App
/// Links intent-filter for [webHost].
///
/// IMPORTANT: for these links to open the app directly from WhatsApp (instead
/// of a browser), you must:
///   1. Own the domain [webHost].
///   2. Host `HOST/.well-known/assetlinks.json` with the app's package name +
///      SHA-256 signing-certificate fingerprint.
/// Until then the link still carries the invite; it just won't auto-open.
/// Point [webHost] at whatever domain (or landing page) you set up.
class AppLinks {
  static const webHost = 'dreamingball.app';

  /// Public link to a specific game.
  static String gameUrl(String id) => 'https://$webHost/game/$id';
}
