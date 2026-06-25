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
        leading: Icon(_statusIcon, color: _statusColor, size: 28),
        title: Text(
          record.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15),
        ),
        subtitle: Text(
          '$dateStr · ${record.source}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: record.status == 'failed'
            ? IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  IconData get _statusIcon {
    switch (record.status) {
      case 'completed':
        return Icons.check_circle;
      case 'uploading':
        return Icons.cloud_upload;
      case 'failed':
        return Icons.error;
      default:
        return Icons.hourglass_empty;
    }
  }

  Color get _statusColor {
    switch (record.status) {
      case 'completed':
        return Colors.green;
      case 'uploading':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
