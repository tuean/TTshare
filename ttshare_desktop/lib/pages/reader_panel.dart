import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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
              Expanded(
                child: Text(
                  widget.article.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(
                  widget.article.isFavorite
                      ? Icons.star
                      : Icons.star_border,
                  color: widget.article.isFavorite ? Colors.amber : null,
                  size: 20,
                ),
                tooltip: '收藏',
                onPressed: widget.onToggleFavorite,
              ),
              IconButton(
                icon: Icon(
                  _showMarkdown ? Icons.web : Icons.description,
                  size: 20,
                ),
                tooltip: _showMarkdown ? '查看 HTML 归档' : '查看 Markdown',
                onPressed: () =>
                    setState(() => _showMarkdown = !_showMarkdown),
              ),
              IconButton(
                icon: const Icon(Icons.share, size: 20),
                tooltip: '分享',
                onPressed: _share,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: Colors.red),
                tooltip: '删除',
                onPressed: widget.onDelete,
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: _showMarkdown ? _buildMarkdownView() : _buildHtmlView(),
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
            border:
                Border(left: BorderSide(color: Colors.grey[400]!, width: 3)),
          ),
        ),
      ),
    );
  }

  void _share() {
    final content =
        widget.article.mdContent ?? widget.article.htmlContent ?? '';
    SharePlus.instance.share(
      ShareParams(text: content, subject: widget.article.title),
    );
  }
}
