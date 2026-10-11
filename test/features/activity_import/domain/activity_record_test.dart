import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/activity_import/domain/activity_record.dart';

void main() {
  final original = ActivityRecord(
    id: 'workout-1',
    source: ActivitySourceKind.appleHealth,
    kind: ActivityKind.run,
    startedAt: DateTime.parse('2026-10-08T06:00:00+08:00'),
    utcOffsetMinutes: 480,
    distanceMeters: 5200,
    durationSeconds: 1800,
    sourceLabel: 'Apple 健康',
  );

  test('pace derives from distance and duration without rounding to zero', () {
    expect(ActivityMetrics.paceSecondsPerKm(original), 346);
    expect(
      () => ActivityMetrics.paceSecondsPerKm(
        original.copyWith(distanceMeters: 0),
      ),
      throwsArgumentError,
    );
  });

  test('manual correction preserves provenance and marks changed fields', () {
    final corrected = ActivityCorrection.apply(
      original,
      distanceMeters: 5400,
      durationSeconds: 1780,
    );

    expect(corrected.id, original.id);
    expect(corrected.source, ActivitySourceKind.appleHealth);
    expect(corrected.distanceMeters, 5400);
    expect(corrected.durationSeconds, 1780);
    expect(corrected.correctedFields, {'distance_m', 'duration_s'});
    expect(original.correctedFields, isEmpty);
  });

  test('bad corrections are rejected before local persistence or sharing', () {
    expect(
      () => ActivityCorrection.apply(original, distanceMeters: double.nan),
      throwsArgumentError,
    );
    expect(
      () => ActivityCorrection.apply(original, durationSeconds: -1),
      throwsArgumentError,
    );
  });
}
