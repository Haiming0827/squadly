import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/cards/domain/card_composer.dart';
import 'package:squadly/features/cards/presentation/card_image_renderer.dart';
import 'package:squadly/features/cards/presentation/card_preview.dart';

void main() {
  testWidgets('a published card renders a local PNG image', (tester) async {
    final key = GlobalKey();
    final snapshot = CardComposer()
        .draftFromActivity(
          activityType: 'run',
          date: DateTime.utc(2026, 10, 8),
          distanceMeters: 5000,
          durationSeconds: 1800,
          title: '晨跑',
        )
        .snapshot;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: CardPreview(squadName: '晨跑小队', snapshot: snapshot),
          ),
        ),
      ),
    );
    await tester.pump();

    final bytes = await tester.runAsync(
      () => const CardImageRenderer().renderPng(key),
    );

    expect(bytes?.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
  });
}
