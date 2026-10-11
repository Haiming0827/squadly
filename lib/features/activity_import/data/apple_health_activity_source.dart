import 'dart:io' show Platform;

import 'package:health/health.dart';

import '../../secure_route/domain/route_models.dart';
import '../domain/activity_record.dart';
import '../domain/activity_source.dart';

/// Keeps the native plugin behind a seam so permission and mapping paths can
/// be tested without a health account or a real device.
abstract interface class AppleHealthGateway {
  Future<void> configure();
  Future<bool> requestRead(HealthDataType type);
  Future<List<HealthDataPoint>> read(
    HealthDataType type,
    DateTime from,
    DateTime to,
  );
}

final class PluginAppleHealthGateway implements AppleHealthGateway {
  PluginAppleHealthGateway() : _health = Health();

  final Health _health;

  @override
  Future<void> configure() => _health.configure();

  @override
  Future<bool> requestRead(HealthDataType type) => _health.requestAuthorization(
    [type],
    permissions: [HealthDataAccess.READ],
  );

  @override
  Future<List<HealthDataPoint>> read(
    HealthDataType type,
    DateTime from,
    DateTime to,
  ) => _health.getHealthDataFromTypes(
    types: [type],
    startTime: from,
    endTime: to,
  );
}

/// Raw HealthKit objects are never persisted or sent to the backend.
final class AppleHealthActivitySource implements ActivitySource {
  AppleHealthActivitySource({AppleHealthGateway? gateway, bool? isIOS})
    : _gateway = gateway ?? PluginAppleHealthGateway(),
      _isIOS = isIOS ?? Platform.isIOS;

  final AppleHealthGateway _gateway;
  final bool _isIOS;
  final _listed = <String, ActivityRecord>{};

  @override
  Future<List<ActivityRecord>> listEligibleActivities({
    required DateTime from,
    required DateTime to,
  }) async {
    if (!_isIOS) throw const ActivitySourceUnavailable();
    if (!from.isBefore(to)) throw ArgumentError('Invalid workout date range');
    await _gateway.configure();
    if (!await _gateway.requestRead(HealthDataType.WORKOUT)) {
      throw const ActivityPermissionDenied();
    }
    final points = await _gateway.read(HealthDataType.WORKOUT, from, to);
    final records = <ActivityRecord>[];
    for (final point in points) {
      final record = _mapWorkout(point);
      if (record != null) records.add(record);
    }
    records.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    _listed
      ..clear()
      ..addEntries(records.map((record) => MapEntry(record.id, record)));
    return List.unmodifiable(records);
  }

  @override
  Future<ActivityRecord> readActivity(String id) async {
    final record = _listed[id];
    if (record == null) throw const ActivityNotFound();
    return record;
  }

  @override
  Future<ActivityRecord> readPreciseRoute(ActivityRecord selected) async {
    if (!_isIOS) throw const ActivitySourceUnavailable();
    if (_listed[selected.id] == null ||
        selected.source != ActivitySourceKind.appleHealth) {
      throw const ActivityNotFound();
    }
    // A separate prompt follows the explicit selection of one workout.
    if (!await _gateway.requestRead(HealthDataType.WORKOUT_ROUTE)) {
      throw const ActivityPermissionDenied();
    }
    final end = selected.startedAt.add(
      Duration(seconds: selected.durationSeconds),
    );
    final routes = await _gateway.read(
      HealthDataType.WORKOUT_ROUTE,
      selected.startedAt.subtract(const Duration(minutes: 1)),
      end.add(const Duration(minutes: 1)),
    );
    final coordinates = <RouteCoordinate>[];
    for (final point in routes) {
      if (point.value case final WorkoutRouteHealthValue route
          when route.workoutUuid == selected.id) {
        for (final sample in route.locations) {
          final coordinate = RouteCoordinate(
            latitude: sample.latitude,
            longitude: sample.longitude,
          );
          if (coordinate.isValid) coordinates.add(coordinate);
        }
      }
    }
    return selected.copyWith(preciseRoute: List.unmodifiable(coordinates));
  }

  ActivityRecord? _mapWorkout(HealthDataPoint point) {
    if (point.type != HealthDataType.WORKOUT ||
        point.sourcePlatform != HealthPlatformType.appleHealth ||
        point.value is! WorkoutHealthValue) {
      return null;
    }
    final workout = point.value as WorkoutHealthValue;
    final kind = switch (workout.workoutActivityType) {
      HealthWorkoutActivityType.RUNNING ||
      HealthWorkoutActivityType.RUNNING_TREADMILL => ActivityKind.run,
      HealthWorkoutActivityType.HIKING => ActivityKind.hike,
      _ => null,
    };
    if (kind == null) return null;
    final distance = _meters(workout.totalDistance, workout.totalDistanceUnit);
    final duration = point.dateTo.difference(point.dateFrom).inSeconds;
    if (distance == null ||
        distance <= 0 ||
        duration <= 0 ||
        point.uuid.isEmpty) {
      return null;
    }
    return ActivityRecord(
      id: point.uuid,
      source: ActivitySourceKind.appleHealth,
      kind: kind,
      startedAt: point.dateFrom,
      utcOffsetMinutes: point.dateFrom.timeZoneOffset.inMinutes,
      distanceMeters: distance,
      durationSeconds: duration,
      sourceLabel: point.sourceName.isEmpty ? 'Apple 健康' : point.sourceName,
    );
  }

  static double? _meters(int? amount, HealthDataUnit? unit) {
    if (amount == null || unit == null) return null;
    return switch (unit) {
      HealthDataUnit.METER => amount.toDouble(),
      HealthDataUnit.CENTIMETER => amount / 100,
      HealthDataUnit.FOOT => amount * 0.3048,
      HealthDataUnit.YARD => amount * 0.9144,
      HealthDataUnit.MILE => amount * 1609.344,
      _ => null,
    };
  }
}
