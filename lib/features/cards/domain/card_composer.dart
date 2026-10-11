import 'dart:collection';

enum CardKind { activity, conversation }

/// A route sample is private draft data. Coordinates never enter the public
/// snapshot; the optional route must use the separate encrypted payload.
final class RoutePoint {
  const RoutePoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

/// Only messages already visible to the author can be selected. The body is
/// used for local preview; only IDs are included in the cloud snapshot.
final class SelectedChatMessage {
  const SelectedChatMessage({
    required this.id,
    required this.squadId,
    required this.authorId,
    required this.text,
    this.isRevoked = false,
  });

  final String id;
  final String squadId;
  final String authorId;
  final String text;
  final bool isRevoked;
}

/// The immutable, deliberately small payload both devices can redraw.
final class CardSnapshot {
  CardSnapshot({
    required this.kind,
    required Map<String, Object> payload,
    this.templateId = 'story',
    this.templateVersion = 1,
    this.hasEncryptedRoute = false,
  }) : payload = UnmodifiableMapView(Map<String, Object>.of(payload));

  final CardKind kind;
  final Map<String, Object> payload;
  final String templateId;
  final int templateVersion;
  final bool hasEncryptedRoute;
}

/// A local draft is not uploaded. Sensitive available fields are deliberately
/// separate from [snapshot] until their sharing rules have been approved.
final class CardDraft {
  CardDraft({
    required this.snapshot,
    required Set<String> availablePrivateFields,
    Map<String, Object> selectableValues = const {},
  }) : availablePrivateFields = Set.unmodifiable(availablePrivateFields),
       _selectableValues = UnmodifiableMapView(
         Map<String, Object>.of(selectableValues),
       );

  final CardSnapshot snapshot;
  final Set<String> availablePrivateFields;
  final Map<String, Object> _selectableValues;

  CardSnapshot confirm({Set<String> selectedFields = const {}}) {
    if (selectedFields.contains('precise_route')) {
      throw UnsupportedError(
        'Precise route requires the encrypted publish flow',
      );
    }
    if (!availablePrivateFields.containsAll(selectedFields)) {
      throw ArgumentError.value(selectedFields, 'selectedFields');
    }
    final fieldNames = <String, String>{
      'heart_rate': 'avg_heart_rate_bpm',
      'weight': 'weight_kg',
      'sleep': 'sleep_minutes',
    };
    final confirmedNames =
        selectedFields
            .map((field) => fieldNames[field])
            .whereType<String>()
            .toList()
          ..sort();
    final payload = <String, Object>{...snapshot.payload};
    for (final name in confirmedNames) {
      payload[name] = _selectableValues[name]!;
    }
    if (confirmedNames.isNotEmpty) {
      payload['confirmed_sensitive_fields'] = List<String>.unmodifiable(
        confirmedNames,
      );
    }
    return CardSnapshot(
      kind: snapshot.kind,
      payload: payload,
      templateId: snapshot.templateId,
      templateVersion: snapshot.templateVersion,
      hasEncryptedRoute: snapshot.hasEncryptedRoute,
    );
  }
}

final class CardComposer {
  CardDraft draftFromMessages({
    required String squadId,
    required String authorId,
    required List<SelectedChatMessage> selected,
  }) {
    if (selected.isEmpty) {
      throw StateError('Select at least one message');
    }
    if (selected.length > 6) {
      throw StateError('Select at most six messages');
    }
    if (selected.any(
      (message) =>
          message.squadId != squadId ||
          message.authorId != authorId ||
          message.isRevoked ||
          message.text.trim().isEmpty,
    )) {
      throw StateError('Only your own visible text messages can be shared');
    }
    final ids = selected.map((message) => message.id).toList();
    if (ids.toSet().length != ids.length) {
      throw StateError('Duplicate messages are not allowed');
    }
    return CardDraft(
      snapshot: CardSnapshot(
        kind: CardKind.conversation,
        payload: {'selected_message_ids': List<String>.unmodifiable(ids)},
      ),
      availablePrivateFields: const {},
    );
  }

  CardDraft draftFromActivity({
    required String activityType,
    required DateTime date,
    required double distanceMeters,
    required int durationSeconds,
    required String title,
    int? averageHeartRateBpm,
    double? weightKg,
    int? sleepMinutes,
    List<RoutePoint>? preciseRoute,
  }) {
    if (activityType != 'run' && activityType != 'hike') {
      throw ArgumentError.value(activityType, 'activityType');
    }
    if (!distanceMeters.isFinite || distanceMeters <= 0) {
      throw ArgumentError.value(distanceMeters, 'distanceMeters');
    }
    if (durationSeconds <= 0) {
      throw ArgumentError.value(durationSeconds, 'durationSeconds');
    }
    if (averageHeartRateBpm != null &&
        (averageHeartRateBpm < 30 || averageHeartRateBpm > 240)) {
      throw ArgumentError.value(averageHeartRateBpm, 'averageHeartRateBpm');
    }
    if (weightKg != null && (weightKg < 20 || weightKg > 500)) {
      throw ArgumentError.value(weightKg, 'weightKg');
    }
    if (sleepMinutes != null && (sleepMinutes < 0 || sleepMinutes > 1440)) {
      throw ArgumentError.value(sleepMinutes, 'sleepMinutes');
    }
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title');
    }

    final available = <String>{
      if (averageHeartRateBpm != null) 'heart_rate',
      if (weightKg != null) 'weight',
      if (sleepMinutes != null) 'sleep',
      if (preciseRoute?.isNotEmpty == true) 'precise_route',
    };
    final distance = distanceMeters.round();
    final pace = (durationSeconds * 1000 / distanceMeters).round();
    final selectableValues = <String, Object>{};
    if (averageHeartRateBpm != null) {
      selectableValues['avg_heart_rate_bpm'] = averageHeartRateBpm;
    }
    if (weightKg != null) {
      selectableValues['weight_kg'] = weightKg;
    }
    if (sleepMinutes != null) {
      selectableValues['sleep_minutes'] = sleepMinutes;
    }
    return CardDraft(
      snapshot: CardSnapshot(
        kind: CardKind.activity,
        payload: {
          'activity_type': activityType,
          'date': _dateOnly(date),
          'distance_m': distance,
          'duration_s': durationSeconds,
          'pace_s_per_km': pace,
          'title': normalizedTitle,
        },
      ),
      availablePrivateFields: available,
      selectableValues: selectableValues,
    );
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
