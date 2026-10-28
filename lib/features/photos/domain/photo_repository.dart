import 'package:fpdart/fpdart.dart';

import '../../../core/error/failures.dart';
import 'photo.dart';

/// Picking only prepares local pixels. A separate explicit send publishes them.
abstract interface class PhotoSourceGateway {
  Future<Either<Failure, PhotoImage?>> pick(PhotoSource source);
}

abstract interface class PhotoRepository {
  /// Must validate the original account, membership and parent before publish.
  /// A retry uses the same nonce and image identity; changed payloads conflict.
  Future<Either<Failure, PublishedPhoto>> publish(PhotoDraft draft);

  /// Returns authenticated image bytes, never a permanent public image URL.
  Future<Either<Failure, PhotoImage>> load({
    required String squadId,
    required String messageId,
  });

  Future<Either<Failure, void>> revoke({
    required String squadId,
    required String messageId,
  });
}
