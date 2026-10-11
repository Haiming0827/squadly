import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/activity_import/data/activity_track_file_parser.dart';
import 'package:squadly/features/activity_import/data/gpx_activity_source.dart';
import 'package:squadly/features/activity_import/domain/activity_record.dart';

const _tcx = '''<?xml version="1.0" encoding="UTF-8"?>
<TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">
  <Activities><Activity Sport="Running"><Id>2026-10-08T06:00:00+08:00</Id>
    <Lap StartTime="2026-10-08T06:00:00+08:00">
      <TotalTimeSeconds>600</TotalTimeSeconds><DistanceMeters>111</DistanceMeters>
      <Track><Trackpoint><Time>2026-10-08T06:00:00+08:00</Time>
        <Position><LatitudeDegrees>31</LatitudeDegrees><LongitudeDegrees>121</LongitudeDegrees></Position>
        <DistanceMeters>0</DistanceMeters><HeartRateBpm><Value>120</Value></HeartRateBpm>
      </Trackpoint><Trackpoint><Time>2026-10-08T06:10:00+08:00</Time>
        <Position><LatitudeDegrees>31.001</LatitudeDegrees><LongitudeDegrees>121</LongitudeDegrees></Position>
        <DistanceMeters>111</DistanceMeters><HeartRateBpm><Value>140</Value></HeartRateBpm>
      </Trackpoint></Track>
    </Lap>
  </Activity></Activities>
</TrainingCenterDatabase>''';

const _kmlTrack = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document><Placemark><gx:Track>
    <when>2026-10-08T06:00:00+08:00</when>
    <when>2026-10-08T06:10:00+08:00</when>
    <gx:coord>121 31 0</gx:coord><gx:coord>121 31.001 0</gx:coord>
  </gx:Track></Placemark></Document>
</kml>''';

Uint8List _bytes(String xml) => Uint8List.fromList(utf8.encode(xml));

void main() {
  const parser = ActivityTrackFileParser();

  test('TCX maps timed points, cumulative metrics and heart-rate samples', () {
    final parsed = parser
        .parse(_bytes(_tcx), extension: 'tcx', kind: ActivityKind.hike)
        .single;
    expect(parsed.record.source, ActivitySourceKind.fileImport);
    expect(parsed.record.kind, ActivityKind.hike);
    expect(parsed.record.sourceLabel, 'TCX 文件（运动类型手选）');
    expect(parsed.record.startedAt.toUtc(), DateTime.utc(2026, 10, 7, 22));
    expect(parsed.record.utcOffsetMinutes, 480);
    expect(parsed.record.durationSeconds, 600);
    expect(parsed.record.distanceMeters, 111);
    expect(parsed.record.averageHeartRateBpm, 130);
    expect(parsed.route, hasLength(2));
    expect(parsed.record.preciseRoute, isNull);
  });

  test('TCX without positions keeps honest metrics but no precise route', () {
    final noPositions = _tcx.replaceAll(
      RegExp(r'<Position>.*?</Position>', dotAll: true),
      '',
    );
    final parsed = parser
        .parse(_bytes(noPositions), extension: 'tcx', kind: ActivityKind.run)
        .single;
    expect(parsed.record.distanceMeters, 111);
    expect(parsed.route, isNull);
  });

  test('KML gx:Track pairs timestamp and latitude/longitude arrays', () {
    final parsed = parser
        .parse(_bytes(_kmlTrack), extension: 'kml', kind: ActivityKind.run)
        .single;
    expect(parsed.record.source, ActivitySourceKind.fileImport);
    expect(parsed.record.sourceLabel, 'KML 文件（运动类型手选）');
    expect(parsed.record.durationSeconds, 600);
    expect(parsed.record.distanceMeters, inInclusiveRange(110, 112));
    expect(parsed.route, hasLength(2));
    expect(parsed.route!.first.latitude, 31);
    expect(parsed.route!.first.longitude, 121);
    expect(parsed.record.averageHeartRateBpm, isNull);
  });

  test(
    'untimed KML LineString is rejected instead of inventing a workout date',
    () {
      const untimed = '''<kml xmlns="http://www.opengis.net/kml/2.2"><Placemark>
      <LineString><coordinates>121,31,0 121,31.001,0</coordinates></LineString>
    </Placemark></kml>''';
      expect(
        () => parser.parse(
          _bytes(untimed),
          extension: 'kml',
          kind: ActivityKind.run,
        ),
        throwsFormatException,
      );
    },
  );

  test('malformed, unsafe and unsupported activity files are rejected', () {
    expect(
      () => parser.parse(
        _bytes(
          _kmlTrack.replaceFirst(
            '2026-10-08T06:10:00+08:00',
            '2026-10-08T05:00:00',
          ),
        ),
        extension: 'kml',
        kind: ActivityKind.run,
      ),
      throwsFormatException,
    );
    expect(
      () => parser.parse(
        _bytes('<!DOCTYPE a [<!ENTITY x "x">]>$_tcx'),
        extension: 'tcx',
        kind: ActivityKind.run,
      ),
      throwsFormatException,
    );
    expect(
      () => parser.parse(
        _bytes(_kmlTrack),
        extension: 'zip',
        kind: ActivityKind.run,
      ),
      throwsFormatException,
    );
  });

  test('file source keeps imported TCX route local until selected', () async {
    final source = GpxActivitySource(
      gateway: _FileGateway(_bytes(_tcx), 'tcx'),
    );
    final imported = await source.importFromDevice(kind: ActivityKind.run);
    final selected = imported!.single;
    expect(selected.preciseRoute, isNull);
    expect(
      (await source.readPreciseRoute(selected)).preciseRoute,
      hasLength(2),
    );
    source.acceptSelection(selected.id);
    expect(
      (await source.readPreciseRoute(selected)).preciseRoute,
      hasLength(2),
    );
  });
}

final class _FileGateway implements GpxFileGateway {
  const _FileGateway(this.bytes, this.extension);

  final Uint8List bytes;
  final String extension;

  @override
  Future<ActivityFilePayload?> chooseActivityFile() async =>
      ActivityFilePayload(bytes: bytes, extension: extension);
}
