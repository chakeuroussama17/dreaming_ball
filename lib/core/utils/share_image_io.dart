import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Mobile/desktop: write the bytes to a temp file and share it.
Future<void> shareImageBytes(Uint8List bytes, {String text = ''}) async {
  final dir = await getTemporaryDirectory();
  final file = await File('${dir.path}/bracket.png').writeAsBytes(bytes);
  await Share.shareXFiles([XFile(file.path)], text: text);
}
