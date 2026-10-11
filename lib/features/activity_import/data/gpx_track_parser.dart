import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../../secure_route/domain/route_models.dart';
import '../domain/activity_record.dart';

final class ParsedGpxTrack {
  const ParsedGpxTrack({required this.record, required this.route});

  final ActivityRecord record;
  final List<RouteCoordinate>? route;
}

/// Bounded GPX 1.0/1.1 track parser. This never reads from the network or
/// persists source bytes; callers hold its private coordinates locally.
final class GpxTrackParser {
  const GpxTrackParser();

  static const maxFileBytes = 5 * 1024 * 1024;
  static const maxTrackPoints = 5000;
  static const _namespaces = {
    'http://www.topografix.com/GPX/1/1',
    'http://www.topografix.com/GPX/1/0',
  };

  List<ParsedGpxTrack> parse(Uint8List bytes, {required ActivityKind kind}) {
    if (bytes.isEmpty || bytes.length > maxFileBytes) {
      throw const FormatException('GPX file size is unsupported');
    }
    final xmlText = utf8.decode(bytes).replaceFirst('\uFEFF', '');
    if (RegExp(
      r'<!\s*(?:DOCTYPE|ENTITY)',
      caseSensitive: false,
    ).hasMatch(xmlText)) {
      throw const FormatException('GPX declarations are unsupported');
    }
    final XmlDocument document;
    try {
      document = XmlDocument.parse(xmlText);
    } on XmlException {
      throw const FormatException('Invalid GPX XML');
    }
    final root = document.rootElement;
    final namespace = root.name.namespaceUri;
    if (root.name.local != 'gpx' || !_namespaces.contains(namespace)) {
      throw const FormatException('Unsupported GPX version');
    }

    final result = <ParsedGpxTrack>[];
    var totalPoints = 0;
    for (final track in root.findElements('trk', namespace: namespace)) {
      final coordinates = <RouteCoordinate>[];
      DateTime? firstTime;
      DateTime? lastTime;
      var firstOffsetMinutes = 0;
      var distanceMeters = 0.0;
      var nonEmptySegments = 0;
      final heartRates = <int>[];
      for (final segment in track.findElements(
        'trkseg',
        namespace: namespace,
      )) {
        RouteCoordinate? previous;
        var segmentPoints = 0;
        for (final point in segment.findElements(
          'trkpt',
          namespace: namespace,
        )) {
          segmentPoints++;
          totalPoints++;
          if (totalPoints > maxTrackPoints) {
            throw const FormatException('GPX contains too many points');
          }
          final latitude = double.tryParse(point.getAttribute('lat') ?? '');
          final longitude = double.tryParse(point.getAttribute('lon') ?? '');
          if (latitude == null || longitude == null) {
            throw const FormatException('GPX point has no coordinates');
          }
          final coordinate = RouteCoordinate(
            latitude: latitude,
            longitude: longitude,
          );
          if (!coordinate.isValid) {
            throw const FormatException(
              'GPX point is outside Earth coordinates',
            );
          }
          final timeText = point
              .findElements('time', namespace: namespace)
              .firstOrNull
              ?.innerText
              .trim();
          final timestamp = timeText == null
              ? null
              : DateTime.tryParse(timeText);
          if (timestamp == null ||
              !RegExp(
                r'(?:Z|[+-]\d{2}:\d{2})$',
                caseSensitive: false,
              ).hasMatch(timeText!)) {
            throw const FormatException('GPX point needs a dated time zone');
          }
          for (final element in point.descendants.whereType<XmlElement>()) {
            if (element.name.local.toLowerCase() != 'hr') continue;
            final heartRate = int.tryParse(element.innerText.trim());
            if (heartRate != null && heartRate >= 30 && heartRate <= 240) {
              heartRates.add(heartRate);
            }
          }
          if (lastTime != null && timestamp.isBefore(lastTime)) {
            throw const FormatException('GPX point times are out of order');
          }
          firstTime ??= timestamp;
          if (coordinates.isEmpty) {
            firstOffsetMinutes = _offsetMinutes(timeText);
          }
          lastTime = timestamp;
          if (previous != null) distanceMeters += _meters(previous, coordinate);
          previous = coordinate;
          coordinates.add(coordinate);
        }
        if (segmentPoints > 0) nonEmptySegments++;
      }
      if (coordinates.isEmpty) continue;
      if (coordinates.length < 2 || firstTime == null || lastTime == null) {
        throw const FormatException('GPX track needs at least two points');
      }
      final durationSeconds = lastTime.difference(firstTime).inSeconds;
      if (!distanceMeters.isFinite ||
          distanceMeters < 1 ||
          distanceMeters > 1000000 ||
          durationSeconds < 1 ||
          durationSeconds > 1000000) {
        throw const FormatException('GPX track metrics are out of range');
      }
      final record = ActivityRecord(
        id: 'gpx:${firstTime.microsecondsSinceEpoch}:${result.length}',
        source: ActivitySourceKind.gpxFile,
        kind: kind,
        startedAt: firstTime,
        utcOffsetMinutes: firstOffsetMinutes,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        sourceLabel: 'GPX 文件（运动类型手选）',
        averageHeartRateBpm: heartRates.isEmpty
            ? null
            : (heartRates.reduce((sum, value) => sum + value) /
                      heartRates.length)
                  .round(),
        correctedFields: const {'activity_type'},
      );
      if (ActivityMetrics.paceSecondsPerKm(record) > 36000) {
        throw const FormatException('GPX track pace is out of range');
      }
      result.add(
        ParsedGpxTrack(
          record: record,
          route: nonEmptySegments == 1
              ? List<RouteCoordinate>.unmodifiable(coordinates)
              : null,
        ),
      );
    }
    if (result.isEmpty) {
      throw const FormatException('No GPX track with timed points');
    }
    return List<ParsedGpxTrack>.unmodifiable(result);
  }

  static int _offsetMinutes(String time) {
    if (time.endsWith('Z') || time.endsWith('z')) return 0;
    final match = RegExp(r'([+-])(\d{2}):(\d{2})$').firstMatch(time);
    if (match == null) throw const FormatException('Invalid GPX time zone');
    final hours = int.parse(match.group(2)!);
    final minutes = int.parse(match.group(3)!);
    final total = hours * 60 + minutes;
    if (hours > 14 || minutes > 59 || total > 14 * 60) {
      throw const FormatException('Invalid GPX time zone');
    }
    return match.group(1) == '-' ? -total : total;
  }

  static double _meters(RouteCoordinate a, RouteCoordinate b) {
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
}
