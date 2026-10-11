import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:squadly/features/activity_import/data/apple_health_activity_source.dart';
import 'package:squadly/features/activity_import/domain/activity_record.dart';
import 'package:squadly/features/activity_import/domain/activity_source.dart';

final class _Gateway implements AppleHealthGateway {
  bool allowWorkout = true;
  bool allowRoute = true;
  final requested = <HealthDataType>[];
  final queries = <HealthDataType>[];
  List<HealthDataPoint> workouts = [];
  List<HealthDataPoint> routes = [];

  @override
  Future<void> configure() async {}

  @override
  Future<bool> requestRead(HealthDataType type) async {
    requested.add(type);
    return type == HealthDataType.WORKOUT ? allowWorkout : allowRoute;
  }

  @override
  Future<List<HealthDataPoint>> read(
    HealthDataType type,
    DateTime from,
    DateTime to,
  ) async {
    queries.add(type);
    return type == HealthDataType.WORKOUT ? workouts : routes;
  }
}

HealthDataPoint _point({
  required String id,
  required HealthValue value,
  required HealthDataType type,
  HealthPlatformType platform = HealthPlatformType.appleHealth,
}) => HealthDataPoint(
  uuid: id,
  value: value,
  type: type,
  unit: HealthDataUnit.NO_UNIT,
  dateFrom: DateTime(2026, 10, 8, 6),
  dateTo: DateTime(2026, 10, 8, 6, 30),
  sourcePlatform: platform,
  sourceDeviceId: 'device',
  sourceId: 'source',
  sourceName: 'Apple Watch',
);

void main() {
  final from = DateTime(2026, 10, 1);
  final to = DateTime(2026, 10, 10);

  test('lists only valid run/hike workouts and normalizes distance', () async {
    final gateway = _Gateway()
      ..workouts = [
        _point(
          id: 'run',
          type: HealthDataType.WORKOUT,
          value: WorkoutHealthValue(
            workoutActivityType: HealthWorkoutActivityType.RUNNING,
            totalDistance: 5,
            totalDistanceUnit: HealthDataUnit.MILE,
          ),
        ),
        _point(
          id: 'hike',
          type: HealthDataType.WORKOUT,
          value: WorkoutHealthValue(
            workoutActivityType: HealthWorkoutActivityType.HIKING,
            totalDistance: 3000,
            totalDistanceUnit: HealthDataUnit.METER,
          ),
        ),
        _point(
          id: 'other',
          type: HealthDataType.WORKOUT,
          value: WorkoutHealthValue(
            workoutActivityType: HealthWorkoutActivityType.BIKING,
            totalDistance: 4000,
            totalDistanceUnit: HealthDataUnit.METER,
          ),
        ),
        _point(
          id: 'missing-distance',
          type: HealthDataType.WORKOUT,
          value: WorkoutHealthValue(
            workoutActivityType: HealthWorkoutActivityType.RUNNING,
          ),
        ),
      ];
    final source = AppleHealthActivitySource(gateway: gateway, isIOS: true);
    final records = await source.listEligibleActivities(from: from, to: to);
    expect(records.map((record) => record.id), ['run', 'hike']);
    expect(records.first.distanceMeters, closeTo(8046.72, 0.001));
    expect(records.first.durationSeconds, 1800);
    expect(records.first.source, ActivitySourceKind.appleHealth);
    expect(gateway.requested, [HealthDataType.WORKOUT]);
    expect(gateway.queries, [HealthDataType.WORKOUT]);
    expect((await source.readActivity('run')).id, 'run');
    await expectLater(
      source.readActivity('missing'),
      throwsA(isA<ActivityNotFound>()),
    );
  });

  test(
    'route is requested separately and only matching workout is used',
    () async {
      final gateway = _Gateway()
        ..workouts = [
          _point(
            id: 'chosen',
            type: HealthDataType.WORKOUT,
            value: WorkoutHealthValue(
              workoutActivityType: HealthWorkoutActivityType.HIKING,
              totalDistance: 2000,
              totalDistanceUnit: HealthDataUnit.METER,
            ),
          ),
        ]
        ..routes = [
          _point(
            id: 'other-route',
            type: HealthDataType.WORKOUT_ROUTE,
            value: WorkoutRouteHealthValue(
              workoutUuid: 'other',
              locations: [
                WorkoutRouteLocation(
                  latitude: 1,
                  longitude: 1,
                  timestamp: from,
                ),
              ],
            ),
          ),
          _point(
            id: 'chosen-route',
            type: HealthDataType.WORKOUT_ROUTE,
            value: WorkoutRouteHealthValue(
              workoutUuid: 'chosen',
              locations: [
                WorkoutRouteLocation(
                  latitude: 31.2,
                  longitude: 121.5,
                  timestamp: from,
                ),
                WorkoutRouteLocation(
                  latitude: 99,
                  longitude: 121.5,
                  timestamp: from,
                ),
              ],
            ),
          ),
        ];
      final source = AppleHealthActivitySource(gateway: gateway, isIOS: true);
      final selected = (await source.listEligibleActivities(
        from: from,
        to: to,
      )).single;
      expect(selected.preciseRoute, isNull);
      final withRoute = await source.readPreciseRoute(selected);
      expect(withRoute.preciseRoute, hasLength(1));
      expect(withRoute.preciseRoute!.single.latitude, 31.2);
      expect(gateway.requested, [
        HealthDataType.WORKOUT,
        HealthDataType.WORKOUT_ROUTE,
      ]);
    },
  );

  test(
    'denied permissions, unavailable platform and unselected ID fail closed',
    () async {
      final gateway = _Gateway()..allowWorkout = false;
      final ios = AppleHealthActivitySource(gateway: gateway, isIOS: true);
      await expectLater(
        ios.listEligibleActivities(from: from, to: to),
        throwsA(isA<ActivityPermissionDenied>()),
      );
      expect(gateway.queries, isEmpty);
      final android = AppleHealthActivitySource(gateway: gateway, isIOS: false);
      await expectLater(
        android.listEligibleActivities(from: from, to: to),
        throwsA(isA<ActivitySourceUnavailable>()),
      );
    },
  );

  test(
    'route denial does not return samples or alter the selected record',
    () async {
      final gateway = _Gateway()
        ..allowRoute = false
        ..workouts = [
          _point(
            id: 'chosen',
            type: HealthDataType.WORKOUT,
            value: WorkoutHealthValue(
              workoutActivityType: HealthWorkoutActivityType.RUNNING,
              totalDistance: 5000,
              totalDistanceUnit: HealthDataUnit.METER,
            ),
          ),
        ];
      final source = AppleHealthActivitySource(gateway: gateway, isIOS: true);
      final selected = (await source.listEligibleActivities(
        from: from,
        to: to,
      )).single;
      await expectLater(
        source.readPreciseRoute(selected),
        throwsA(isA<ActivityPermissionDenied>()),
      );
      expect(selected.preciseRoute, isNull);
      expect(gateway.queries, [HealthDataType.WORKOUT]);
    },
  );
}
