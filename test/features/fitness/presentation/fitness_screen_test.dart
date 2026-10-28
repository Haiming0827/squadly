import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/app/demo/demo_store.dart';
import 'package:squadly/core/theme/app_theme.dart';
import 'package:squadly/features/fitness/presentation/screens/fitness_screen.dart';

void main() {
  testWidgets('completed fitness tasks use the semantic success token', (
    tester,
  ) async {
    final store = DemoAppStore()
      ..signInWithEmail(email: 'haiming@example.com', password: 'password1')
      ..checkInTask(taskId: 'task-run', squadId: 'squad-weekend', value: 3.1);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [demoAppStoreProvider.overrideWith((ref) => store)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: FitnessScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final completedIcon = tester.widget<Icon>(
      find.byIcon(Icons.check_circle_rounded),
    );
    expect(
      completedIcon.color,
      AppTheme.light().extension<SquadlyPalette>()!.success,
    );
  });
}
