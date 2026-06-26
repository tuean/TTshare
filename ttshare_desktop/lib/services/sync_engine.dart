import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/article.dart';
import 'local_db.dart';
import 'webdav_client.dart';

class SyncEngine {
  final WebdavClient _webdavClient;
  final LocalDB _localDB;

  SyncEngine({
    required WebdavClient webdavClient,
    required LocalDB localDB,
  })  : _webdavClient = webdavClient,
        _localDB = localDB;

  Future<SyncResult> syncArticles() async {
    if (!_webdavClient.isConfigured) {
      return SyncResult(errorMessage: 'WebDAV 未配置');
    }

    try {
      final items = await _webdavClient.listDirectory('/TTshare');
      final dirs = items.where((item) => item.isDirectory).toList();

      int added = 0, errors = 0;

      for (final dir in dirs) {
        try {
          await _syncArticle(dir.path);
          added++;
        } catch (e) {
          errors++;
        }
      }

      return SyncResult(added: added, errors: errors);
    } catch (e) {
      return SyncResult(errors: 1, errorMessage: e.toString());
    }
  }

  Future<void> _syncArticle(String dirPath) async {
    final dirName = p.basename(dirPath);
    final cacheDir = await _getCacheDir(dirName);
    final parts = dirName.split('-');
    final dateStr = parts.take(3).join('-');
    final savedAt = DateTime.tryParse(dateStr) ?? DateTime.now();

    String? htmlContent;
    String? mdContent;
    String title = dirName;

    try {
      final htmlLocal = p.join(cacheDir, 'index.html');
      htmlContent = await _webdavClient.downloadFile(
          '$dirPath/index.html', htmlLocal);
    } catch (_) {}

    try {
      final mdLocal = p.join(cacheDir, 'index.md');
      mdContent =
          await _webdavClient.downloadFile('$dirPath/index.md', mdLocal);
    } catch (_) {}

    if (htmlContent != null) {
      final titleMatch = RegExp(r'<title>(.*?)</title>', dotAll: true)
          .firstMatch(htmlContent);
      if (titleMatch != null) {
        title = titleMatch.group(1)!.trim();
      }
    }

    final article = Article(
      id: dirName,
      title: title,
      source: dirName.split('-').skip(3).join('-'),
      savedAt: savedAt,
      syncedAt: DateTime.now(),
      webdavPath: dirPath,
      htmlContent: htmlContent,
      mdContent: mdContent,
    );

    await _localDB.upsertArticle(article);
  }

  Future<String> _getCacheDir(String dirName) async {
    final appDir = await getApplicationSupportDirectory();
    final cacheDir = p.join(appDir.path, 'cache', dirName);
    await Directory(cacheDir).create(recursive: true);
    return cacheDir;
  }

  Future<void> deleteArticle(String id) async {
    final article = await _localDB.getArticle(id);
    if (article == null) return;

    try {
      await _webdavClient.deleteDirectory(article.webdavPath);
    } catch (_) {}

    final cacheDir = await _getCacheDir(id);
    if (await Directory(cacheDir).exists()) {
      await Directory(cacheDir).delete(recursive: true);
    }

    await _localDB.deleteArticle(id);
  }
}

class SyncResult {
  final int added;
  final int errors;
  final String? errorMessage;

  SyncResult({this.added = 0, this.errors = 0, this.errorMessage});
}
