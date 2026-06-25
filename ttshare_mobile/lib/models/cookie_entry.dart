class CookieEntry {
  final String domain;
  final String cookieData;
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
