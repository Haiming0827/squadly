import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../domain/activity_record.dart';
import '../domain/activity_source.dart';

final class HealthConnectWorkout {
  const HealthConnectWorkout({
    required this.id,
    required this.kind,
    required this.startedAt,
    required this.endedAt,
    required this.distanceMeters,
  });

  final String id;
  final ActivityKind kind;
  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceMeters;
}

abstract interface class HealthConnectGateway {
  Future<bool> get isAvailable;
  Future<List<HealthConnectWorkout>> readWorkouts(DateTime from, DateTime to);
}

final class MethodChannelHealthConnectGateway implements HealthConnectGateway {
  MethodChannelHealthConnectGateway({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('squadly/health_connect');

  final MethodChannel _channel;

  @override
  Future<bool> get isAvailable async =>
      await _channel.invokeMethod<bool>('isAvailable') ?? false;

  @override
  Future<List<HealthConnectWorkout>> readWorkouts(
    DateTime from,
    DateTime to,
  ) async {
    try {
      final rows = await _channel.invokeListMethod<Object?>('readWorkouts', {
        'fromMillis': from.millisecondsSinceEpoch,
        'toMillis': to.millisecondsSinceEpoch,
      });
      return [
        for (final row in rows ?? const <Object?>[])
          if (row is Map<Object?, Object?>) _mapWorkout(row),
      ];
    } on PlatformException catch (error) {
      if (error.code == 'permission_denied') {
        throw const ActivityPermissionDenied();
      }
      if (error.code == 'unavailable') throw const ActivitySourceUnavailable();
      rethrow;
    }
  }

  HealthConnectWorkout _mapWorkout(Map<Object?, Object?> row) {
    final kind = switch (row['kind']) {
      'run' => ActivityKind.run,
      'hike' => ActivityKind.hike,
      _ => throw const FormatException('Unsupported Health Connect activity'),
    };
    final startedAt = DateTime.fromMillisecondsSinceEpoch(
      row['startedAtMillis']! as int,
    );
    final endedAt = DateTime.fromMillisecondsSinceEpoch(
      row['endedAtMillis']! as int,
    );
    final distanceMeters = (row['distanceMeters']! as num).toDouble();
    final id = row['id']! as String;
    if (id.isEmpty ||
        !startedAt.isBefore(endedAt) ||
        !distanceMeters.isFinite ||
        distanceMeters <= 0) {
      throw const FormatException('Invalid Health Connect activity');
    }
    return HealthConnectWorkout(
      id: id,
      kind: kind,
      startedAt: startedAt,
      endedAt: endedAt,
      distanceMeters: distanceMeters,
    );
  }
}

final class HealthConnectActivitySource implements ActivitySource {
  HealthConnectActivitySource({HealthConnectGateway? gateway, bool? isAndroid})
    : _gateway = gateway ?? MethodChannelHealthConnectGateway(),
      _isAndroid = isAndroid ?? Platform.isAndroid;

  final HealthConnectGateway _gateway;
  final bool _isAndroid;
  final _listed = <String, ActivityRecord>{};

  @override
  Future<List<ActivityRecord>> listEligibleActivities({
    required DateTime from,
    required DateTime to,
  }) async {
    if (!_isAndroid || !await _gateway.isAvailable) {
      throw const ActivitySourceUnavailable();
    }
    if (!from.isBefore(to)) throw ArgumentError('Invalid workout date range');
    final now = DateTime.now();
    final earliest = now.subtract(const Duration(days: 30));
    final boundedFrom = from.isBefore(earliest) ? earliest : from;
    final boundedTo = to.isAfter(now) ? now : to;
    if (!boundedFrom.isBefore(boundedTo)) return const [];

    final workouts = await _gateway.readWorkouts(boundedFrom, boundedTo);
    final records = [
      for (final workout in workouts)
        if (workout.startedAt.isBefore(workout.endedAt) &&
            workout.distanceMeters.isFinite &&
            workout.distanceMeters > 0 &&
            workout.id.isNotEmpty)
          ActivityRecord(
            id: workout.id,
            source: ActivitySourceKind.healthConnect,
            kind: workout.kind,
            startedAt: workout.startedAt,
            utcOffsetMinutes: workout.startedAt.timeZoneOffset.inMinutes,
            distanceMeters: workout.distanceMeters,
            durationSeconds: workout.endedAt
                .difference(workout.startedAt)
                .inSeconds,
            sourceLabel: 'Health Connect',
          ),
    ];
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
    if (!_isAndroid || selected.source != ActivitySourceKind.healthConnect) {
      throw const ActivitySourceUnavailable();
    }
    if (_listed[selected.id] == null) throw const ActivityNotFound();
    throw const ActivitySourceUnavailable();
  }
}
