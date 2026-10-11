/// 经用户确认后发布到小队空间的数据内容卡片。
final class SocialPost {
  SocialPost({
    required this.id,
    required this.squadId,
    required this.authorId,
    required this.authorName,
    required this.title,
    required this.body,
    required this.template,
    required this.visibility,
    required this.sourceLabel,
    required this.metricValue,
    required this.metricUnit,
    required this.rangeStart,
    required this.rangeEnd,
    required this.createdAt,
    List<double> trend = const [],
    List<String> visibleToUserIds = const [],
    List<String> reactionUserIds = const [],
    this.commentCount = 0,
  }) : trend = List.unmodifiable(trend),
       visibleToUserIds = List.unmodifiable(visibleToUserIds),
       reactionUserIds = List.unmodifiable(reactionUserIds);

  final String id;
  final String squadId;
  final String authorId;
  final String authorName;
  final String title;
  final String body;
  final String template;
  final String visibility;
  final String sourceLabel;
  final String metricValue;
  final String metricUnit;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final DateTime createdAt;
  final List<double> trend;
  final List<String> visibleToUserIds;
  final List<String> reactionUserIds;
  final int commentCount;

  SocialPost copyWith({
    String? id,
    String? squadId,
    String? authorId,
    String? authorName,
    String? title,
    String? body,
    String? template,
    String? visibility,
    String? sourceLabel,
    String? metricValue,
    String? metricUnit,
    DateTime? rangeStart,
    DateTime? rangeEnd,
    DateTime? createdAt,
    List<double>? trend,
    List<String>? visibleToUserIds,
    List<String>? reactionUserIds,
    int? commentCount,
  }) => SocialPost(
    id: id ?? this.id,
    squadId: squadId ?? this.squadId,
    authorId: authorId ?? this.authorId,
    authorName: authorName ?? this.authorName,
    title: title ?? this.title,
    body: body ?? this.body,
    template: template ?? this.template,
    visibility: visibility ?? this.visibility,
    sourceLabel: sourceLabel ?? this.sourceLabel,
    metricValue: metricValue ?? this.metricValue,
    metricUnit: metricUnit ?? this.metricUnit,
    rangeStart: rangeStart ?? this.rangeStart,
    rangeEnd: rangeEnd ?? this.rangeEnd,
    createdAt: createdAt ?? this.createdAt,
    trend: trend ?? this.trend,
    visibleToUserIds: visibleToUserIds ?? this.visibleToUserIds,
    reactionUserIds: reactionUserIds ?? this.reactionUserIds,
    commentCount: commentCount ?? this.commentCount,
  );

  factory SocialPost.fromJson(Map<String, dynamic> json) => SocialPost(
    id: json['id'] as String,
    squadId: json['squadId'] as String,
    authorId: json['authorId'] as String,
    authorName: json['authorName'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    template: json['template'] as String,
    visibility: json['visibility'] as String,
    sourceLabel: json['sourceLabel'] as String,
    metricValue: json['metricValue'] as String,
    metricUnit: json['metricUnit'] as String,
    rangeStart: DateTime.parse(json['rangeStart'] as String),
    rangeEnd: DateTime.parse(json['rangeEnd'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    trend:
        (json['trend'] as List<dynamic>?)
            ?.map((value) => (value as num).toDouble())
            .toList() ??
        const [],
    visibleToUserIds:
        (json['visibleToUserIds'] as List<dynamic>?)
            ?.map((value) => value as String)
            .toList() ??
        const [],
    reactionUserIds:
        (json['reactionUserIds'] as List<dynamic>?)
            ?.map((value) => value as String)
            .toList() ??
        const [],
    commentCount: json['commentCount'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'squadId': squadId,
    'authorId': authorId,
    'authorName': authorName,
    'title': title,
    'body': body,
    'template': template,
    'visibility': visibility,
    'sourceLabel': sourceLabel,
    'metricValue': metricValue,
    'metricUnit': metricUnit,
    'rangeStart': rangeStart.toIso8601String(),
    'rangeEnd': rangeEnd.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'trend': trend,
    'visibleToUserIds': visibleToUserIds,
    'reactionUserIds': reactionUserIds,
    'commentCount': commentCount,
  };
}
