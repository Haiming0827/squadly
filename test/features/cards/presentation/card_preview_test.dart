import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/cards/domain/card_composer.dart';
import 'package:squadly/features/cards/presentation/card_preview.dart';

void main() {
  testWidgets(
    'activity preview shows confirmed values and omits missing ones',
    (tester) async {
      final draft = CardComposer().draftFromActivity(
        activityType: 'run',
        date: DateTime.utc(2026, 10, 8),
        distanceMeters: 5000,
        durationSeconds: 1800,
        title: '晨跑',
        averageHeartRateBpm: 128,
        weightKg: 63,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardPreview(
              squadName: '晨跑小队',
              snapshot: draft.confirm(selectedFields: {'heart_rate'}),
            ),
          ),
        ),
      );

      expect(find.text('晨跑'), findsOneWidget);
      expect(find.text('5.00 km'), findsOneWidget);
      expect(find.text('128 bpm'), findsOneWidget);
      expect(find.textContaining('63 kg'), findsNothing);
      expect(find.textContaining('睡眠'), findsNothing);
    },
  );
}
