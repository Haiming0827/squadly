import 'activity_record.dart';

/// Sources never publish raw workout data; callers must explicitly choose one.
abstract interface class ActivitySource {
  Future<List<ActivityRecord>> listEligibleActivities({
    required DateTime from,
    required DateTime to,
  });

  Future<ActivityRecord> readActivity(String id);

  Future<ActivityRecord> readPreciseRoute(ActivityRecord selected);
}

final class ActivitySourceUnavailable implements Exception {
  const ActivitySourceUnavailable();
}

final class ActivityPermissionDenied implements Exception {
  const ActivityPermissionDenied();
}

final class ActivityNotFound implements Exception {
  const ActivityNotFound();
}
