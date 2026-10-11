import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/activity_import/data/activity_track_file_parser.dart';
import 'package:squadly/features/activity_import/data/gpx_activity_source.dart';
import 'package:squadly/features/activity_import/data/gpx_track_parser.dart';
import 'package:squadly/features/activity_import/domain/activity_record.dart';
import 'package:squadly/features/activity_import/domain/activity_source.dart';

const _validGpx = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="synthetic-test">
  <trk><name>Private track name</name><trkseg>
    <trkpt lat="31.0000" lon="121.0000"><time>2026-10-08T06:00:00+08:00</time></trkpt>
    <trkpt lat="31.0010" lon="121.0000"><time>2026-10-08T06:10:00+08:00</time></trkpt>
  </trkseg></trk>
</gpx>''';

Uint8List _bytes(String source) => Uint8List.fromList(utf8.encode(source));

void main() {
  test(
    'GPX is one private timed activity with explicit kind and local day',
    () {
      final tracks = const GpxTrackParser().parse(
        _bytes(_validGpx),
        kind: ActivityKind.hike,
      );
      expect(tracks, hasLength(1));
      final record = tracks.single.record;
      expect(record.source, ActivitySourceKind.gpxFile);
      expect(record.kind, ActivityKind.hike);
      expect(record.sourceLabel, 'GPX 文件（运动类型手选）');
      expect(record.sourceLabel, isNot(contains('Private track name')));
      expect(record.correctedFields, contains('activity_type'));
      expect(record.startedAt.toUtc(), DateTime.utc(2026, 10, 7, 22));
      expect(record.utcOffsetMinutes, 480);
      expect(ActivityMetrics.localCalendarDate(record), DateTime(2026, 10, 8));
      expect(record.durationSeconds, 600);
      expect(record.distanceMeters, inInclusiveRange(110, 112));
      expect(record.preciseRoute, isNull);
      expect(tracks.single.route, hasLength(2));
    },
  );

  test('GPX heart-rate extensions are averaged and stay optional', () {
    const withHeartRate = '''<gpx xmlns="http://www.topografix.com/GPX/1/1"
      xmlns:tp="http://www.garmin.com/xmlschemas/TrackPointExtension/v1"
      version="1.1">
      <trk><trkseg>
        <trkpt lat="31.0000" lon="121.0000">
          <time>2026-10-08T06:00:00+08:00</time>
          <extensions><tp:TrackPointExtension><tp:hr>120</tp:hr></tp:TrackPointExtension></extensions>
        </trkpt>
        <trkpt lat="31.0010" lon="121.0000">
          <time>2026-10-08T06:10:00+08:00</time>
          <extensions><tp:TrackPointExtension><tp:hr>140</tp:hr></tp:TrackPointExtension></extensions>
        </trkpt>
      </trkseg></trk>
    </gpx>''';
    const parser = GpxTrackParser();
    final withSamples = parser
        .parse(_bytes(withHeartRate), kind: ActivityKind.run)
        .single
        .record;
    final missingSamples = parser
        .parse(_bytes(_validGpx), kind: ActivityKind.run)
        .single
        .record;
    expect(withSamples.averageHeartRateBpm, 130);
    expect(missingSamples.averageHeartRateBpm, isNull);
  });

  test(
    'file import keeps route local until the selected record is read',
    () async {
      final gateway = _Gateway(_bytes(_validGpx));
      final source = GpxActivitySource(gateway: gateway);
      final imported = await source.importFromDevice(kind: ActivityKind.run);
      expect(imported, hasLength(1));
      final selected = imported!.single;
      expect(selected.preciseRoute, isNull);
      expect((await source.readActivity(selected.id)).id, selected.id);
      expect(
        await source.listEligibleActivities(
          from: DateTime.utc(2026, 10, 7),
          to: DateTime.utc(2026, 10, 9),
        ),
        hasLength(1),
      );
      final withRoute = await source.readPreciseRoute(selected);
      expect(withRoute.preciseRoute, hasLength(2));
      expect(selected.preciseRoute, isNull);
      source.acceptSelection(selected.id);
      expect(gateway.picks, 1);
      gateway.bytes = null;
      expect(await source.importFromDevice(kind: ActivityKind.hike), isNull);
      expect((await source.readActivity(selected.id)).id, selected.id);
      await expectLater(
        source.readPreciseRoute(
          selected.copyWith(id: 'other', source: ActivitySourceKind.gpxFile),
        ),
        throwsA(isA<ActivityNotFound>()),
      );
    },
  );

  test('cancelled second selection preserves the accepted route', () async {
    final gateway = _Gateway(_bytes(_validGpx));
    final source = GpxActivitySource(gateway: gateway);
    final first = (await source.importFromDevice(
      kind: ActivityKind.run,
    ))!.single;
    source.acceptSelection(first.id);
    gateway.bytes = _bytes(_validGpx.replaceAll('2026-10-08', '2026-10-09'));
    final second = (await source.importFromDevice(
      kind: ActivityKind.hike,
    ))!.single;
    expect(second.id, isNot(first.id));
    source.discardCandidates();
    expect((await source.readActivity(first.id)).id, first.id);
    expect((await source.readPreciseRoute(first)).preciseRoute, hasLength(2));
    await expectLater(
      source.readActivity(second.id),
      throwsA(isA<ActivityNotFound>()),
    );
  });

  test('malformed, overlarge and unsafe GPX files are rejected', () {
    const parser = GpxTrackParser();
    expect(
      () => parser.parse(
        _bytes(
          '<!DOCTYPE gpx [<!ENTITY x "boom">]>'
          '$_validGpx',
        ),
        kind: ActivityKind.run,
      ),
      throwsFormatException,
    );
    expect(
      () => parser.parse(
        Uint8List(GpxTrackParser.maxFileBytes + 1),
        kind: ActivityKind.run,
      ),
      throwsFormatException,
    );
    expect(
      () => parser.parse(
        _bytes(_validGpx.replaceFirst('lat="31.0010"', 'lat="99"')),
        kind: ActivityKind.run,
      ),
      throwsFormatException,
    );
    expect(
      () => parser.parse(
        _bytes(
          _validGpx.replaceFirst(
            '2026-10-08T06:10:00+08:00',
            '2026-10-08T05:10:00+08:00',
          ),
        ),
        kind: ActivityKind.run,
      ),
      throwsFormatException,
    );
    expect(
      () => parser.parse(
        _bytes(
          _validGpx.replaceFirst(
            '2026-10-08T06:10:00+08:00',
            '2026-10-08T06:10:00',
          ),
        ),
        kind: ActivityKind.run,
      ),
      throwsFormatException,
    );
  });

  test('distance never bridges separate GPX track segments', () {
    final segmented = _validGpx.replaceFirst(
      '</trkseg></trk>',
      '</trkseg><trkseg>'
          '<trkpt lat="32.0000" lon="122.0000">'
          '<time>2026-10-08T06:20:00+08:00</time></trkpt>'
          '<trkpt lat="32.0010" lon="122.0000">'
          '<time>2026-10-08T06:30:00+08:00</time></trkpt>'
          '</trkseg></trk>',
    );
    final track = const GpxTrackParser()
        .parse(_bytes(segmented), kind: ActivityKind.hike)
        .single;
    final record = track.record;
    expect(record.distanceMeters, inInclusiveRange(220, 225));
    expect(record.durationSeconds, 1800);
    expect(track.route, isNull);
  });

  test(
    'multi-segment activity cannot claim an exact continuous route',
    () async {
      final segmented = _validGpx.replaceFirst(
        '</trkseg></trk>',
        '</trkseg><trkseg>'
            '<trkpt lat="32.0000" lon="122.0000">'
            '<time>2026-10-08T06:20:00+08:00</time></trkpt>'
            '<trkpt lat="32.0010" lon="122.0000">'
            '<time>2026-10-08T06:30:00+08:00</time></trkpt>'
            '</trkseg></trk>',
      );
      final source = GpxActivitySource(gateway: _Gateway(_bytes(segmented)));
      final selected = (await source.importFromDevice(
        kind: ActivityKind.hike,
      ))!.single;
      await expectLater(
        source.readPreciseRoute(selected),
        throwsA(isA<ActivitySourceUnavailable>()),
      );
    },
  );
}

final class _Gateway implements GpxFileGateway {
  _Gateway(this.bytes);

  Uint8List? bytes;
  int picks = 0;

  @override
  Future<ActivityFilePayload?> chooseActivityFile() async {
    picks++;
    final selected = bytes;
    return selected == null
        ? null
        : ActivityFilePayload(bytes: selected, extension: 'gpx');
  }
}
