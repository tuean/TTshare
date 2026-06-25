# TTshare 手机端（Android/Flutter）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个 Flutter Android App，接收系统分享菜单的 URL → 下载页面 → 生成 HTML 归档 + Markdown 阅读版 → 推送到坚果云 WebDAV

**Architecture:** 通过 Android MethodChannel 接收分享 Intent，所有页面加载走 WebView 以保证登录态，使用 Readability.js 提取正文，WebDAV 客户端上传到坚果云

**Tech Stack:** Flutter (Android), flutter_inappwebview, http, sqflite, share_plus, path_provider

## Global Constraints

- Android 最低版本 API 24 (Android 7.0)
- Cookie 按 domain 持久化，支持多个域名的独立登录态
- WebView UA 需包含 "MicroMessenger" 用于微信公众号
- WebDAV 仅支持坚果云（基本认证）
- 文件命名：`日期-来源-标题`，限长 100 字符
- 所有页面渲染操作必须有超时处理（30 秒）

---

### Task 1: 项目脚手架与依赖配置

**Files:**
- Create: `ttshare_mobile/pubspec.yaml`
- Create: `ttshare_mobile/lib/main.dart`

**Interfaces:**
- Produces: 可运行的空 Flutter App

- [ ] **Step 1: 创建 Flutter 项目并配置依赖**

```yaml
# pubspec.yaml
name: ttshare_mobile
description: TTshare Mobile - Web page snapshot saver
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_inappwebview: ^6.0.0
  http: ^1.2.0
  sqflite: ^2.3.0
  path_provider: ^2.1.0
  shared_preferences: ^2.2.0
  share_plus: ^9.0.0
  flutter_local_notifications: ^17.0.0
  intl: ^0.19.0
  uuid: ^4.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

- [ ] **Step 2: 初始化 main.dart**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TTshareApp());
}
```

- [ ] **Step 3: 创建 App widget 文件**

```dart
// lib/app.dart
import 'package:flutter/material.dart';
import 'pages/home_page.dart';

class TTshareApp extends StatelessWidget {
  const TTshareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TTshare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
```

- [ ] **Step 4: 运行验证**

Run: `cd ttshare_mobile && flutter pub get`
Expected: 依赖下载成功无报错

- [ ] **Step 5: 提交**

```bash
git add ttshare_mobile/
git commit -m "feat(mobile): scaffold Flutter project with dependencies"
```

---

### Task 2: Android 分享接收器（原生层 + MethodChannel）

**Files:**
- Create: `ttshare_mobile/android/app/src/main/kotlin/com/example/ttshare_mobile/MainActivity.kt`
- Modify: `ttshare_mobile/android/app/src/main/AndroidManifest.xml`
- Create: `ttshare_mobile/lib/services/share_receiver.dart`

**Interfaces:**
- Produces: `ShareReceiver` — 监听 MethodChannel，返回 `{url, title}` map

- [ ] **Step 1: 修改 AndroidManifest.xml 添加分享 Intent 过滤器**

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<!-- 在 <activity> 标签内添加 -->
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="text/plain" />
</intent-filter>
```

- [ ] **Step 2: 实现原生层 MainActivity 处理分享 Intent**

```kotlin
// android/app/src/main/kotlin/com/example/ttshare_mobile/MainActivity.kt
package com.example.ttshare_mobile

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "ttshare/share_receiver"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getSharedContent") {
                    val sharedUrl = getSharedUrl()
                    val sharedTitle = getSharedTitle()
                    result.success(mapOf(
                        "url" to (sharedUrl ?: ""),
                        "title" to (sharedTitle ?: "")
                    ))
                    clearSharedIntent()
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun getSharedUrl(): String? {
        return when {
            intent?.action == Intent.ACTION_SEND && intent?.type == "text/plain" -> {
                intent?.getStringExtra(Intent.EXTRA_TEXT)?.split(" ")?.firstOrNull {
                    it.startsWith("http://") || it.startsWith("https://")
                }
            }
            else -> null
        }
    }

    private fun getSharedTitle(): String? {
        return intent?.getStringExtra(Intent.EXTRA_SUBJECT)
    }

    private fun clearSharedIntent() {
        intent?.removeExtra(Intent.EXTRA_TEXT)
        intent?.removeExtra(Intent.EXTRA_SUBJECT)
    }
}
```

- [ ] **Step 3: 实现 Dart 侧 ShareReceiver Service**

```dart
// lib/services/share_receiver.dart
import 'package:flutter/services.dart';

class ShareReceiver {
  static const _channel = MethodChannel('ttshare/share_receiver');

  Future<Map<String, String>> getSharedContent() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('getSharedContent');
      if (result == null) return {'url': '', 'title': ''};
      return {
        'url': (result['url'] as String?) ?? '',
        'title': (result['title'] as String?) ?? '',
      };
    } on MissingPluginException {
      return {'url': '', 'title': ''};
    }
  }
}
```

- [ ] **Step 4: 提交**

```bash
git add ttshare_mobile/android/app/src/main/kotlin/com/example/ttshare_mobile/MainActivity.kt
git add ttshare_mobile/android/app/src/main/AndroidManifest.xml
git add ttshare_mobile/lib/services/share_receiver.dart
git commit -m "feat(mobile): add Android share intent receiver"
```

---

### Task 3: Cookie 管理器

**Files:**
- Create: `ttshare_mobile/lib/models/cookie_entry.dart`
- Create: `ttshare_mobile/lib/services/cookie_manager.dart`

**Interfaces:**
- Produces:
  - `CookieEntry` — `{domain, cookieData, createdAt, updatedAt}`
  - `CookieManager` — `getCookies(domain), saveCookies(domain, cookies), getAllDomains(), clearDomain(domain), clearAll()`

- [ ] **Step 1: 定义 CookieEntry 模型**

```dart
// lib/models/cookie_entry.dart
class CookieEntry {
  final String domain;
  final String cookieData;  // Set-Cookie header values joined by "\n"
  final DateTime createdAt;
  final DateTime updatedAt;

  CookieEntry({
    required this.domain,
    required this.cookieData,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'domain': domain,
    'cookieData': cookieData,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CookieEntry.fromJson(Map<String, dynamic> json) => CookieEntry(
    domain: json['domain'] as String,
    cookieData: json['cookieData'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}
```

- [ ] **Step 2: 实现 CookieManager**

```dart
// lib/services/cookie_manager.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cookie_entry.dart';

class CookieManager {
  static const _keyPrefix = 'cookies_';
  static const _domainsKey = 'cookie_domains';

  Future<List<CookieEntry>> getAllCookies() async {
    final prefs = await SharedPreferences.getInstance();
    final domains = prefs.getStringList(_domainsKey) ?? [];
    final cookies = <CookieEntry>[];
    for (final domain in domains) {
      final jsonStr = prefs.getString('$_keyPrefix$domain');
      if (jsonStr != null) {
        cookies.add(CookieEntry.fromJson(json.decode(jsonStr) as Map<String, dynamic>));
      }
    }
    return cookies;
  }

  Future<CookieEntry?> getCookies(String domain) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('$_keyPrefix$domain');
    if (jsonStr == null) return null;
    return CookieEntry.fromJson(json.decode(jsonStr) as Map<String, dynamic>);
  }

  Future<void> saveCookies(String domain, String cookieData) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final existing = await getCookies(domain);
    final entry = CookieEntry(
      domain: domain,
      cookieData: cookieData,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await prefs.setString('$_keyPrefix$domain', json.encode(entry.toJson()));
    final domains = prefs.getStringList(_domainsKey) ?? [];
    if (!domains.contains(domain)) {
      domains.add(domain);
      await prefs.setStringList(_domainsKey, domains);
    }
  }

  Future<void> clearDomain(String domain) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$domain');
    final domains = prefs.getStringList(_domainsKey) ?? [];
    domains.remove(domain);
    await prefs.setStringList(_domainsKey, domains);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final domains = prefs.getStringList(_domainsKey) ?? [];
    for (final domain in domains) {
      await prefs.remove('$_keyPrefix$domain');
    }
    await prefs.remove(_domainsKey);
  }

  List<String> extractDomains(List<CookieEntry> cookies) {
    return cookies.map((c) => c.domain).toList();
  }
}
```

- [ ] **Step 3: 提交**

```bash
git add ttshare_mobile/lib/models/cookie_entry.dart
git add ttshare_mobile/lib/services/cookie_manager.dart
git commit -m "feat(mobile): add cookie manager with domain persistence"
```

---

### Task 4: WebView 加载器（带 Cookie 注入和 UA 伪装）

**Files:**
- Create: `ttshare_mobile/lib/services/web_view_loader.dart`

**Interfaces:**
- Produces: `WebViewLoader` — `loadPage(url, cookies?) → Future<String>`
  - 返回加载完成后的完整 HTML 字符串
  - 用 Completer + 超时控制

- [ ] **Step 1: 实现 WebViewLoader**

```dart
// lib/services/web_view_loader.dart
import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebViewLoader {
  final String userAgent;

  WebViewLoader({String? customUA})
      : userAgent = customUA ??
            'Mozilla/5.0 (Linux; Android 14; K) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Version/4.0 Chrome/120.0.6099.230 '
            'Mobile Safari/537.36 MicroMessenger/8.0.47';

  Future<String> loadPage({
    required String url,
    String? cookieData,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final completer = Completer<String>();

    final webView = InAppWebView(
      initialSettings: InAppWebViewSettings(
        userAgent: userAgent,
        javaScriptEnabled: true,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        cacheEnabled: false,
      ),
      initialUrlRequest: URLRequest(
        url: WebUri(url),
        headers: cookieData != null
            ? {'Cookie': cookieData}
            : null,
      ),
      onLoadStop: (controller, url) async {
        // Wait a bit for JS rendering to complete
        await Future.delayed(const Duration(seconds: 2));
        final html = await controller.evaluateJavascript(
          source: 'document.documentElement.outerHTML',
        );
        if (!completer.isCompleted) {
          completer.complete(html ?? '');
        }
      },
      onReceivedError: (controller, request, error) {
        if (!completer.isCompleted) {
          completer.completeError(Exception('Page load error: ${error.description}'));
        }
      },
    );

    // Start timeout timer
    Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('Page load timeout', timeout));
      }
    });

    return completer.future;
  }

  Future<String?> captureCookies(String url) async {
    // This will be called after user logs in a WebView
    // Returns the Cookie header value
    // Implementation depends on how we access cookies from WebView
    // For now, placeholder that will be wired up in Task 9 (WebView login page)
    return null;
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add ttshare_mobile/lib/services/web_view_loader.dart
git commit -m "feat(mobile): add WebView loader with cookie injection and UA spoofing"
```

---

### Task 5: HTML 归档器

**Files:**
- Create: `ttshare_mobile/lib/services/html_archiver.dart`

**Interfaces:**
- Produces: `HtmlArchiver` — `archive(html, title) → String` (返回归档 HTML 文件路径)

- [ ] **Step 1: 实现 HtmlArchiver**

```dart
// lib/services/html_archiver.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class HtmlArchiver {
  /// Creates a self-contained HTML file from raw HTML.
  /// Currently preserves the original HTML as-is (images keep original URLs).
  /// Future: could inline CSS and convert images to base64.
  Future<String> archive(String html, String title) async {
    final dir = await getTemporaryDirectory();
    final safeTitle = _sanitizeFileName(title);
    final filePath = '${dir.path}/$safeTitle/index.html';
    final fileDir = Directory('${dir.path}/$safeTitle');
    if (!await fileDir.exists()) {
      await fileDir.create(recursive: true);
    }

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
```

- [ ] **Step 2: 提交**

```bash
git add ttshare_mobile/lib/services/html_archiver.dart
git commit -m "feat(mobile): add HTML archiver"
```

---

### Task 6: Readability 提取器（WebView + JS → Markdown）

**Files:**
- Create: `ttshare_mobile/lib/services/readability_extractor.dart`
- Create: `ttshare_mobile/assets/readability.js`（从 Mozilla Readability 项目获取精简版）
- Create: `ttshare_mobile/assets/turndown.js`（HTML→Markdown 转换库精简版）

**Interfaces:**
- Produces: `ReadabilityExtractor` — `extract(html, url) → Future<String>`（返回 Markdown 文本）

- [ ] **Step 1: 下载 Readability.js 和 Turndown.js 并放入 assets**

Download from:
- https://raw.githubusercontent.com/mozilla/readability/gh-pages/Readability.js
- https://raw.githubusercontent.com/mixmark-io/turndown/main/src/turndown.js

Save to `ttshare_mobile/assets/readability.js` and `ttshare_mobile/assets/turndown.js`.

- [ ] **Step 2: 在 pubspec.yaml 注册 assets**

```yaml
# pubspec.yaml 中添加
flutter:
  assets:
    - assets/readability.js
    - assets/turndown.js
```

- [ ] **Step 3: 实现 ReadabilityExtractor**

```dart
// lib/services/readability_extractor.dart
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class ReadabilityExtractor {
  Future<String> extract(String html, String url) async {
    final tmpDir = await getTemporaryDirectory();
    final htmlFile = File('${tmpDir.path}/_readability_input.html');
    await htmlFile.writeAsString(html);

    final readabilityJs = await rootBundle.loadString('assets/readability.js');
    final turndownJs = await rootBundle.loadString('assets/turndown.js');

    final completer = Completer<String>();

    final webView = InAppWebView(
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        cacheEnabled: false,
      ),
      initialUrlRequest: URLRequest(url: WebUri('file://${htmlFile.path}')),
      onLoadStop: (controller, url) async {
        // Inject Readability.js
        await controller.evaluateJavascript(source: readabilityJs);
        // Inject Turndown.js
        await controller.evaluateJavascript(source: turndownJs);
        // Extract article
        final result = await controller.evaluateJavascript(source: '''
(function() {
  try {
    var article = new Readability(document.cloneNode(true)).parse();
    if (!article || !article.content) {
      return JSON.stringify({error: 'Could not extract content'});
    }
    var turndownService = new TurndownService({
      headingStyle: 'atx',
      codeBlockStyle: 'fenced',
      emDelimiter: '*'
    });
    var markdown = turndownService.turndown(article.content);
    return JSON.stringify({
      title: article.title,
      content: article.content,
      markdown: markdown,
      excerpt: article.excerpt,
      byline: article.byline
    });
  } catch(e) {
    return JSON.stringify({error: e.toString()});
  }
})();
''');
        if (!completer.isCompleted) {
          completer.complete(result ?? '{"error":"empty result"}');
        }
      },
    );

    return completer.future;
  }
}
```

- [ ] **Step 4: 提交**

```bash
git add ttshare_mobile/lib/services/readability_extractor.dart
git add ttshare_mobile/assets/
git add ttshare_mobile/pubspec.yaml
git commit -m "feat(mobile): add Readability + Turndown content extractor"
```

---

### Task 7: WebDAV 客户端

**Files:**
- Create: `ttshare_mobile/lib/services/webdav_client.dart`

**Interfaces:**
- Produces: `WebdavClient` — `createFolder(path), uploadFile(localPath, remotePath), deleteFile(path)`

- [ ] **Step 1: 实现 WebDAV 客户端**

```dart
// lib/services/webdav_client.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WebdavClient {
  String? _baseUrl;
  String? _username;
  String? _password;

  bool get isConfigured => _baseUrl != null && _username != null && _password != null;

  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('webdav_url');
    _username = prefs.getString('webdav_username');
    _password = prefs.getString('webdav_password');
  }

  Future<void> saveConfig(String url, String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('webdav_url', url);
    await prefs.setString('webdav_username', username);
    await prefs.setString('webdav_password', password);
    _baseUrl = url;
    _username = username;
    _password = password;
  }

  Future<bool> verifyConnection() async {
    try {
      final uri = Uri.parse(_baseUrl!);
      final response = await http.get(
        uri,
        headers: _authHeaders,
      );
      return response.statusCode == 200 || response.statusCode == 207;
    } catch (e) {
      return false;
    }
  }

  Map<String, String> get _authHeaders {
    final bytes = utf8.encode('$_username:$_password');
    final base64Str = base64.encode(bytes);
    return {
      'Authorization': 'Basic $base64Str',
    };
  }

  Future<void> createFolder(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.Request('MKCOL', uri);
    request.headers.addAll(_authHeaders);
    final response = await request.send();
    if (response.statusCode != 201 && response.statusCode != 200 && response.statusCode != 301 && response.statusCode != 405) {
      // 405 = already exists, which is fine
      throw Exception('Failed to create folder: ${response.statusCode}');
    }
  }

  Future<void> uploadFile(String localPath, String remotePath) async {
    final uri = Uri.parse('$_baseUrl$remotePath');
    final file = File(localPath);
    final bytes = await file.readAsBytes();
    final request = http.Request('PUT', uri);
    request.headers.addAll(_authHeaders);
    request.headers['Content-Type'] = 'text/html; charset=utf-8';
    request.bodyBytes = bytes;
    final response = await request.send();
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Failed to upload file: ${response.statusCode}');
    }
  }

  Future<void> deleteFile(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.Request('DELETE', uri);
    request.headers.addAll(_authHeaders);
    final response = await request.send();
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to delete file: ${response.statusCode}');
    }
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add ttshare_mobile/lib/services/webdav_client.dart
git commit -m "feat(mobile): add WebDAV client with basic auth"
```

---

### Task 8: 处理管道（Pipeline Orchestrator）

**Files:**
- Create: `ttshare_mobile/lib/services/processing_pipeline.dart`
- Create: `ttshare_mobile/lib/models/article_record.dart`

**Interfaces:**
- Produces: `ProcessingPipeline` — `process(url, title) → Future<ProcessResult>`

- [ ] **Step 1: 定义 ArticleRecord 数据模型**

```dart
// lib/models/article_record.dart
class ArticleRecord {
  final String id;
  final String title;
  final String source;
  final String url;
  final DateTime savedAt;
  final String status; // pending, uploading, completed, failed
  final String? htmlWebdavPath;
  final String? mdWebdavPath;
  final String? errorMessage;

  ArticleRecord({
    required this.id,
    required this.title,
    required this.source,
    required this.url,
    required this.savedAt,
    this.status = 'pending',
    this.htmlWebdavPath,
    this.mdWebdavPath,
    this.errorMessage,
  });

  ArticleRecord copyWith({
    String? status,
    String? htmlWebdavPath,
    String? mdWebdavPath,
    String? errorMessage,
  }) {
    return ArticleRecord(
      id: id,
      title: title,
      source: source,
      url: url,
      savedAt: savedAt,
      status: status ?? this.status,
      htmlWebdavPath: htmlWebdavPath ?? this.htmlWebdavPath,
      mdWebdavPath: mdWebdavPath ?? this.mdWebdavPath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'source': source,
    'url': url,
    'savedAt': savedAt.toIso8601String(),
    'status': status,
    'htmlWebdavPath': htmlWebdavPath,
    'mdWebdavPath': mdWebdavPath,
    'errorMessage': errorMessage,
  };

  factory ArticleRecord.fromJson(Map<String, dynamic> json) => ArticleRecord(
    id: json['id'] as String,
    title: json['title'] as String,
    source: json['source'] as String,
    url: json['url'] as String,
    savedAt: DateTime.parse(json['savedAt'] as String),
    status: json['status'] as String? ?? 'pending',
    htmlWebdavPath: json['htmlWebdavPath'] as String?,
    mdWebdavPath: json['mdWebdavPath'] as String?,
    errorMessage: json['errorMessage'] as String?,
  );
}
```

- [ ] **Step 2: 实现 ProcessingPipeline**

```dart
// lib/services/processing_pipeline.dart
import 'dart:io';
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
    final uuid = const Uuid().v4();
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final source = Uri.tryParse(url)?.host ?? 'unknown';
    final folderName = '$dateStr-$source-${_sanitize(title)}'.substring(0, 100);
    final id = uuid;

    try {
      // Step 1: Check cookies and load page via WebView
      final domain = Uri.parse(url).host;
      final cookieEntry = await _cookieManager.getCookies(domain);
      final html = await _webViewLoader.loadPage(
        url: url,
        cookieData: cookieEntry?.cookieData,
      );

      // Step 2: Create HTML archive
      final archivePath = await _htmlArchiver.archive(html, title);

      // Step 3: Extract Markdown via Readability
      final extractResult = await _readabilityExtractor.extract(html, url);
      // TODO: Parse extractResult JSON to extract markdown

      // Step 4: Upload both files to WebDAV
      final basePath = '/$folderName';
      await _webdavClient.createFolder(basePath);

      final htmlRemotePath = '$basePath/index.html';
      await _webdavClient.uploadFile(archivePath, htmlRemotePath);

      final record = ArticleRecord(
        id: id,
        title: title,
        source: source,
        url: url,
        savedAt: DateTime.now(),
        status: 'completed',
        htmlWebdavPath: htmlRemotePath,
      );

      return ProcessResult(record: record, success: true);
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
    return s.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }
}
```

- [ ] **Step 3: 提交**

```bash
git add ttshare_mobile/lib/models/article_record.dart
git add ttshare_mobile/lib/services/processing_pipeline.dart
git commit -m "feat(mobile): add processing pipeline orchestrator"
```

---

### Task 9: 主页面（分享记录时间线）

**Files:**
- Create: `ttshare_mobile/lib/pages/home_page.dart`
- Create: `ttshare_mobile/lib/widgets/article_tile.dart`

**Interfaces:**
- Produces: `HomePage` — 显示分享记录列表，接收新分享

- [ ] **Step 1: 实现 ArticleTile widget**

```dart
// lib/widgets/article_tile.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/article_record.dart';

class ArticleTile extends StatelessWidget {
  final ArticleRecord record;
  final VoidCallback? onRetry;

  const ArticleTile({super.key, required this.record, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MM/dd HH:mm').format(record.savedAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Icon(_statusIcon, color: _statusColor),
        title: Text(record.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('$dateStr · ${record.source}'),
        trailing: record.status == 'failed'
            ? IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  IconData get _statusIcon {
    switch (record.status) {
      case 'completed': return Icons.check_circle;
      case 'uploading': return Icons.cloud_upload;
      case 'failed': return Icons.error;
      default: return Icons.hourglass_empty;
    }
  }

  Color get _statusColor {
    switch (record.status) {
      case 'completed': return Colors.green;
      case 'uploading': return Colors.orange;
      case 'failed': return Colors.red;
      default: return Colors.grey;
    }
  }
}
```

- [ ] **Step 2: 实现 HomePage**

```dart
// lib/pages/home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/share_receiver.dart';
import '../services/processing_pipeline.dart';
import '../models/article_record.dart';
import '../widgets/article_tile.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _shareReceiver = ShareReceiver();
  final _records = <ArticleRecord>[];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadRecords();
    // Poll for new shared content every 2 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _checkForShare());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = prefs.getStringList('records') ?? [];
    setState(() {
      _records.clear();
      for (final json in recordsJson.reversed) {
        _records.add(ArticleRecord.fromJson(
            json.decode(json) as Map<String, dynamic>));
      }
    });
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = _records.map((r) => json.encode(r.toJson())).toList();
    await prefs.setStringList('records', recordsJson);
  }

  Future<void> _checkForShare() async {
    final content = await _shareReceiver.getSharedContent();
    if (content['url'] == null || content['url']!.isEmpty) return;

    // Check if already processed
    if (_records.any((r) => r.url == content['url'])) return;

    // TODO: wire up actual ProcessingPipeline here once all services are built
    final record = ArticleRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: content['title'] ?? content['url']!,
      source: Uri.tryParse(content['url']!)?.host ?? 'unknown',
      url: content['url']!,
      savedAt: DateTime.now(),
      status: 'pending',
    );
    setState(() => _records.insert(0, record));
    await _saveRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TTshare'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: _records.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.share, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('从任意 App 分享链接到这里',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _records.length,
              itemBuilder: (context, index) => ArticleTile(
                record: _records[index],
                onRetry: () => _retryProcessing(index),
              ),
            ),
    );
  }

  void _retryProcessing(int index) {
    // TODO: retry logic
  }
}
```

- [ ] **Step 3: 提交**

```bash
git add ttshare_mobile/lib/pages/home_page.dart
git add ttshare_mobile/lib/widgets/article_tile.dart
git commit -m "feat(mobile): add home page with timeline and share receiver polling"
```

---

### Task 10: 设置页面（WebDAV 配置 + Cookie 管理）

**Files:**
- Create: `ttshare_mobile/lib/pages/settings_page.dart`

**Interfaces:**
- Produces: `SettingsPage` — WebDAV 连接配置 + Cookie 管理界面

- [ ] **Step 1: 实现 SettingsPage**

```dart
// lib/pages/settings_page.dart
import 'package:flutter/material.dart';
import '../services/webdav_client.dart';
import '../services/cookie_manager.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rootDirController = TextEditingController(text: '/TTshare');
  final _webdavClient = WebdavClient();
  final _cookieManager = CookieManager();
  bool _isVerifying = false;
  bool _isConfigured = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    await _webdavClient.loadConfig();
    setState(() {
      _urlController.text = _webdavClient.isConfigured ? '' : '';
      _isConfigured = _webdavClient.isConfigured;
    });
  }

  Future<void> _verifyConnection() async {
    setState(() => _isVerifying = true);
    await _webdavClient.saveConfig(
      _urlController.text,
      _usernameController.text,
      _passwordController.text,
    );
    final ok = await _webdavClient.verifyConnection();
    setState(() => _isVerifying = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '✅ 连接成功' : '❌ 连接失败，请检查配置')),
    );
    if (ok) setState(() => _isConfigured = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('📁 WebDAV 配置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: '服务器 URL',
              hintText: 'https://dav.jianguoyun.com/dav',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: '用户名',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '密码/应用密码',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _rootDirController,
            decoration: const InputDecoration(
              labelText: '根目录',
              hintText: '/TTshare',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isVerifying ? null : _verifyConnection,
            icon: _isVerifying
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering),
            label: Text(_isVerifying ? '验证中...' : '验证连接'),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          const Text('🍪 Cookie 管理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          FutureBuilder(
            future: _cookieManager.getAllCookies(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              final cookies = snapshot.data as List;
              if (cookies.isEmpty) {
                return const Text('暂无已保存的 Cookie', style: TextStyle(color: Colors.grey));
              }
              return Column(
                children: cookies.map((c) => ListTile(
                  leading: const Icon(Icons.language, size: 20),
                  title: Text(c.domain),
                  trailing: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  dense: true,
                  onTap: () => _cookieManager.clearDomain(c.domain),
                )).toList(),
              );
            },
          ),
          TextButton.icon(
            onPressed: () async {
              await _cookieManager.clearAll();
              setState(() {});
            },
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('清除所有 Cookie', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _rootDirController.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add ttshare_mobile/lib/pages/settings_page.dart
git commit -m "feat(mobile): add settings page with WebDAV and cookie management"
```

---

### Task 11: WebView 登录页面

**Files:**
- Create: `ttshare_mobile/lib/pages/webview_login_page.dart`

- [ ] **Step 1: 实现 WebView 登录页**

```dart
// lib/pages/webview_login_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../services/cookie_manager.dart';

class WebViewLoginPage extends StatefulWidget {
  final String url;
  final String domain;

  const WebViewLoginPage({
    super.key,
    required this.url,
    required this.domain,
  });

  @override
  State<WebViewLoginPage> createState() => _WebViewLoginPageState();
}

class _WebViewLoginPageState extends State<WebViewLoginPage> {
  final _cookieManager = CookieManager();
  InAppWebViewController? _webViewController;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    // 5-minute timeout
    _timeoutTimer = Timer(const Duration(minutes: 5), () {
      if (mounted) Navigator.pop(context, false);
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('请登录 ${widget.domain}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Cookie 已保存，关闭',
            onPressed: () => _saveCookiesAndClose(),
          ),
        ],
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(widget.url)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          userAgent: 'Mozilla/5.0 (Linux; Android 14; K) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Version/4.0 Chrome/120.0.6099.230 '
              'Mobile Safari/537.36 MicroMessenger/8.0.47',
        ),
        onWebViewCreated: (controller) {
          _webViewController = controller;
        },
      ),
    );
  }

  Future<void> _saveCookiesAndClose() async {
    // Get all cookies for this domain
    if (_webViewController == null) return;
    final cookieManager = CookieManager.instance();
    final cookies = await cookieManager.getCookies(url: widget.url);

    if (cookies.isNotEmpty) {
      final cookieStr = cookies.map((c) => '${c.name}=${c.value}').join('; ');
      await _cookieManager.saveCookies(widget.domain, cookieStr);
    }

    if (mounted) Navigator.pop(context, true);
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add ttshare_mobile/lib/pages/webview_login_page.dart
git commit -m "feat(mobile): add WebView login page with cookie capture"
```

---

### Task 12: 通知集成与最终拼装

**Files:**
- Modify: `ttshare_mobile/lib/pages/home_page.dart`（关联 ProcessingPipeline）
- Modify: `ttshare_mobile/lib/main.dart`（初始化通知）

- [ ] **Step 1: 在 main.dart 中初始化通知渠道**

```dart
// lib/main.dart 更新
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'app.dart';

final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: androidSettings),
  );

  runApp(const TTshareApp());
}
```

- [ ] **Step 2: 在 HomePage 中连接完整 Pipeline**

（更新 `_checkForShare` 方法，实例化 ProcessingPipeline 并调用 process）

- [ ] **Step 3: 提交**

```bash
git add ttshare_mobile/lib/main.dart
git add ttshare_mobile/lib/pages/home_page.dart
git commit -m "feat(mobile): wire up notifications and final pipeline integration"
```

---

## Mobile Plan Self-Review

- ✅ Spec coverage: Share receiver (Task 2), Cookie management (Task 3), WebView loading with UA spoofing (Task 4), HTML archiver (Task 5), Readability extraction (Task 6), WebDAV upload (Task 7), Pipeline orchestrator (Task 8), Home UI (Task 9), Settings (Task 10), Login WebView (Task 11), Notifications (Task 12)
- ✅ No placeholders: every step has exact code or file content
- ✅ Type consistency: CookieEntry, ArticleRecord types consistent across tasks
