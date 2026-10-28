import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/activity_import/data/health_connect_activity_source.dart';
import 'package:squadly/features/activity_import/domain/activity_record.dart';
import 'package:squadly/features/activity_import/domain/activity_source.dart';

final class _Gateway implements HealthConnectGateway {
  bool available = true;
  final requests = <({DateTime from, DateTime to})>[];
  List<HealthConnectWorkout> workouts = [];
  Object? error;

  @override
  Future<bool> get isAvailable async => available;

  @override
  Future<List<HealthConnectWorkout>> readWorkouts(
    DateTime from,
    DateTime to,
  ) async {
    requests.add((from: from, to: to));
    if (error case final Object value) throw value;
    return workouts;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('method channel decodes only workout summary fields', () async {
    const channel = MethodChannel('squadly/health_connect');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'isAvailable') return true;
          if (call.method == 'readWorkouts') {
            return [
              {
                'id': 'hc-1',
                'kind': 'run',
                'startedAtMillis': 1792214400000,
                'endedAtMillis': 1792216200000,
                'distanceMeters': 5000.0,
              },
            ];
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final gateway = MethodChannelHealthConnectGateway(channel: channel);
    expect(await gateway.isAvailable, isTrue);
    final workouts = await gateway.readWorkouts(
      DateTime(2026, 10, 17),
      DateTime(2026, 10, 18),
    );
    expect(workouts.single.id, 'hc-1');
    expect(workouts.single.kind, ActivityKind.run);
    expect(workouts.single.distanceMeters, 5000);
  });

  test('method channel maps permission denial without swallowing it', () async {
    const channel = MethodChannel('squadly/health_connect');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'isAvailable') return true;
          throw PlatformException(code: 'permission_denied');
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final source = HealthConnectActivitySource(
      gateway: MethodChannelHealthConnectGateway(channel: channel),
      isAndroid: true,
    );
    final now = DateTime.now();
    await expectLater(
      source.listEligibleActivities(
        from: now.subtract(const Duration(days: 1)),
        to: now,
      ),
      throwsA(isA<ActivityPermissionDenied>()),
    );
  });

  test(
    'reads at most 30 days and lists only in-memory selected workouts',
    () async {
      final now = DateTime.now();
      final gateway = _Gateway()
        ..workouts = [
          HealthConnectWorkout(
            id: 'oldest',
            kind: ActivityKind.hike,
            startedAt: now.subtract(const Duration(days: 10)),
            endedAt: now.subtract(const Duration(days: 10, minutes: -30)),
            distanceMeters: 4500,
          ),
          HealthConnectWorkout(
            id: 'newest',
            kind: ActivityKind.run,
            startedAt: now.subtract(const Duration(days: 2)),
            endedAt: now.subtract(const Duration(days: 2, minutes: -25)),
            distanceMeters: 5000,
          ),
        ];
      final source = HealthConnectActivitySource(
        gateway: gateway,
        isAndroid: true,
      );

      final records = await source.listEligibleActivities(
        from: now.subtract(const Duration(days: 90)),
        to: now.add(const Duration(days: 5)),
      );

      expect(
        gateway.requests.single.from
            .difference(now.subtract(const Duration(days: 30)))
            .inMilliseconds
            .abs(),
        lessThan(50),
      );
      expect(
        gateway.requests.single.to.difference(now).inMilliseconds.abs(),
        lessThan(50),
      );
      expect(records.map((record) => record.id), ['newest', 'oldest']);
      expect(records.first.source, ActivitySourceKind.healthConnect);
      expect(records.first.sourceLabel, 'Health Connect');
      expect(await source.readActivity('newest'), records.first);
      await expectLater(
        source.readActivity('not-listed'),
        throwsA(isA<ActivityNotFound>()),
      );
    },
  );

  test(
    'does not access Health Connect outside Android or when unavailable',
    () async {
      final gateway = _Gateway();
      final source = HealthConnectActivitySource(
        gateway: gateway,
        isAndroid: false,
      );
      await expectLater(
        source.listEligibleActivities(
          from: DateTime(2026),
          to: DateTime(2026, 1, 2),
        ),
        throwsA(isA<ActivitySourceUnavailable>()),
      );
      expect(gateway.requests, isEmpty);

      final unavailable = _Gateway()..available = false;
      await expectLater(
        HealthConnectActivitySource(
          gateway: unavailable,
          isAndroid: true,
        ).listEligibleActivities(
          from: DateTime(2026),
          to: DateTime(2026, 1, 2),
        ),
        throwsA(isA<ActivitySourceUnavailable>()),
      );
    },
  );

  test('preserves permission denial and does not expose route data', () async {
    final now = DateTime.now();
    final gateway = _Gateway()..error = const ActivityPermissionDenied();
    final source = HealthConnectActivitySource(
      gateway: gateway,
      isAndroid: true,
    );
    await expectLater(
      source.listEligibleActivities(
        from: now.subtract(const Duration(days: 1)),
        to: now,
      ),
      throwsA(isA<ActivityPermissionDenied>()),
    );
    final routeGateway = _Gateway()
      ..workouts = [
        HealthConnectWorkout(
          id: 'id',
          kind: ActivityKind.run,
          startedAt: now.subtract(const Duration(hours: 2)),
          endedAt: now.subtract(const Duration(minutes: 90)),
          distanceMeters: 1000,
        ),
      ];
    final routeSource = HealthConnectActivitySource(
      gateway: routeGateway,
      isAndroid: true,
    );
    final selected = (await routeSource.listEligibleActivities(
      from: now.subtract(const Duration(days: 1)),
      to: now,
    )).single;
    await expectLater(
      routeSource.readPreciseRoute(selected),
      throwsA(isA<ActivitySourceUnavailable>()),
    );
  });
}
