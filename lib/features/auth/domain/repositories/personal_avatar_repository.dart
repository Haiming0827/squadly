import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';

abstract interface class PersonalAvatarRepository {
  /// The adapter is bound to the originating account. Null restores initials.
  Future<Either<Failure, void>> save(String? avatar);
}
