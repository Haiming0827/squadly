import 'package:fpdart/fpdart.dart';

import '../../../core/error/failures.dart';
import 'photo_head.dart';
import 'timeline_entry.dart';

/// Online photo-only views of the same ordinary Squad message timeline.
/// Neither operation advances read cursors or returns image bytes/URLs.
abstract interface class ConversationPhotoRepository {
  Future<Either<Failure, PhotoHead>> photoHead(String squadId);
  Future<Either<Failure, List<TimelineEntry>>> pagePhotos(
    String squadId, {
    TimelineCursor? before,
    int limit = 50,
  });
  Future<Either<Failure, TimelineEntry?>> findPhoto({
    required String squadId,
    required String messageId,
  });
}
