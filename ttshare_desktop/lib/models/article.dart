class Article {
  final String id;
  final String title;
  final String source;
  final DateTime savedAt;
  final DateTime? syncedAt;
  final bool isFavorite;
  final String webdavPath;
  final String? htmlContent;
  final String? mdContent;
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
    syncedAt: map['syncedAt'] != null
        ? DateTime.parse(map['syncedAt'] as String)
        : null,
    isFavorite: (map['isFavorite'] as int) == 1,
    webdavPath: map['webdavPath'] as String,
    htmlContent: map['htmlContent'] as String?,
    mdContent: map['mdContent'] as String?,
    errorMessage: map['errorMessage'] as String?,
  );
}
