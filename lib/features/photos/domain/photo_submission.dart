import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/error/failures.dart';
import 'photo.dart';

part 'photo_submission.freezed.dart';

typedef ConfirmPhoto = Future<PhotoSubmissionResult> Function(PhotoDraft draft);

/// Distinguishes a durable queue entry from an unconfirmed local disk write.
@freezed
sealed class PhotoSubmissionResult with _$PhotoSubmissionResult {
  const factory PhotoSubmissionResult.sent() = PhotoSubmissionSent;
  const factory PhotoSubmissionResult.pending(Failure failure) =
      PhotoSubmissionPending;
  const factory PhotoSubmissionResult.rejected(Failure failure) =
      PhotoSubmissionRejected;
  const factory PhotoSubmissionResult.unconfirmed(Failure failure) =
      PhotoSubmissionUnconfirmed;
}

bool sameConfirmedPhoto(PhotoDraft a, PhotoDraft b) {
  if (a.target != b.target ||
      a.clientNonce != b.clientNonce ||
      !a.preparedAt.isAtSameMomentAs(b.preparedAt) ||
      a.image.width != b.image.width ||
      a.image.height != b.image.height ||
      a.image.sha256 != b.image.sha256 ||
      a.image.bytes.length != b.image.bytes.length) {
    return false;
  }
  for (var i = 0; i < a.image.bytes.length; i++) {
    if (a.image.bytes[i] != b.image.bytes[i]) return false;
  }
  return true;
}
