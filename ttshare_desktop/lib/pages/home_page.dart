import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
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

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _syncStatus = '');
    });
  }

  Future<void> _toggleFavorite(Article article) async {
    await _localDB.markFavorite(article.id, !article.isFavorite);
    final updated = article.copyWith(isFavorite: !article.isFavorite);
    setState(() {
      _selectedArticle = updated;
      final idx = _articles.indexWhere((a) => a.id == article.id);
      if (idx != -1) _articles[idx] = updated;
    });
  }

  Future<void> _deleteArticle(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content:
            const Text('将删除本地缓存和 WebDAV 远程文件\n确定继续？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('删除', style: TextStyle(color: Colors.red)),
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
          _buildTopBar(),
          Expanded(
            child: Row(
              children: [
                SizedBox(width: 280, child: _buildArticleList()),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _selectedArticle != null
                      ? ReaderPanel(
                          article: _selectedArticle!,
                          onToggleFavorite: () =>
                              _toggleFavorite(_selectedArticle!),
                          onDelete: () => _deleteArticle(_selectedArticle!.id),
                        )
                      : const Center(
                          child: Text('选择一篇文章开始阅读',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 16)),
                        ),
                ),
              ],
            ),
          ),
          if (_syncStatus.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: Colors.grey[100],
              child: Row(
                children: [
                  if (_isSyncing)
                    const SizedBox(
                      width: 12,
                      height: 12,
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
          const Text('TTshare',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: '搜索文章...',
                prefixIcon: Icon(Icons.search, size: 20),
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                isDense: true,
              ),
              onChanged: (v) {
                _searchQuery = v;
                _loadArticles();
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
                _showFavoritesOnly ? Icons.star : Icons.star_border,
                color: _showFavoritesOnly ? Colors.amber : null),
            tooltip: _showFavoritesOnly ? '显示全部' : '显示收藏',
            onPressed: () {
              setState(() => _showFavoritesOnly = !_showFavoritesOnly);
              _loadArticles();
            },
          ),
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
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
            Text('点击同步按钮拉取',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
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
          selectedTileColor:
              Theme.of(context).colorScheme.primaryContainer,
          title: Text(article.title,
              maxLines: 1, overflow: TextOverflow.ellipsis),
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
