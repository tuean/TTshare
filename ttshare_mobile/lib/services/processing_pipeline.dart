import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'cookie_manager.dart';
import 'web_view_loader.dart';
import 'html_archiver.dart';
import 'readability_extractor.dart';
import 'webdav_client.dart';
import '../models/article_record.dart';

class ProcessResult {
  final ArticleRecord record;
  final bool success;
  final String? error;

  ProcessResult({required this.record, required this.success, this.error});
}

class ProcessingPipeline {
  final CookieManager _cookieManager;
  final WebViewLoader _webViewLoader;
  final HtmlArchiver _htmlArchiver;
  final ReadabilityExtractor _readabilityExtractor;
  final WebdavClient _webdavClient;

  ProcessingPipeline({
    required CookieManager cookieManager,
    required WebViewLoader webViewLoader,
    required HtmlArchiver htmlArchiver,
    required ReadabilityExtractor readabilityExtractor,
    required WebdavClient webdavClient,
  })  : _cookieManager = cookieManager,
        _webViewLoader = webViewLoader,
        _htmlArchiver = htmlArchiver,
        _readabilityExtractor = readabilityExtractor,
        _webdavClient = webdavClient;

  Future<ProcessResult> process(String url, String title) async {
    final id = const Uuid().v4();
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final source = Uri.tryParse(url)?.host ?? 'unknown';
    final folderName = '$dateStr-$source-${_sanitize(title)}';
    final safeFolder = folderName.substring(0, folderName.length.clamp(1, 100));

    try {
      // 1. Check cookies and load page via headless WebView
      final domain = Uri.parse(url).host;
      final cookieEntry = await _cookieManager.getCookies(domain);
      final html = await _webViewLoader.loadPage(
        url: url,
        cookieData: cookieEntry?.cookieData,
      );

      // 2. Create HTML archive
      final htmlPath = await _htmlArchiver.archive(html, title);

      // 3. Extract Markdown via Readability
      final extractResult = await _readabilityExtractor.extract(html, url);
      String? mdLocalPath;

      final rawJson = extractResult['raw'] as String?;
      if (rawJson != null) {
        try {
          final parsed = json.decode(rawJson) as Map<String, dynamic>;
          final markdown = parsed['markdown'] as String?;
          if (markdown != null && markdown.isNotEmpty) {
            // Save markdown file alongside HTML
            final tmpDir = await getTemporaryDirectory();
            final mdDir = '${tmpDir.path}/${_sanitize(title)}';
            mdLocalPath = '$mdDir/index.md';
          }
        } catch (_) {}
      }

      // 4. Upload to WebDAV
      if (!_webdavClient.isConfigured) {
        return ProcessResult(
          record: ArticleRecord(
            id: id,
            title: title,
            source: source,
            url: url,
            savedAt: DateTime.now(),
            status: 'failed',
            errorMessage: 'WebDAV not configured',
          ),
          success: false,
          error: 'WebDAV not configured',
        );
      }

      final basePath = '/$safeFolder';
      await _webdavClient.createFolder(basePath);

      final htmlRemotePath = '$basePath/index.html';
      await _webdavClient.uploadFile(htmlPath, htmlRemotePath);

      if (mdLocalPath != null) {
        final mdRemotePath = '$basePath/index.md';
        await _webdavClient.uploadFile(mdLocalPath, mdRemotePath);
      }

      return ProcessResult(
        record: ArticleRecord(
          id: id,
          title: title,
          source: source,
          url: url,
          savedAt: DateTime.now(),
          status: 'completed',
          htmlWebdavPath: htmlRemotePath,
        ),
        success: true,
      );
    } catch (e) {
      return ProcessResult(
        record: ArticleRecord(
          id: id,
          title: title,
          source: source,
          url: url,
          savedAt: DateTime.now(),
          status: 'failed',
          errorMessage: e.toString(),
        ),
        success: false,
        error: e.toString(),
      );
    }
  }

  String _sanitize(String s) {
    return s
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }
}
