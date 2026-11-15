import 'package:share_plus/share_plus.dart';

Future<void> shareDocument(String title, Iterable<String?> details) {
  final text = details
      .where((line) => line != null && line.trim().isNotEmpty)
      .join('\n');
  return SharePlus.instance.share(ShareParams(text: text, subject: title));
}
