import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/share_receiver.dart';
import '../services/processing_pipeline.dart';
import '../services/cookie_manager.dart';
import '../services/web_view_loader.dart';
import '../services/html_archiver.dart';
import '../services/readability_extractor.dart';
import '../services/webdav_client.dart';
import '../models/article_record.dart';
import '../widgets/article_tile.dart';
import 'settings_page.dart';
import '../main.dart' show flutterLocalNotificationsPlugin;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final _shareReceiver = ShareReceiver();
  final _records = <ArticleRecord>[];
  Timer? _pollTimer;
  ProcessingPipeline? _pipeline;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initPipeline();
    _loadRecords();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initPipeline() async {
    final webdav = WebdavClient();
    await webdav.loadConfig();
    _pipeline = ProcessingPipeline(
      cookieManager: CookieManager(),
      webViewLoader: WebViewLoader(),
      htmlArchiver: HtmlArchiver(),
      readabilityExtractor: ReadabilityExtractor(),
      webdavClient: webdav,
    );
    _initialized = true;

    // Start polling for shared content after pipeline is ready
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkForShare());
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = prefs.getStringList('records') ?? [];
    setState(() {
      _records.clear();
      for (final jsonStr in recordsJson.reversed) {
        _records.add(ArticleRecord.fromJson(
            json.decode(jsonStr) as Map<String, dynamic>));
      }
    });
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = _records.map((r) => json.encode(r.toJson())).toList();
    await prefs.setStringList('records', recordsJson);
  }

  Future<void> addRecord(ArticleRecord record) async {
    setState(() => _records.insert(0, record));
    await _saveRecords();
  }

  Future<void> updateRecord(int index, ArticleRecord record) async {
    setState(() => _records[index] = record);
    await _saveRecords();
  }

  Future<void> _checkForShare() async {
    if (!_initialized || _pipeline == null) return;

    final content = await _shareReceiver.getSharedContent();
    final url = content['url'];
    final title = content['title'];

    if (url == null || url.isEmpty) return;
    if (_records.any((r) => r.url == url)) return;

    final pendingRecord = ArticleRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title?.isNotEmpty == true ? title! : url,
      source: Uri.tryParse(url)?.host ?? 'unknown',
      url: url,
      savedAt: DateTime.now(),
      status: 'uploading',
    );

    await addRecord(pendingRecord);

    // Process in background
    final result = await _pipeline!.process(url, title ?? url);

    final idx = _records.indexWhere((r) => r.id == pendingRecord.id);
    if (idx != -1) {
      await updateRecord(idx, result.record);
    }

    // Show notification
    await flutterLocalNotificationsPlugin.show(
      result.record.id.hashCode,
      result.success ? '保存成功' : '保存失败',
      result.success
          ? '${result.record.title} 已上传到坚果云'
          : '${result.record.title}: ${result.error ?? "未知错误"}',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'ttshare_channel',
          'TTshare 保存通知',
          channelDescription: '网页快照保存结果通知',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
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
                  SizedBox(height: 8),
                  Text('TTshare 会自动保存网页快照',
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadRecords,
              child: ListView.builder(
                itemCount: _records.length,
                itemBuilder: (context, index) => ArticleTile(
                  record: _records[index],
                  onRetry: () => _retryProcessing(index),
                ),
              ),
            ),
    );
  }

  Future<void> _retryProcessing(int index) async {
    if (_pipeline == null) return;
    final record = _records[index];
    final updated = record.copyWith(status: 'uploading', errorMessage: null);
    await updateRecord(index, updated);

    final result = await _pipeline!.process(record.url, record.title);
    await updateRecord(index, result.record);
  }
}
