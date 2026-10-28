import '../../cards/domain/card_composer.dart';
import '../../photos/domain/photo.dart';
import '../domain/timeline_entry.dart';

/// Decode only the public projection returned by page_squad_timeline and the
/// two send RPCs. Contact details must never be part of this projection.
TimelineEntry timelineEntryFromJson(Map<String, dynamic> json) {
  final kind = switch (json['kind']) {
    'text' => TimelineEntryKind.text,
    'card' => TimelineEntryKind.card,
    'photo' => TimelineEntryKind.photo,
    _ => throw const FormatException('Unknown timeline entry kind'),
  };
  final author = _map(json['author']);
  final cardValue = json['card_snapshot'];
  final card = cardValue == null
      ? null
      : _cardSnapshotFromJson(_map(cardValue));
  final cardId = json['card_id'] as String?;
  final photoValue = json['photo'];
  PhotoAttachment? photo;
  if (kind == TimelineEntryKind.photo) {
    final value = _map(photoValue);
    if (value.length != 5 ||
        !value.keys.toSet().containsAll({
          'id',
          'width',
          'height',
          'byte_length',
          'revoked',
        }) ||
        value['id'] is! String ||
        (value['id'] as String).trim().isEmpty ||
        value['id'] != json['photo_id'] ||
        value['width'] is! int ||
        value['height'] is! int ||
        value['byte_length'] is! int ||
        value['revoked'] is! bool ||
        (value['width'] as int) < 1 ||
        (value['width'] as int) > PhotoImage.maxDimension ||
        (value['height'] as int) < 1 ||
        (value['height'] as int) > PhotoImage.maxDimension ||
        (value['byte_length'] as int) < 1 ||
        (value['byte_length'] as int) > PhotoImage.maxBytes ||
        json['body'] != null ||
        cardValue != null ||
        cardId != null ||
        json['plan_id'] != null) {
      throw const FormatException('Invalid photo message projection');
    }
    photo = PhotoAttachment(
      mediaId: value['id'] as String,
      width: value['width'] as int,
      height: value['height'] as int,
      byteLength: value['byte_length'] as int,
      isRevoked: value['revoked'] as bool,
    );
  } else if (photoValue != null || json['photo_id'] != null) {
    throw const FormatException('Non-photo entry contains photo data');
  }
  if (kind == TimelineEntryKind.card &&
      (card == null || cardId == null || cardId != _map(cardValue)['id'])) {
    throw const FormatException('Card entry has no matching snapshot');
  }
  return TimelineEntry(
    id: json['id'] as String,
    squadId: json['squad_id'] as String,
    planId: json['plan_id'] as String?,
    authorId: json['sender_id'] as String,
    authorName: (author['nickname'] as String?)?.trim().isNotEmpty == true
        ? author['nickname'] as String
        : '成员',
    kind: kind,
    text: json['body'] as String?,
    cardId: cardId,
    cardSnapshot: card,
    photo: photo,
    replyToEntryId: json['reply_to_message_id'] as String?,
    clientNonce: json['client_nonce'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

CardSnapshot _cardSnapshotFromJson(Map<String, dynamic> json) {
  final kind = switch (json['kind']) {
    'activity' => CardKind.activity,
    'conversation' => CardKind.conversation,
    _ => throw const FormatException('Unknown card kind'),
  };
  final rawPayload = _map(json['snapshot']);
  final allowed = kind == CardKind.activity
      ? const {
          'activity_type',
          'date',
          'distance_m',
          'duration_s',
          'pace_s_per_km',
          'title',
          'avg_heart_rate_bpm',
          'weight_kg',
          'sleep_minutes',
          'confirmed_sensitive_fields',
        }
      : const {'selected_message_ids'};
  if (!allowed.containsAll(rawPayload.keys)) {
    throw const FormatException('Card snapshot includes unsupported data');
  }
  final payload = Map<String, Object>.from(rawPayload);
  return CardSnapshot(
    kind: kind,
    payload: payload,
    templateId: json['template_id'] as String,
    templateVersion: json['template_version'] as int,
    hasEncryptedRoute: json['has_encrypted_route'] as bool? ?? false,
  );
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) throw const FormatException('Expected JSON object');
  return Map<String, dynamic>.from(value);
}
