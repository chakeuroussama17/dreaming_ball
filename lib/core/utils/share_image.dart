import 'dart:typed_data';
import 'share_image_io.dart' if (dart.library.html) 'share_image_web.dart'
    as impl;

/// Shares a PNG image (given as bytes) via the platform share sheet. On mobile
/// it writes a temp file; on web it shares the bytes directly. The conditional
/// import keeps path_provider / dart:io out of the web build.
Future<void> shareImageBytes(Uint8List bytes, {String text = ''}) =>
    impl.shareImageBytes(bytes, text: text);
