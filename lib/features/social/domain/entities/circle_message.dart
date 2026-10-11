/// 小队内部的即时文本消息。
final class CircleMessage {
  const CircleMessage({
    required this.id,
    required this.squadId,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String squadId;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime createdAt;

  CircleMessage copyWith({
    String? id,
    String? squadId,
    String? authorId,
    String? authorName,
    String? text,
    DateTime? createdAt,
  }) => CircleMessage(
    id: id ?? this.id,
    squadId: squadId ?? this.squadId,
    authorId: authorId ?? this.authorId,
    authorName: authorName ?? this.authorName,
    text: text ?? this.text,
    createdAt: createdAt ?? this.createdAt,
  );

  factory CircleMessage.fromJson(Map<String, dynamic> json) => CircleMessage(
    id: json['id'] as String,
    squadId: json['squadId'] as String,
    authorId: json['authorId'] as String,
    authorName: json['authorName'] as String,
    text: json['text'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'squadId': squadId,
    'authorId': authorId,
    'authorName': authorName,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };
}
