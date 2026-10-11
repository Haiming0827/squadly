import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/cards/domain/card_composer.dart';
import 'package:squadly/features/conversation/data/timeline_entry_mapper.dart';
import 'package:squadly/features/conversation/domain/timeline_entry.dart';

void main() {
  test('a published card row becomes one card timeline entry', () {
    final entry = timelineEntryFromJson({
      'id': 'entry-1',
      'squad_id': 'squad-a',
      'sender_id': 'alice',
      'kind': 'card',
      'body': null,
      'card_id': 'card-1',
      'reply_to_message_id': null,
      'client_nonce': 'nonce-1',
      'created_at': '2026-10-08T12:00:00Z',
      'author': {'id': 'alice', 'nickname': '阿晴', 'avatar_url': null},
      'card_snapshot': {
        'id': 'card-1',
        'squad_id': 'squad-a',
        'author_id': 'alice',
        'kind': 'activity',
        'snapshot': {
          'activity_type': 'run',
          'date': '2026-10-08',
          'distance_m': 5000,
          'duration_s': 1800,
          'pace_s_per_km': 360,
          'title': '晨跑',
        },
        'template_id': 'story',
        'template_version': 1,
        'created_at': '2026-10-08T12:00:00Z',
      },
    });

    expect(entry.kind, TimelineEntryKind.card);
    expect(entry.cardId, 'card-1');
    expect(entry.cardSnapshot?.kind, CardKind.activity);
    expect(entry.cardSnapshot?.payload['title'], '晨跑');
    expect(entry.authorName, '阿晴');
  });

  test('remote card projection rejects a raw route coordinate', () {
    expect(
      () => timelineEntryFromJson({
        'id': 'entry-2',
        'squad_id': 'squad-a',
        'sender_id': 'alice',
        'kind': 'card',
        'body': null,
        'card_id': 'card-2',
        'reply_to_message_id': null,
        'client_nonce': 'nonce-2',
        'created_at': '2026-10-08T12:00:00Z',
        'author': {'id': 'alice', 'nickname': '阿晴'},
        'card_snapshot': {
          'id': 'card-2',
          'kind': 'activity',
          'snapshot': {
            'title': '晨跑',
            'route': [
              [31.2, 121.4],
            ],
          },
          'template_id': 'story',
          'template_version': 1,
        },
      }),
      throwsFormatException,
    );
  });
}
