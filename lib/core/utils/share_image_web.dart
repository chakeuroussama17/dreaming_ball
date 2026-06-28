import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';

/// Web: share the bytes directly (no filesystem) via the Web Share API where
/// available, falling back to a download.
Future<void> shareImageBytes(Uint8List bytes, {String text = ''}) async {
  await Share.shareXFiles(
    [XFile.fromData(bytes, mimeType: 'image/png', name: 'bracket.png')],
    text: text,
  );
}
