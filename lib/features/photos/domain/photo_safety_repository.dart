import 'package:fpdart/fpdart.dart';

import '../../../core/error/failures.dart';

enum PhotoReportReason { spam, harassment, privacy, other }

/// Receiver preferences do not retract the author's message for teammates.
abstract interface class PhotoSafetyRepository {
  Future<Either<Failure, void>> hide({
    required String squadId,
    required String messageId,
  });
  Future<Either<Failure, void>> report({
    required String squadId,
    required String messageId,
    required PhotoReportReason reason,
  });
}
