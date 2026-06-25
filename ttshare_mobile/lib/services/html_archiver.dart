import 'dart:io';
import 'package:path_provider/path_provider.dart';

class HtmlArchiver {
  /// Creates a self-contained HTML file from raw HTML
  Future<String> archive(String html, String title) async {
    final dir = await getTemporaryDirectory();
    final safeTitle = _sanitizeFileName(title);
    final fileDir = Directory('${dir.path}/$safeTitle');
    if (!await fileDir.exists()) {
      await fileDir.create(recursive: true);
    }

    final filePath = '${fileDir.path}/index.html';

    final wrappedHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$title</title>
</head>
<body>
$html
</body>
</html>
''';

    await File(filePath).writeAsString(wrappedHtml);
    return filePath;
  }

  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .substring(0, name.length.clamp(1, 100));
  }
}
