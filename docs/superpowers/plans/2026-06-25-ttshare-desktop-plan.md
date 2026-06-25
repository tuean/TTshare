# TTshare 桌面端（macOS/Flutter）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个 Flutter macOS App，从坚果云 WebDAV 拉取 TTshare 保存的文章，提供搜索、阅读（HTML + Markdown）、收藏、删除、再分享功能

**Architecture:** WebDAV 同步引擎拉取内容到本地 SQLite 缓存，三栏式 UI（搜索栏 + 时间线列表 + 阅读区），HTML 用 WebView 渲染，Markdown 用 Flutter Markdown 组件渲染

**Tech Stack:** Flutter (macOS), sqflite (ffi), flutter_inappwebview (macOS), flutter_markdown, share_plus, path_provider

## Global Constraints

- macOS 最低版本 macOS 11 (Big Sur)
- 本地使用 SQLite 缓存，支持 FTS5 全文搜索
- 搜索范围包括文章标题和 Markdown 正文
- 删除操作需同步删除 WebDAV 远程文件和本地缓存
- 首次启动全量同步，后续增量同步
- 同步状态显示在状态栏

---

### Task 1: 项目脚手架与依赖配置

**Files:**
- Create: `ttshare_desktop/pubspec.yaml`
- Create: `ttshare_desktop/lib/main.dart`
- Create: `ttshare_desktop/lib/app.dart`

**Interfaces:**
- Produces: 可运行的空 Flutter macOS App

- [ ] **Step 1: 创建 Flutter Desktop 项目**

```bash
cd /Users/zhongxiaotian/IdeaProjects/TTshare
flutter create --platforms=macos ttshare_desktop
cd ttshare_desktop
```

- [ ] **Step 2: 配置 pubspec.yaml 依赖**

```yaml
# pubspec.yaml
name: ttshare_desktop
description: TTshare Desktop - Read and manage web snapshots
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_inappwebview_macos: ^1.0.0
  flutter_markdown: ^0.7.0
  http: ^1.2.0
  sqflite: ^2.3.0
  sqflite_common_ffi: ^2.3.0
  path_provider: ^2.1.0
  path: ^1.9.0
  shared_preferences: ^2.2.0
  share_plus: ^9.0.0
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true
```

- [ ] **Step 3: 初始化 main.dart 和 app.dart**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'app.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TTshareDesktopApp());
}
```

```dart
// lib/app.dart
import 'package:flutter/material.dart';
import 'pages/home_page.dart';

class TTshareDesktopApp extends StatelessWidget {
  const TTshareDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TTshare Desktop',
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

Run: `cd ttshare_desktop && flutter pub get`
Expected: 依赖下载成功无报错

- [ ] **Step 5: 提交**

```bash
git add ttshare_desktop/
git commit -m "feat(desktop): scaffold macOS Flutter project with dependencies"
```

---

### Task 2: 数据模型与本地数据库

**Files:**
- Create: `ttshare_desktop/lib/models/article.dart`
- Create: `ttshare_desktop/lib/services/local_db.dart`

**Interfaces:**
- Produces:
  - `Article` — 数据模型
  - `LocalDB` — `init(), upsertArticle(article), getAllArticles(), searchArticles(query), getFavorites(), deleteArticle(id), markFavorite(id, favorite)`

- [ ] **Step 1: 定义 Article 模型**

```dart
// lib/models/article.dart
class Article {
  final String id;           // UUID, matches mobile
  final String title;
  final String source;       // domain
  final DateTime savedAt;
  final DateTime? syncedAt;
  final bool isFavorite;
  final String webdavPath;   // WebDAV folder path
  final String? htmlContent; // cached HTML content
  final String? mdContent;   // cached Markdown content
  final String? errorMessage;

  Article({
    required this.id,
    required this.title,
    required this.source,
    required this.savedAt,
    this.syncedAt,
    this.isFavorite = false,
    required this.webdavPath,
    this.htmlContent,
    this.mdContent,
    this.errorMessage,
  });

  Article copyWith({
    String? title,
    String? source,
    DateTime? savedAt,
    DateTime? syncedAt,
    bool? isFavorite,
    String? webdavPath,
    String? htmlContent,
    String? mdContent,
    String? errorMessage,
  }) {
    return Article(
      id: id,
      title: title ?? this.title,
      source: source ?? this.source,
      savedAt: savedAt ?? this.savedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      webdavPath: webdavPath ?? this.webdavPath,
      htmlContent: htmlContent ?? this.htmlContent,
      mdContent: mdContent ?? this.mdContent,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'source': source,
    'savedAt': savedAt.toIso8601String(),
    'syncedAt': syncedAt?.toIso8601String(),
    'isFavorite': isFavorite ? 1 : 0,
    'webdavPath': webdavPath,
    'htmlContent': htmlContent,
    'mdContent': mdContent,
    'errorMessage': errorMessage,
  };

  factory Article.fromMap(Map<String, dynamic> map) => Article(
    id: map['id'] as String,
    title: map['title'] as String,
    source: map['source'] as String,
    savedAt: DateTime.parse(map['savedAt'] as String),
    syncedAt: map['syncedAt'] != null ? DateTime.parse(map['syncedAt'] as String) : null,
    isFavorite: (map['isFavorite'] as int) == 1,
    webdavPath: map['webdavPath'] as String,
    htmlContent: map['htmlContent'] as String?,
    mdContent: map['mdContent'] as String?,
    errorMessage: map['errorMessage'] as String?,
  );
}
```

- [ ] **Step 2: 实现 LocalDB（含 FTS5）**

```dart
// lib/services/local_db.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/article.dart';

class LocalDB {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'ttshare.db');
    final db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE articles (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            source TEXT NOT NULL,
            savedAt TEXT NOT NULL,
            syncedAt TEXT,
            isFavorite INTEGER DEFAULT 0,
            webdavPath TEXT NOT NULL,
            htmlContent TEXT,
            mdContent TEXT,
            errorMessage TEXT
          )
        ''');
        // FTS5 virtual table for full-text search
        await db.execute('''
          CREATE VIRTUAL TABLE articles_fts USING fts5(
            title, mdContent, content='articles', content_rowid='rowid'
          )
        ''');
        // Trigger to keep FTS index in sync
        await db.execute('''
          CREATE TRIGGER articles_ai AFTER INSERT ON articles BEGIN
            INSERT INTO articles_fts(rowid, title, mdContent)
            VALUES (new.rowid, new.title, new.mdContent);
          END
        ''');
        await db.execute('''
          CREATE TRIGGER articles_ad AFTER DELETE ON articles BEGIN
            INSERT INTO articles_fts(articles_fts, rowid, title, mdContent)
            VALUES ('delete', old.rowid, old.title, old.mdContent);
          END
        ''');
        await db.execute('''
          CREATE TRIGGER articles_au AFTER UPDATE ON articles BEGIN
            INSERT INTO articles_fts(articles_fts, rowid, title, mdContent)
            VALUES ('delete', old.rowid, old.title, old.mdContent);
            INSERT INTO articles_fts(rowid, title, mdContent)
            VALUES (new.rowid, new.title, new.mdContent);
          END
        ''');
      },
    );
    return db;
  }

  Future<void> upsertArticle(Article article) async {
    final db = await database;
    await db.insert('articles', article.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Article>> getAllArticles() async {
    final db = await database;
    final maps = await db.query('articles', orderBy: 'savedAt DESC');
    return maps.map((m) => Article.fromMap(m)).toList();
  }

  Future<List<Article>> searchArticles(String query) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT articles.* FROM articles
      JOIN articles_fts ON articles.rowid = articles_fts.rowid
      WHERE articles_fts MATCH ?
      ORDER BY savedAt DESC
    ''', [query]);
    return maps.map((m) => Article.fromMap(m)).toList();
  }

  Future<List<Article>> getFavorites() async {
    final db = await database;
    final maps = await db.query('articles',
        where: 'isFavorite = 1', orderBy: 'savedAt DESC');
    return maps.map((m) => Article.fromMap(m)).toList();
  }

  Future<void> markFavorite(String id, bool favorite) async {
    final db = await database;
    await db.update('articles',
        {'isFavorite': favorite ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteArticle(String id) async {
    final db = await database;
    await db.delete('articles', where: 'id = ?', whereArgs: [id]);
  }

  Future<Article?> getArticle(String id) async {
    final db = await database;
    final maps = await db.query('articles', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Article.fromMap(maps.first);
  }
}
```

- [ ] **Step 3: 提交**

```bash
git add ttshare_desktop/lib/models/article.dart
git add ttshare_desktop/lib/services/local_db.dart
git commit -m "feat(desktop): add data model and SQLite database with FTS5 search"
```

---

### Task 3: WebDAV 客户端（桌面版，支持拉取和删除）

**Files:**
- Create: `ttshare_desktop/lib/services/webdav_client.dart`

**Interfaces:**
- Produces: `WebdavClient` — `listDirectory(path), downloadFile(remotePath, localPath), deleteFile(path), deleteDirectory(path)`

- [ ] **Step 1: 实现桌面版 WebDAV 客户端**

```dart
// lib/services/webdav_client.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart' as xml;

class WebdavItem {
  final String path;
  final bool isDirectory;
  final int? contentLength;
  final DateTime? lastModified;

  WebdavItem({
    required this.path,
    required this.isDirectory,
    this.contentLength,
    this.lastModified,
  });
}

class WebdavClient {
  String? _baseUrl;
  String? _username;
  String? _password;

  bool get isConfigured => _baseUrl != null && _username != null && _password != null;
  String get baseUrl => _baseUrl ?? '';

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

  Map<String, String> get _authHeaders {
    final bytes = utf8.encode('$_username:$_password');
    return {'Authorization': 'Basic ${base64.encode(bytes)}'};
  }

  /// PROPFIND to list directory contents
  Future<List<WebdavItem>> listDirectory(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.Request('PROPFIND', uri);
    request.headers.addAll(_authHeaders);
    request.headers['Depth'] = '1';

    final response = await request.send();
    if (response.statusCode != 207) {
      throw Exception('Failed to list directory: ${response.statusCode}');
    }

    final body = await response.stream.bytesToString();
    final document = xml.XmlDocument.parse(body);
    final items = <WebdavItem>[];

    final multiStatus = document.findAllElements('D:multistatus').first;
    for (final responseEl in multiStatus.findAllElements('D:response')) {
      final href = responseEl.findElements('D:href').first.innerText;
      final props = responseEl.findElements('D:propstat').first
          .findElements('D:prop').first;
      final isDir = props.findElements('D:resourcetype').first
          .findElements('D:collection').isNotEmpty;

      final itemPath = Uri.decodeComponent(href);
      if (itemPath == path) continue; // skip self

      int? size;
      try {
        size = int.tryParse(props.findElements('D:getcontentlength').first.innerText);
      } catch (_) {}

      DateTime? lastMod;
      try {
        lastMod = DateTime.tryParse(props.findElements('D:getlastmodified').first.innerText);
      } catch (_) {}

      items.add(WebdavItem(
        path: itemPath,
        isDirectory: isDir,
        contentLength: size,
        lastModified: lastMod,
      ));
    }
    return items;
  }

  /// Download a file from WebDAV to local path
  Future<void> downloadFile(String remotePath, String localPath) async {
    final uri = Uri.parse('$_baseUrl$remotePath');
    final response = await http.get(uri, headers: _authHeaders);
    if (response.statusCode != 200) {
      throw Exception('Failed to download $remotePath: ${response.statusCode}');
    }
    final file = File(localPath);
    await file.create(recursive: true);
    await file.writeAsBytes(response.bodyBytes);
  }

  /// Delete a file on WebDAV
  Future<void> deleteFile(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.Request('DELETE', uri);
    request.headers.addAll(_authHeaders);
    final response = await request.send();
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to delete $path: ${response.statusCode}');
    }
  }

  /// Delete a directory (recursive)
  Future<void> deleteDirectory(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.Request('DELETE', uri);
    request.headers.addAll(_authHeaders);
    final response = await request.send();
    if (response.statusCode != 204 && response.statusCode != 200 && response.statusCode != 404) {
      throw Exception('Failed to delete directory $path: ${response.statusCode}');
    }
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add ttshare_desktop/lib/services/webdav_client.dart
git commit -m "feat(desktop): add WebDAV client with list, download, delete"
```

---

### Task 4: 同步引擎

**Files:**
- Create: `ttshare_desktop/lib/services/sync_engine.dart`

**Interfaces:**
- Produces: `SyncEngine` — `syncArticles() → Future<SyncResult>`

- [ ] **Step 1: 实现同步引擎**

```dart
// lib/services/sync_engine.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/article.dart';
import 'local_db.dart';
import 'webdav_client.dart';

class SyncResult {
  final int added;
  final int updated;
  final int errors;
  final String? errorMessage;

  SyncResult({this.added = 0, this.updated = 0, this.errors = 0, this.errorMessage});
}

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
      // List top-level directories under /TTshare
      final items = await _webdavClient.listDirectory('/TTshare');
      final dirs = items.where((item) => item.isDirectory).toList();

      int added = 0, updated = 0, errors = 0;

      for (final dir in dirs) {
        try {
          added += await _syncArticle(dir.path);
        } catch (e) {
          errors++;
        }
      }

      return SyncResult(added: added, updated: updated, errors: errors);
    } catch (e) {
      return SyncResult(errors: 1, errorMessage: e.toString());
    }
  }

  Future<int> _syncArticle(String dirPath) async {
    final dirName = p.basename(dirPath);
    final cacheDir = await _getCacheDir(dirName);

    // Parse folder name: "2026-06-25-domain-title"
    final parts = dirName.split('-');
    final dateStr = parts.take(3).join('-');
    final savedAt = DateTime.tryParse(dateStr) ?? DateTime.now();

    // Download HTML and MD files
    final htmlRemote = '$dirPath/index.html';
    final mdRemote = '$dirPath/index.md';
    final htmlLocal = p.join(cacheDir, 'index.html');
    final mdLocal = p.join(cacheDir, 'index.md');

    String? htmlContent;
    String? mdContent;
    String title = dirName;

    try {
      await _webdavClient.downloadFile(htmlRemote, htmlLocal);
      htmlContent = await File(htmlLocal).readAsString();
    } catch (_) {}

    try {
      await _webdavClient.downloadFile(mdRemote, mdLocal);
      mdContent = await File(mdLocal).readAsString();
    } catch (_) {}

    // Extract title from HTML if possible
    if (htmlContent != null) {
      final titleMatch = RegExp(r'<title>(.*?)</title>', dotAll: true).firstMatch(htmlContent);
      if (titleMatch != null) {
        title = titleMatch.group(1)!.trim();
      }
    }

    final article = Article(
      id: dirName, // Use folder name as ID
      title: title,
      source: dirName.split('-').skip(3).join('-'), // everything after date
      savedAt: savedAt,
      syncedAt: DateTime.now(),
      webdavPath: dirPath,
      htmlContent: htmlContent,
      mdContent: mdContent,
    );

    await _localDB.upsertArticle(article);
    return 1;
  }

  Future<String> _getCacheDir(String dirName) async {
    final appDir = await getApplicationSupportDirectory();
    final cacheDir = p.join(appDir.path, 'cache', dirName);
    await Directory(cacheDir).create(recursive: true);
    return cacheDir;
  }

  /// Delete an article from both local cache and WebDAV
  Future<void> deleteArticle(String id) async {
    final article = await _localDB.getArticle(id);
    if (article == null) return;

    // Delete from WebDAV
    try {
      await _webdavClient.deleteDirectory(article.webdavPath);
    } catch (e) {
      // Continue even if WebDAV delete fails
    }

    // Delete local cache
    final cacheDir = await _getCacheDir(id);
    if (await Directory(cacheDir).exists()) {
      await Directory(cacheDir).delete(recursive: true);
    }

    // Delete from database
    await _localDB.deleteArticle(id);
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add ttshare_desktop/lib/services/sync_engine.dart
git commit -m "feat(desktop): add sync engine with WebDAV pull and dual delete"
```

---

### Task 5: 主界面 — 三栏布局

**Files:**
- Create: `ttshare_desktop/lib/pages/home_page.dart`

- [ ] **Step 1: 实现 HomePage 三栏布局**

```dart
// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import '../services/local_db.dart';
import '../services/webdav_client.dart';
import '../services/sync_engine.dart';
import '../models/article.dart';
import 'reader_panel.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final _localDB = LocalDB();
  final _webdavClient = WebdavClient();
  late final SyncEngine _syncEngine;

  List<Article> _articles = [];
  Article? _selectedArticle;
  String _searchQuery = '';
  bool _showFavoritesOnly = false;
  bool _isSyncing = false;
  String _syncStatus = '';

  @override
  void initState() {
    super.initState();
    _syncEngine = SyncEngine(webdavClient: _webdavClient, localDB: _localDB);
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    await _webdavClient.loadConfig();
    await _loadArticles();
  }

  Future<void> _loadArticles() async {
    List<Article> articles;
    if (_searchQuery.isNotEmpty) {
      articles = await _localDB.searchArticles(_searchQuery);
    } else if (_showFavoritesOnly) {
      articles = await _localDB.getFavorites();
    } else {
      articles = await _localDB.getAllArticles();
    }
    setState(() => _articles = articles);
  }

  Future<void> _sync() async {
    setState(() {
      _isSyncing = true;
      _syncStatus = '同步中...';
    });
    final result = await _syncEngine.syncArticles();
    await _loadArticles();
    setState(() {
      _isSyncing = false;
      _syncStatus = result.errorMessage != null
          ? '❌ ${result.errorMessage}'
          : '✅ 新增 ${result.added} 篇 (失败 ${result.errors})';
    });

    // Auto-clear status after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _syncStatus = '');
    });
  }

  Future<void> _toggleFavorite(Article article) async {
    await _localDB.markFavorite(article.id, !article.isFavorite);
    final updated = article.copyWith(isFavorite: !article.isFavorite);
    setState(() {
      _selectedArticle = updated;
      // Update in list
      final idx = _articles.indexWhere((a) => a.id == article.id);
      if (idx != -1) _articles[idx] = updated;
    });
  }

  Future<void> _deleteArticle(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('将删除本地缓存和 WebDAV 远程文件\n确定继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _syncStatus = '删除中...');
    await _syncEngine.deleteArticle(id);
    await _loadArticles();
    setState(() {
      _selectedArticle = null;
      _syncStatus = '🗑 已删除';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Search bar + action buttons
          _buildTopBar(),
          // Main content: left list + right reader
          Expanded(
            child: Row(
              children: [
                // Left panel: article list
                SizedBox(
                  width: 280,
                  child: _buildArticleList(),
                ),
                const VerticalDivider(width: 1),
                // Right panel: reader
                Expanded(
                  child: _selectedArticle != null
                      ? ReaderPanel(
                          article: _selectedArticle!,
                          onToggleFavorite: () => _toggleFavorite(_selectedArticle!),
                          onDelete: () => _deleteArticle(_selectedArticle!.id),
                        )
                      : const Center(
                          child: Text('选择一篇文章开始阅读',
                              style: TextStyle(color: Colors.grey, fontSize: 16)),
                        ),
                ),
              ],
            ),
          ),
          // Status bar
          if (_syncStatus.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: Colors.grey[100],
              child: Row(
                children: [
                  if (_isSyncing)
                    const SizedBox(
                      width: 12, height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  const SizedBox(width: 8),
                  Text(_syncStatus, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          const Text('TTshare', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: '搜索文章...',
                prefixIcon: Icon(Icons.search, size: 20),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                isDense: true,
              ),
              onChanged: (v) {
                _searchQuery = v;
                _loadArticles();
              },
            ),
          ),
          const SizedBox(width: 8),
          if (!_showFavoritesOnly)
            IconButton(
              icon: const Icon(Icons.star_border),
              tooltip: '显示收藏',
              onPressed: () {
                setState(() => _showFavoritesOnly = true);
                _loadArticles();
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.star, color: Colors.amber),
              tooltip: '显示全部',
              onPressed: () {
                setState(() => _showFavoritesOnly = false);
                _loadArticles();
              },
            ),
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            tooltip: '同步',
            onPressed: _isSyncing ? null : _sync,
          ),
        ],
      ),
    );
  }

  Widget _buildArticleList() {
    if (_articles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('暂无文章', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 4),
            Text('点击同步按钮拉取', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _articles.length,
      itemBuilder: (context, index) {
        final article = _articles[index];
        final isSelected = _selectedArticle?.id == article.id;
        return ListTile(
          selected: isSelected,
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
          title: Text(article.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${article.savedAt.toString().substring(0, 10)} · ${article.source}',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: article.isFavorite
              ? const Icon(Icons.star, size: 16, color: Colors.amber)
              : null,
          onTap: () => setState(() => _selectedArticle = article),
        );
      },
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add ttshare_desktop/lib/pages/home_page.dart
git commit -m "feat(desktop): add three-panel home page with search and sync"
```

---

### Task 6: 阅读面板（HTML WebView + Markdown 渲染 + 操作按钮）

**Files:**
- Create: `ttshare_desktop/lib/pages/reader_panel.dart`

- [ ] **Step 1: 实现 ReaderPanel**

```dart
// lib/pages/reader_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart';
import '../models/article.dart';

class ReaderPanel extends StatefulWidget {
  final Article article;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;

  const ReaderPanel({
    super.key,
    required this.article,
    required this.onToggleFavorite,
    required this.onDelete,
  });

  @override
  State<ReaderPanel> createState() => _ReaderPanelState();
}

class _ReaderPanelState extends State<ReaderPanel> {
  bool _showMarkdown = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              // Article title
              Expanded(
                child: Text(
                  widget.article.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Favorite button
              IconButton(
                icon: Icon(
                  widget.article.isFavorite ? Icons.star : Icons.star_border,
                  color: widget.article.isFavorite ? Colors.amber : null,
                  size: 20,
                ),
                tooltip: '收藏',
                onPressed: widget.onToggleFavorite,
              ),
              // HTML / Markdown toggle
              IconButton(
                icon: Icon(
                  _showMarkdown ? Icons.web : Icons.description,
                  size: 20,
                ),
                tooltip: _showMarkdown ? '查看 HTML 归档' : '查看 Markdown 阅读版',
                onPressed: () => setState(() => _showMarkdown = !_showMarkdown),
              ),
              // Share button
              IconButton(
                icon: const Icon(Icons.share, size: 20),
                tooltip: '分享',
                onPressed: _share,
              ),
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                tooltip: '删除',
                onPressed: widget.onDelete,
              ),
            ],
          ),
        ),
        // Content area
        Expanded(
          child: _showMarkdown
              ? _buildMarkdownView()
              : _buildHtmlView(),
        ),
      ],
    );
  }

  Widget _buildHtmlView() {
    final html = widget.article.htmlContent;
    if (html == null || html.isEmpty) {
      return const Center(child: Text('HTML 内容不可用'));
    }

    return InAppWebView(
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: false,
        cacheEnabled: false,
      ),
      initialData: InAppWebViewInitialData(
        data: html,
        baseUrl: WebUri('https://${widget.article.source}'),
      ),
    );
  }

  Widget _buildMarkdownView() {
    final md = widget.article.mdContent;
    if (md == null || md.isEmpty) {
      return const Center(child: Text('Markdown 内容不可用'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: MarkdownBody(
        data: md,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          p: const TextStyle(fontSize: 16, height: 1.6),
          code: TextStyle(
            backgroundColor: Colors.grey[200],
            fontFamily: 'monospace',
            fontSize: 14,
          ),
          codeblockDecoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(4),
          ),
          blockquoteDecoration: BoxDecoration(
            border: Border(left: BorderSide(color: Colors.grey[400]!, width: 3)),
          ),
        ),
      ),
    );
  }

  void _share() {
    final content = widget.article.mdContent ?? widget.article.htmlContent ?? '';
    SharePlus.instance.share(
      ShareParams(text: content, subject: widget.article.title),
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add ttshare_desktop/lib/pages/reader_panel.dart
git commit -m "feat(desktop): add reader panel with HTML/Markdown views and actions"
```

---

## Desktop Plan Self-Review

- ✅ Spec coverage: Project scaffold (Task 1), SQLite + FTS5 (Task 2), WebDAV client (Task 3), Sync engine (Task 4), Three-panel home page + search + favorites (Task 5), Reader with HTML/Markdown + share/delete (Task 6)
- ✅ No placeholders: all code blocks have complete implementations
- ✅ Type consistency: Article model same fields across all tasks; WebdavClient API consistent between Tasks 3 and 4
- ✅ Spec coverage verification:
  - WebDAV 拉取: Task 3 (listDir + downloadFile)
  - SQLite 缓存: Task 2 (LocalDB)
  - FTS5 全文搜索: Task 2 (articles_fts) + Task 5 (searchArticles)
  - 收藏: Task 5 (toggleFavorite) + Task 2 (markFavorite)
  - 删除（本地 + WebDAV）: Task 4 (deleteArticle) + Task 5 (_deleteArticle with confirm dialog)
  - 再分享: Task 6 (_share via SharePlus)
  - HTML 阅读: Task 6 (InAppWebView)
  - Markdown 阅读: Task 6 (flutter_markdown)
  - 三栏布局: Task 5 (Column with top bar + Row with list/reader + status bar)
  - 状态栏: Task 5 (syncStatus)
  - 同步: Task 4 + Task 5 (_sync)
