import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/app/demo/demo_store.dart';
import 'package:squadly/core/theme/app_theme.dart';
import 'package:squadly/features/squad/presentation/screens/squad_list_screen.dart';

void main() {
  testWidgets('demo squad cards inherit the shared card radius token', (
    tester,
  ) async {
    final store = DemoAppStore()
      ..signInWithEmail(email: 'haiming@example.com', password: 'password1');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [demoAppStoreProvider.overrideWith((ref) => store)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: SquadListScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cards = tester.widgetList<Card>(find.byType(Card));
    expect(cards, isNotEmpty);
    expect(cards.every((card) => card.shape == null), isTrue);
    final themeShape = AppTheme.light().cardTheme.shape;
    expect(themeShape, isA<RoundedRectangleBorder>());
    expect(
      (themeShape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(16),
    );
  });
}
