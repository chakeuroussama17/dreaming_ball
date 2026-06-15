import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Sharing helpers used by the room and profile screens.
class ShareUtils {
  /// Opens the native share sheet (WhatsApp, Telegram, SMS, copy, ...).
  static Future<void> shareText(String text, {String? subject}) async {
    await Share.share(text, subject: subject);
  }

  /// Opens WhatsApp directly with [text] pre-filled, letting the user pick a
  /// chat. Falls back to the native share sheet if WhatsApp can't be opened
  /// (not installed / no handler). Returns true if something opened.
  static Future<bool> shareViaWhatsApp(String text) async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    try {
      final ok =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return true;
    } catch (_) {
      // fall through to the share sheet
    }
    await shareText(text);
    return true;
  }
}
