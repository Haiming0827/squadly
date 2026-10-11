/// 从第三方应用导入后存放在个人空间的数据素材。
final class ExternalDataItem {
  ExternalDataItem({
    required this.id,
    required this.userId,
    required this.source,
    required this.sourceLabel,
    required this.category,
    required this.title,
    required this.summary,
    required this.value,
    required this.unit,
    required this.rangeStart,
    required this.rangeEnd,
    required this.importedAt,
    List<double> trend = const [],
  }) : trend = List.unmodifiable(trend);

  final String id;
  final String userId;
  final String source;
  final String sourceLabel;
  final String category;
  final String title;
  final String summary;
  final String value;
  final String unit;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final DateTime importedAt;
  final List<double> trend;

  ExternalDataItem copyWith({
    String? id,
    String? userId,
    String? source,
    String? sourceLabel,
    String? category,
    String? title,
    String? summary,
    String? value,
    String? unit,
    DateTime? rangeStart,
    DateTime? rangeEnd,
    DateTime? importedAt,
    List<double>? trend,
  }) => ExternalDataItem(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    source: source ?? this.source,
    sourceLabel: sourceLabel ?? this.sourceLabel,
    category: category ?? this.category,
    title: title ?? this.title,
    summary: summary ?? this.summary,
    value: value ?? this.value,
    unit: unit ?? this.unit,
    rangeStart: rangeStart ?? this.rangeStart,
    rangeEnd: rangeEnd ?? this.rangeEnd,
    importedAt: importedAt ?? this.importedAt,
    trend: trend ?? this.trend,
  );

  factory ExternalDataItem.fromJson(Map<String, dynamic> json) =>
      ExternalDataItem(
        id: json['id'] as String,
        userId: json['userId'] as String,
        source: json['source'] as String,
        sourceLabel: json['sourceLabel'] as String,
        category: json['category'] as String,
        title: json['title'] as String,
        summary: json['summary'] as String,
        value: json['value'] as String,
        unit: json['unit'] as String,
        rangeStart: DateTime.parse(json['rangeStart'] as String),
        rangeEnd: DateTime.parse(json['rangeEnd'] as String),
        importedAt: DateTime.parse(json['importedAt'] as String),
        trend:
            (json['trend'] as List<dynamic>?)
                ?.map((value) => (value as num).toDouble())
                .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'source': source,
    'sourceLabel': sourceLabel,
    'category': category,
    'title': title,
    'summary': summary,
    'value': value,
    'unit': unit,
    'rangeStart': rangeStart.toIso8601String(),
    'rangeEnd': rangeEnd.toIso8601String(),
    'importedAt': importedAt.toIso8601String(),
    'trend': trend,
  };
}
