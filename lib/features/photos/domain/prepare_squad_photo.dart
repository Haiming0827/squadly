import 'package:fpdart/fpdart.dart';

import '../../../core/error/failures.dart';
import 'photo.dart';
import 'photo_repository.dart';

typedef PhotoTargetAccess = Future<bool> Function(PhotoTarget target);

/// Rechecks the captured account/target after a system picker suspends the app.
final class PrepareSquadPhoto {
  const PrepareSquadPhoto({
    required this._source,
    required this._canAccess,
    required this._nonce,
    required this._clock,
  });

  final PhotoSourceGateway _source;
  final PhotoTargetAccess _canAccess;
  final String Function() _nonce;
  final DateTime Function() _clock;

  Future<Either<Failure, PhotoDraft?>> call({
    required PhotoTarget target,
    required PhotoSource source,
  }) async {
    if (target.userId.trim().isEmpty ||
        target.userId.length > 64 ||
        !_uuid(target.squadId) ||
        target.squadName.trim().isEmpty ||
        (target.replyToMessageId != null && !_uuid(target.replyToMessageId!))) {
      return left(const Failure.validation(message: '请确认要发送的小队'));
    }
    try {
      if (!await _canAccess(target)) return left(_denied);
      final picked = await _source.pick(source);
      return await picked.fold((failure) async => left(failure), (image) async {
        if (image == null) return right(null);
        if (!await _canAccess(target)) return left(_denied);
        final nonce = _nonce();
        if (!_uuid(nonce)) {
          return left(const Failure.validation(message: '无法准备照片，请重试'));
        }
        return right(
          PhotoDraft(
            target: target,
            image: image,
            clientNonce: nonce,
            preparedAt: _clock().toUtc(),
          ),
        );
      });
    } catch (_) {
      return left(const Failure.network(message: '无法确认小队权限，请稍后重试'));
    }
  }

  static const _denied = Failure.permissionDenied(message: '账号或小队已变化，请重新选择照片');

  static bool _uuid(String value) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
}
