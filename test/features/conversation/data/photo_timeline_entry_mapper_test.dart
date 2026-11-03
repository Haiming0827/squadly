import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/conversation/data/timeline_entry_mapper.dart';
import 'package:squadly/features/conversation/domain/timeline_entry.dart';

Map<String, dynamic> _projection() => {
  'id': 'message',
  'squad_id': 'squad',
  'sender_id': 'author',
  'author': {'nickname': '队友'},
  'kind': 'photo',
  'body': null,
  'photo_id': 'media',
  'photo': {
    'id': 'media',
    'width': 4,
    'height': 3,
    'byte_length': 600,
    'revoked': false,
  },
  'reply_to_message_id': 'parent',
  'client_nonce': 'nonce',
  'created_at': '2026-10-27T10:00:00Z',
};

void main() {
  test('photo and tombstone retain the same timeline and reply identity', () {
    final json = _projection();
    final entry = timelineEntryFromJson(json);
    expect(entry.kind, TimelineEntryKind.photo);
    expect(entry.photo!.mediaId, 'media');
    expect(entry.replyToEntryId, 'parent');
    expect(entry.photo!.isRevoked, isFalse);
    expect(entry.photo!.isHidden, isFalse);
    (json['photo'] as Map)['hidden'] = true;
    final hidden = timelineEntryFromJson(json);
    expect(hidden.photo!.isHidden, isTrue);
    (json['photo'] as Map)['revoked'] = true;
    final revoked = timelineEntryFromJson(json);
    expect(revoked.id, entry.id);
    expect(revoked.photo!.isRevoked, isTrue);
    expect(revoked.asLocalCopy().photo, revoked.photo);
    expect(revoked.asLocalCopy().isLocalCopy, isTrue);
  });

  for (final change in <String, void Function(Map<String, dynamic>)>{
    'mismatched identity': (p) => p['photo_id'] = 'other',
    'blank identity': (p) {
      p['photo_id'] = '';
      (p['photo'] as Map)['id'] = '';
    },
    'extra storage URL': (p) =>
        (p['photo'] as Map)['url'] = 'https://example.test/photo',
    'missing revocation': (p) => (p['photo'] as Map).remove('revoked'),
    'incorrect dimensions': (p) => (p['photo'] as Map)['width'] = 1601,
    'noninteger dimensions': (p) => (p['photo'] as Map)['width'] = 1.5,
    'empty image': (p) => (p['photo'] as Map)['byte_length'] = 0,
    'oversize image': (p) => (p['photo'] as Map)['byte_length'] = 2097153,
    'invalid hidden flag': (p) => (p['photo'] as Map)['hidden'] = 'false',
    'invalid revoked flag': (p) => (p['photo'] as Map)['revoked'] = 'false',
    'text mixed with photo': (p) => p['body'] = 'unexpected',
    'card mixed with photo': (p) => p['card_id'] = 'card',
    'photo in plan thread': (p) => p['plan_id'] = 'private-plan',
    'photo attached to text': (p) {
      p['kind'] = 'text';
      p['body'] = 'text';
    },
  }.entries) {
    test('rejects ${change.key}', () {
      final json = _projection();
      change.value(json);
      expect(() => timelineEntryFromJson(json), throwsFormatException);
    });
  }
}
