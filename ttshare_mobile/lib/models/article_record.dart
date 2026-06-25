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
