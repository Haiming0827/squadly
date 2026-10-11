import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/cards/domain/card_composer.dart';

void main() {
  group('CardComposer', () {
    test('activity draft publishes only the explicitly supported summary', () {
      final composer = CardComposer();

      final draft = composer.draftFromActivity(
        activityType: 'run',
        date: DateTime.utc(2026, 10, 8, 7, 30),
        distanceMeters: 5200,
        durationSeconds: 1800,
        title: '晨跑',
        averageHeartRateBpm: 143,
        weightKg: 62.5,
        sleepMinutes: 420,
        preciseRoute: const [
          RoutePoint(latitude: 31.2304, longitude: 121.4737),
        ],
      );

      expect(draft.availablePrivateFields, {
        'heart_rate',
        'weight',
        'sleep',
        'precise_route',
      });
      expect(draft.snapshot.kind, CardKind.activity);
      expect(draft.snapshot.payload, {
        'activity_type': 'run',
        'date': '2026-10-08',
        'distance_m': 5200,
        'duration_s': 1800,
        'pace_s_per_km': 346,
        'title': '晨跑',
      });
    });

    test('sensitive values enter the snapshot only after field selection', () {
      final draft = CardComposer().draftFromActivity(
        activityType: 'hike',
        date: DateTime.utc(2026, 10, 8),
        distanceMeters: 10000,
        durationSeconds: 7200,
        title: '周末徒步',
        averageHeartRateBpm: 128,
        weightKg: 63,
        sleepMinutes: 480,
      );

      expect(draft.snapshot.payload.containsKey('avg_heart_rate_bpm'), isFalse);
      expect(draft.confirm(selectedFields: {'heart_rate', 'sleep'}).payload, {
        'activity_type': 'hike',
        'date': '2026-10-08',
        'distance_m': 10000,
        'duration_s': 7200,
        'pace_s_per_km': 720,
        'title': '周末徒步',
        'avg_heart_rate_bpm': 128,
        'sleep_minutes': 480,
        'confirmed_sensitive_fields': ['avg_heart_rate_bpm', 'sleep_minutes'],
      });
    });

    test(
      'precise route cannot be published before route policy is settled',
      () {
        final draft = CardComposer().draftFromActivity(
          activityType: 'run',
          date: DateTime.utc(2026, 10, 8),
          distanceMeters: 5000,
          durationSeconds: 1800,
          title: '晨跑',
          preciseRoute: const [RoutePoint(latitude: 31, longitude: 121)],
        );

        expect(
          () => draft.confirm(selectedFields: {'precise_route'}),
          throwsUnsupportedError,
        );
      },
    );

    test(
      'conversation draft shares owned message IDs but not message bodies',
      () {
        final draft = CardComposer().draftFromMessages(
          squadId: 'squad-a',
          authorId: 'alice',
          selected: const [
            SelectedChatMessage(
              id: 'msg-1',
              squadId: 'squad-a',
              authorId: 'alice',
              text: '今天的路很好走',
            ),
            SelectedChatMessage(
              id: 'msg-2',
              squadId: 'squad-a',
              authorId: 'alice',
              text: '下周再见',
            ),
          ],
        );

        expect(draft.snapshot.kind, CardKind.conversation);
        expect(draft.snapshot.payload, {
          'selected_message_ids': ['msg-1', 'msg-2'],
        });
      },
    );

    test(
      'conversation draft rejects a teammate quote without their consent',
      () {
        expect(
          () => CardComposer().draftFromMessages(
            squadId: 'squad-a',
            authorId: 'alice',
            selected: const [
              SelectedChatMessage(
                id: 'msg-b',
                squadId: 'squad-a',
                authorId: 'bob',
                text: '未经许可的原话',
              ),
            ],
          ),
          throwsStateError,
        );
      },
    );
  });
}
