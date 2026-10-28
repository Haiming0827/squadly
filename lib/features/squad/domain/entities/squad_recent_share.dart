final class SquadRecentShare {
  const SquadRecentShare({
    required this.messageId,
    required this.authorName,
    required this.title,
    required this.createdAt,
  });

  final String messageId;
  final String authorName;
  final String title;
  final DateTime createdAt;
}
