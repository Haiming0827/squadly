import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../conversation/domain/conversation_repository.dart';
import '../../../conversation/domain/timeline_entry.dart';
import '../entities/squad_recent_share.dart';

final class GetSquadRecentShares {
  const GetSquadRecentShares(this._conversationRepository);

  final ConversationRepository _conversationRepository;

  Future<Either<Failure, List<SquadRecentShare>>> call({
    required String squadId,
    int limit = 3,
  }) async {
    if (squadId.trim().isEmpty || limit < 1 || limit > 20) {
      return left(const Failure.validation(message: '小队分享查询参数无效'));
    }

    final result = await _conversationRepository.loadRecent(squadId);
    return result.map((entries) {
      final shares =
          entries
              .where((entry) => entry.kind == TimelineEntryKind.card)
              .map(_toShare)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return List.unmodifiable(shares.take(limit));
    });
  }

  SquadRecentShare _toShare(TimelineEntry entry) {
    final rawTitle = entry.cardSnapshot?.payload['title'];
    final title = rawTitle is String && rawTitle.trim().isNotEmpty
        ? rawTitle.trim()
        : '分享了一张内容卡片';
    return SquadRecentShare(
      messageId: entry.id,
      authorName: entry.authorName,
      title: title,
      createdAt: entry.createdAt,
    );
  }
}
