import 'package:freezed_annotation/freezed_annotation.dart';

import '../../secure_route/domain/route_models.dart';

part 'activity_record.freezed.dart';

enum ActivityKind { run, hike }

enum ActivitySourceKind {
  manual,
  appleHealth,
  xiaomiHealth,
  huaweiHealth,
  gpxFile,
  fileImport,
}

/// A private, locally held workout. No repository method publishes this type.
@freezed
abstract class ActivityRecord with _$ActivityRecord {
  const factory ActivityRecord({
    required String id,
    required ActivitySourceKind source,
    required ActivityKind kind,
    required DateTime startedAt,
    required int utcOffsetMinutes,
    required double distanceMeters,
    required int durationSeconds,
    required String sourceLabel,
    int? averageHeartRateBpm,
    List<RouteCoordinate>? preciseRoute,
    @Default(<String>{}) Set<String> correctedFields,
  }) = _ActivityRecord;
}

final class ActivityMetrics {
  const ActivityMetrics._();

  static int paceSecondsPerKm(ActivityRecord record) {
    if (!record.distanceMeters.isFinite ||
        record.distanceMeters <= 0 ||
        record.durationSeconds <= 0) {
      throw ArgumentError('Distance and duration must be positive');
    }
    return (record.durationSeconds * 1000 / record.distanceMeters).round();
  }

  /// The original calendar day, not the UTC day after offset normalization.
  static DateTime localCalendarDate(ActivityRecord record) {
    final wallTime = record.startedAt.toUtc().add(
      Duration(minutes: record.utcOffsetMinutes),
    );
    return DateTime(wallTime.year, wallTime.month, wallTime.day);
  }
}

final class ActivityCorrection {
  const ActivityCorrection._();

  static ActivityRecord apply(
    ActivityRecord record, {
    double? distanceMeters,
    int? durationSeconds,
    DateTime? startedAt,
    int? averageHeartRateBpm,
  }) {
    final corrected = {...record.correctedFields};
    if (distanceMeters != null && distanceMeters != record.distanceMeters) {
      corrected.add('distance_m');
    }
    if (durationSeconds != null && durationSeconds != record.durationSeconds) {
      corrected.add('duration_s');
    }
    if (startedAt != null && startedAt != record.startedAt) {
      corrected.add('started_at');
    }
    if (averageHeartRateBpm != null &&
        averageHeartRateBpm != record.averageHeartRateBpm) {
      corrected.add('avg_heart_rate_bpm');
    }
    final result = record.copyWith(
      distanceMeters: distanceMeters ?? record.distanceMeters,
      durationSeconds: durationSeconds ?? record.durationSeconds,
      startedAt: startedAt ?? record.startedAt,
      averageHeartRateBpm: averageHeartRateBpm ?? record.averageHeartRateBpm,
      correctedFields: corrected,
    );
    ActivityMetrics.paceSecondsPerKm(result);
    if (result.averageHeartRateBpm != null &&
        (result.averageHeartRateBpm! < 30 ||
            result.averageHeartRateBpm! > 240)) {
      throw ArgumentError.value(
        result.averageHeartRateBpm,
        'averageHeartRateBpm',
      );
    }
    return result;
  }
}
