import 'package:fpdart/fpdart.dart';

import '../../../core/error/failures.dart';
import 'photo_safety_repository.dart';

/// Clears local copies before a potentially delayed server hide/report commit.
final class CoordinatedPhotoSafety implements PhotoSafetyRepository {
  const CoordinatedPhotoSafety({
    required this.repository,
    required this.isCurrent,
    required this.protect,
    required this.confirmed,
  });
  final PhotoSafetyRepository repository;
  final bool Function() isCurrent;
  final Future<void> Function(String squadId, String messageId) protect;
  final Future<void> Function() confirmed;

  Future<Either<Failure, void>> _run(
    String squad,
    String message,
    PhotoReportReason? reason,
  ) async {
    const changed = Failure.unauthorized(message: '账号或会话已变化，请重新打开');
    if (!isCurrent()) return left(changed);
    try {
      await protect(squad, message);
      if (!isCurrent()) return left(changed);
      final result = reason == null
          ? await repository.hide(squadId: squad, messageId: message)
          : await repository.report(
              squadId: squad,
              messageId: message,
              reason: reason,
            );
      if (!isCurrent()) return left(changed);
      if (result.isRight()) await confirmed();
      return isCurrent() ? result : left(changed);
    } catch (_) {
      return left(const Failure.network(message: '操作未确认，请稍后重试'));
    }
  }

  @override
  Future<Either<Failure, void>> hide({
    required String squadId,
    required String messageId,
  }) => _run(squadId, messageId, null);
  @override
  Future<Either<Failure, void>> report({
    required String squadId,
    required String messageId,
    required PhotoReportReason reason,
  }) => _run(squadId, messageId, reason);
}
