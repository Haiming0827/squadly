import 'dart:isolate';

import 'package:file_selector/file_selector.dart';

import '../../secure_route/domain/route_models.dart';
import '../domain/activity_record.dart';
import '../domain/activity_source.dart';
import 'activity_track_file_parser.dart';
import 'gpx_track_parser.dart';

abstract interface class GpxFileGateway {
  /// Returns null on cancellation. File names and paths never enter records.
  Future<ActivityFilePayload?> chooseActivityFile();
}

final class NativeGpxFileGateway implements GpxFileGateway {
  const NativeGpxFileGateway();

  @override
  Future<ActivityFilePayload?> chooseActivityFile() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: '运动轨迹文件',
          extensions: ['gpx', 'tcx', 'kml'],
          mimeTypes: ['application/gpx+xml', 'application/xml'],
          uniformTypeIdentifiers: ['public.xml'],
        ),
      ],
    );
    if (file == null) return null;
    final extension = file.name.split('.').last.toLowerCase();
    if (!const {'gpx', 'tcx', 'kml'}.contains(extension) ||
        await file.length() > GpxTrackParser.maxFileBytes) {
      throw const FormatException(
        'Expected a GPX, TCX or KML file under 5 MiB',
      );
    }
    return ActivityFilePayload(
      bytes: await file.readAsBytes(),
      extension: extension,
    );
  }
}

/// GPX coordinates stay in process memory; a cancelled selection cannot
/// replace the previously selected track.
final class GpxActivitySource implements ActivitySource {
  GpxActivitySource({GpxFileGateway? gateway})
    : _gateway = gateway ?? const NativeGpxFileGateway();

  final GpxFileGateway _gateway;
  ActivityRecord? _selectedRecord;
  List<RouteCoordinate>? _selectedRoute;
  final _candidates = <String, ActivityRecord>{};
  final _candidateRoutes = <String, List<RouteCoordinate>>{};

  Future<List<ActivityRecord>?> importFromDevice({
    required ActivityKind kind,
  }) async {
    final file = await _gateway.chooseActivityFile();
    if (file == null) return null;
    final parsed = await Isolate.run(
      () => const ActivityTrackFileParser().parse(
        file.bytes,
        extension: file.extension,
        kind: kind,
      ),
    );
    _candidates
      ..clear()
      ..addEntries(
        parsed.map((track) => MapEntry(track.record.id, track.record)),
      );
    _candidateRoutes
      ..clear()
      ..addEntries(
        parsed
            .where((track) => track.route != null)
            .map((track) => MapEntry(track.record.id, track.route!)),
      );
    return List<ActivityRecord>.unmodifiable(
      parsed.map((track) => track.record),
    );
  }

  void acceptSelection(String id) {
    final record = _candidates[id];
    if (record == null) throw const ActivityNotFound();
    _selectedRecord = record;
    _selectedRoute = _candidateRoutes[id];
    discardCandidates();
  }

  void discardCandidates() {
    _candidates.clear();
    _candidateRoutes.clear();
  }

  @override
  Future<List<ActivityRecord>> listEligibleActivities({
    required DateTime from,
    required DateTime to,
  }) async {
    if (!from.isBefore(to)) throw ArgumentError('Invalid workout date range');
    final records = Map<String, ActivityRecord>.of(_candidates);
    if (_selectedRecord case final selected?) {
      records.putIfAbsent(selected.id, () => selected);
    }
    return List<ActivityRecord>.unmodifiable(
      records.values.where(
        (record) =>
            !record.startedAt.isBefore(from) && record.startedAt.isBefore(to),
      ),
    );
  }

  @override
  Future<ActivityRecord> readActivity(String id) async {
    final record =
        _candidates[id] ?? (_selectedRecord?.id == id ? _selectedRecord : null);
    if (record == null) throw const ActivityNotFound();
    return record;
  }

  @override
  Future<ActivityRecord> readPreciseRoute(ActivityRecord selected) async {
    final record =
        _candidates[selected.id] ??
        (_selectedRecord?.id == selected.id ? _selectedRecord : null);
    final route =
        _candidateRoutes[selected.id] ??
        (_selectedRecord?.id == selected.id ? _selectedRoute : null);
    if (record == null ||
        (selected.source != ActivitySourceKind.gpxFile &&
            selected.source != ActivitySourceKind.fileImport)) {
      throw const ActivityNotFound();
    }
    if (route == null) throw const ActivitySourceUnavailable();
    return selected.copyWith(preciseRoute: route);
  }
}
