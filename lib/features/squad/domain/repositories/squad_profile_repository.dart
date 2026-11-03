import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';

abstract interface class SquadProfileRepository {
  /// Null avatar restores the default. Only the current captain may save.
  Future<Either<Failure, void>> save({
    required String squadId,
    required String name,
    required String description,
    required String? avatar,
  });
}

abstract interface class SquadAvatarPicker {
  /// A cancelled system picker returns null. No upload occurs here.
  Future<Either<Failure, String?>> pick();
}
