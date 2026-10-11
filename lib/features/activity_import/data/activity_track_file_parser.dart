import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../../secure_route/domain/route_models.dart';
import '../domain/activity_record.dart';
import 'gpx_track_parser.dart';

final class ActivityFilePayload {
  const ActivityFilePayload({required this.bytes, required this.extension});

  final Uint8List bytes;
  final String extension;
}

/// Dispatches only supported, user-selected local track formats. The source
/// filename is deliberately not retained in the parsed record.
final class ActivityTrackFileParser {
  const ActivityTrackFileParser();

  List<ParsedGpxTrack> parse(
    Uint8List bytes, {
    required String extension,
    required ActivityKind kind,
  }) => switch (extension.toLowerCase()) {
    'gpx' => const GpxTrackParser().parse(bytes, kind: kind),
    'tcx' => const TcxTrackParser().parse(bytes, kind: kind),
    'kml' => const KmlTrackParser().parse(bytes, kind: kind),
    _ => throw const FormatException('Unsupported activity file format'),
  };
}

final class TcxTrackParser {
  const TcxTrackParser();

  static const _namespace =
      'http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2';

  List<ParsedGpxTrack> parse(Uint8List bytes, {required ActivityKind kind}) {
    final document = _parseXml(bytes);
    final root = document.rootElement;
    if (root.name.local != 'TrainingCenterDatabase' ||
        root.name.namespaceUri != _namespace) {
      throw const FormatException('Unsupported TCX format');
    }

    final activities = root.descendants
        .whereType<XmlElement>()
        .where(
          (element) =>
              element.name.local == 'Activity' &&
              element.name.namespaceUri == _namespace,
        )
        .toList(growable: false);
    final parsed = <ParsedGpxTrack>[];
    var totalPoints = 0;
    for (final activity in activities) {
      final trackElements = activity.descendants
          .whereType<XmlElement>()
          .where(
            (element) =>
                element.name.local == 'Track' &&
                element.name.namespaceUri == _namespace,
          )
          .toList(growable: false);
      final tracks = <List<_TimedPoint>>[];
      final allPoints = <_TimedPoint>[];
      final heartRates = <int>[];
      for (final track in trackElements) {
        final points = <_TimedPoint>[];
        for (final point in track.findElements(
          'Trackpoint',
          namespace: _namespace,
        )) {
          totalPoints++;
          if (totalPoints > GpxTrackParser.maxTrackPoints) {
            throw const FormatException('TCX contains too many points');
          }
          final timeText = _childText(point, 'Time', _namespace);
          if (timeText == null) {
            throw const FormatException('TCX point has no time');
          }
          final timestamp = _parseTimedDate(timeText);
          final position = point
              .findElements('Position', namespace: _namespace)
              .firstOrNull;
          RouteCoordinate? coordinate;
          if (position != null) {
            final latitudeText = _childText(
              position,
              'LatitudeDegrees',
              _namespace,
            );
            final longitudeText = _childText(
              position,
              'LongitudeDegrees',
              _namespace,
            );
            if ((latitudeText == null) != (longitudeText == null)) {
              throw const FormatException('TCX position is incomplete');
            }
            if (latitudeText != null && longitudeText != null) {
              coordinate = _coordinate(latitudeText, longitudeText);
            }
          }
          final distance = double.tryParse(
            _childText(point, 'DistanceMeters', _namespace) ?? '',
          );
          final heartRateText = _childText(
            point
                .findElements('HeartRateBpm', namespace: _namespace)
                .firstOrNull,
            'Value',
            _namespace,
          );
          final heartRate = int.tryParse(heartRateText ?? '');
          if (heartRate != null && heartRate >= 30 && heartRate <= 240) {
            heartRates.add(heartRate);
          }
          final parsedPoint = _TimedPoint(
            timestamp: timestamp,
            timeText: timeText,
            coordinate: coordinate,
            cumulativeDistanceMeters: distance,
          );
          points.add(parsedPoint);
          allPoints.add(parsedPoint);
        }
        if (points.isNotEmpty) tracks.add(points);
      }

      final laps = activity.findElements('Lap', namespace: _namespace).toList();
      if (allPoints.isEmpty && laps.isEmpty) continue;
      final lapDistance = laps
          .map(
            (lap) => double.tryParse(
              _childText(lap, 'DistanceMeters', _namespace) ?? '',
            ),
          )
          .whereType<double>()
          .fold<double?>(
            null,
            (current, value) => math.max(current ?? 0, value),
          );
      final cumulativeDistance = allPoints
          .map((point) => point.cumulativeDistanceMeters)
          .whereType<double>()
          .fold<double?>(
            null,
            (current, value) => math.max(current ?? 0, value),
          );
      final routeDistance = _distanceForTracks(tracks);
      final distance = lapDistance ?? cumulativeDistance ?? routeDistance;

      final firstPoint = allPoints.firstOrNull;
      final lastPoint = allPoints.lastOrNull;
      final startText =
          firstPoint?.timeText ??
          laps
              .map((lap) => lap.getAttribute('StartTime'))
              .whereType<String>()
              .firstOrNull ??
          _childText(activity, 'Id', _namespace);
      if (startText == null) {
        throw const FormatException('TCX activity has no start time');
      }
      final startedAt = _parseTimedDate(startText);
      final endTime = lastPoint?.timestamp;
      final lapDuration = laps
          .map(
            (lap) => double.tryParse(
              _childText(lap, 'TotalTimeSeconds', _namespace) ?? '',
            ),
          )
          .whereType<double>()
          .fold<double>(0, (sum, value) => sum + value);
      final duration = endTime != null && allPoints.length >= 2
          ? endTime.difference(startedAt).inSeconds
          : lapDuration.round();
      if (distance == null ||
          !distance.isFinite ||
          distance < 1 ||
          distance > 1000000 ||
          duration < 1 ||
          duration > 1000000) {
        throw const FormatException(
          'TCX activity metrics are unavailable or out of range',
        );
      }
      final record = _record(
        idPrefix: 'tcx',
        index: parsed.length,
        kind: kind,
        startedAt: startedAt,
        startTimeText: startText,
        distanceMeters: distance,
        durationSeconds: duration,
        sourceLabel: 'TCX 文件（运动类型手选）',
        heartRates: heartRates,
      );
      parsed.add(
        ParsedGpxTrack(
          record: record,
          route:
              tracks.length == 1 &&
                  tracks.single.length >= 2 &&
                  tracks.single.every((point) => point.coordinate != null)
              ? List.unmodifiable(
                  tracks.single.map((point) => point.coordinate!),
                )
              : null,
        ),
      );
    }
    if (parsed.isEmpty) throw const FormatException('No usable TCX activity');
    return List.unmodifiable(parsed);
  }
}

final class KmlTrackParser {
  const KmlTrackParser();

  static const _kmlNamespace = 'http://www.opengis.net/kml/2.2';
  static const _gxNamespace = 'http://www.google.com/kml/ext/2.2';

  List<ParsedGpxTrack> parse(Uint8List bytes, {required ActivityKind kind}) {
    final document = _parseXml(bytes);
    final root = document.rootElement;
    if (root.name.local != 'kml' || root.name.namespaceUri != _kmlNamespace) {
      throw const FormatException('Unsupported KML format');
    }
    final tracks = root.descendants
        .whereType<XmlElement>()
        .where(
          (element) =>
              element.name.local == 'Track' &&
              element.name.namespaceUri == _gxNamespace,
        )
        .toList(growable: false);
    if (tracks.isEmpty) {
      throw const FormatException(
        'KML route has no per-point timestamps; use GPX or TCX',
      );
    }

    final parsed = <ParsedGpxTrack>[];
    var totalPoints = 0;
    for (final track in tracks) {
      final times = <String>[];
      final coordinateTexts = <String>[];
      for (final child in track.children.whereType<XmlElement>()) {
        if (child.name.local == 'when' &&
            child.name.namespaceUri == _kmlNamespace) {
          times.add(child.innerText.trim());
        } else if (child.name.local == 'coord' &&
            child.name.namespaceUri == _gxNamespace) {
          coordinateTexts.add(child.innerText.trim());
        }
      }
      totalPoints += times.length;
      if (totalPoints > GpxTrackParser.maxTrackPoints) {
        throw const FormatException('KML contains too many points');
      }
      if (times.length != coordinateTexts.length || times.length < 2) {
        throw const FormatException(
          'KML track time and coordinate arrays do not match',
        );
      }
      final points = <_TimedPoint>[];
      for (var index = 0; index < times.length; index++) {
        final values = coordinateTexts[index].split(RegExp(r'\s+'));
        if (values.length < 2) {
          throw const FormatException('KML coordinate is missing');
        }
        // gx:coord uses longitude, latitude, altitude, like KML coordinates;
        // its values are space-separated rather than comma-separated.
        final coordinate = _coordinate(values[1], values[0]);
        final timestamp = _parseTimedDate(times[index]);
        if (points.isNotEmpty && timestamp.isBefore(points.last.timestamp)) {
          throw const FormatException('KML track times are out of order');
        }
        points.add(
          _TimedPoint(
            timestamp: timestamp,
            timeText: times[index],
            coordinate: coordinate,
          ),
        );
      }
      final startedAt = points.first.timestamp;
      final duration = points.last.timestamp.difference(startedAt).inSeconds;
      final distance = _distanceForTracks([points]);
      if (duration < 1 ||
          duration > 1000000 ||
          distance == null ||
          !distance.isFinite ||
          distance < 1 ||
          distance > 1000000) {
        throw const FormatException('KML activity metrics are out of range');
      }
      parsed.add(
        ParsedGpxTrack(
          record: _record(
            idPrefix: 'kml',
            index: parsed.length,
            kind: kind,
            startedAt: startedAt,
            startTimeText: times.first,
            distanceMeters: distance,
            durationSeconds: duration,
            sourceLabel: 'KML 文件（运动类型手选）',
            heartRates: const [],
          ),
          route: List.unmodifiable(points.map((point) => point.coordinate!)),
        ),
      );
    }
    return List.unmodifiable(parsed);
  }
}

XmlDocument _parseXml(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > GpxTrackParser.maxFileBytes) {
    throw const FormatException('Activity file size is unsupported');
  }
  final xmlText = utf8.decode(bytes).replaceFirst('\uFEFF', '');
  if (RegExp(
    r'<!\s*(?:DOCTYPE|ENTITY)',
    caseSensitive: false,
  ).hasMatch(xmlText)) {
    throw const FormatException('XML declarations are unsupported');
  }
  try {
    return XmlDocument.parse(xmlText);
  } on XmlException {
    throw const FormatException('Invalid activity XML');
  }
}

String? _childText(XmlElement? parent, String name, String namespace) {
  if (parent == null) return null;
  for (final child in parent.children.whereType<XmlElement>()) {
    if (child.name.local == name && child.name.namespaceUri == namespace) {
      final value = child.innerText.trim();
      return value.isEmpty ? null : value;
    }
  }
  return null;
}

DateTime _parseTimedDate(String value) {
  final timestamp = DateTime.tryParse(value);
  if (timestamp == null ||
      !RegExp(
        r'(?:Z|[+-]\d{2}:\d{2})$',
        caseSensitive: false,
      ).hasMatch(value)) {
    throw const FormatException('Trackpoint time needs an explicit time zone');
  }
  return timestamp;
}

RouteCoordinate _coordinate(String latitudeText, String longitudeText) {
  final latitude = double.tryParse(latitudeText);
  final longitude = double.tryParse(longitudeText);
  if (latitude == null || longitude == null) {
    throw const FormatException('Trackpoint has invalid coordinates');
  }
  final point = RouteCoordinate(latitude: latitude, longitude: longitude);
  if (!point.isValid) {
    throw const FormatException('Trackpoint is outside Earth coordinates');
  }
  return point;
}

ActivityRecord _record({
  required String idPrefix,
  required int index,
  required ActivityKind kind,
  required DateTime startedAt,
  required String startTimeText,
  required double distanceMeters,
  required int durationSeconds,
  required String sourceLabel,
  required List<int> heartRates,
}) {
  final offsetMinutes = _offsetMinutes(startTimeText);
  final record = ActivityRecord(
    id: '$idPrefix:${startedAt.microsecondsSinceEpoch}:$index',
    source: idPrefix == 'gpx'
        ? ActivitySourceKind.gpxFile
        : ActivitySourceKind.fileImport,
    kind: kind,
    startedAt: startedAt,
    utcOffsetMinutes: offsetMinutes,
    distanceMeters: distanceMeters,
    durationSeconds: durationSeconds,
    sourceLabel: sourceLabel,
    averageHeartRateBpm: heartRates.isEmpty
        ? null
        : (heartRates.reduce((sum, value) => sum + value) / heartRates.length)
              .round(),
    correctedFields: const {'activity_type'},
  );
  if (ActivityMetrics.paceSecondsPerKm(record) > 36000) {
    throw const FormatException('Track pace is out of range');
  }
  return record;
}

int _offsetMinutes(String value) {
  if (value.endsWith('Z') || value.endsWith('z')) return 0;
  final match = RegExp(r'([+-])(\d{2}):(\d{2})$').firstMatch(value);
  if (match == null) throw const FormatException('Invalid track time zone');
  final hours = int.parse(match.group(2)!);
  final minutes = int.parse(match.group(3)!);
  final total = hours * 60 + minutes;
  if (hours > 14 || minutes > 59 || total > 14 * 60) {
    throw const FormatException('Invalid track time zone');
  }
  return match.group(1) == '-' ? -total : total;
}

double? _distanceForTracks(List<List<_TimedPoint>> tracks) {
  var total = 0.0;
  var hasSegment = false;
  for (final points in tracks) {
    RouteCoordinate? previous;
    for (final point in points) {
      final coordinate = point.coordinate;
      if (coordinate == null) {
        previous = null;
        continue;
      }
      if (previous != null) total += _meters(previous, coordinate);
      previous = coordinate;
    }
    if (points.length >= 2) hasSegment = true;
  }
  return hasSegment ? total : null;
}

double _meters(RouteCoordinate a, RouteCoordinate b) {
  const earthRadiusMeters = 6371000.0;
  final lat1 = a.latitude * math.pi / 180;
  final lat2 = b.latitude * math.pi / 180;
  final deltaLat = (b.latitude - a.latitude) * math.pi / 180;
  final deltaLon = (b.longitude - a.longitude) * math.pi / 180;
  final halfChord =
      math.pow(math.sin(deltaLat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(deltaLon / 2), 2);
  return 2 *
      earthRadiusMeters *
      math.asin(math.min(1, math.sqrt(halfChord.toDouble())));
}

final class _TimedPoint {
  const _TimedPoint({
    required this.timestamp,
    required this.timeText,
    required this.coordinate,
    this.cumulativeDistanceMeters,
  });

  final DateTime timestamp;
  final String timeText;
  final RouteCoordinate? coordinate;
  final double? cumulativeDistanceMeters;
}
