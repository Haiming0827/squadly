import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/photos/domain/coordinated_photo_safety.dart';
import '../../features/photos/domain/photo_safety_repository.dart';
import 'current_user_provider.dart';
import 'photo_providers.dart';
import 'photo_widget_providers.dart';

final photoSafetyRepositoryProvider = Provider<PhotoSafetyRepository?>((ref) {
  final repository = ref.watch(photoRepositoryProvider);
  final user = ref.watch(currentUserProvider).asData?.value?.id;
  if (repository is! PhotoSafetyRepository || user == null) return null;
  var active = true;
  ref.onDispose(() => active = false);
  return CoordinatedPhotoSafety(
    repository: repository as PhotoSafetyRepository,
    isCurrent: () =>
        active &&
        ref.read(currentUserProvider).asData?.value?.id == user &&
        ref.read(photoSessionReadyProvider),
    protect: (squad, message) =>
        ref.read(photoWidgetServiceProvider).suppressPhoto(squad, message),
    confirmed: () async {
      if (active) await ref.read(photoWidgetServiceProvider).refresh();
    },
  );
});
