import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/app/providers/diagnostics_provider.dart';
import 'package:squadly/features/home/presentation/screens/profile_screen.dart';

void main() {
  testWidgets('unconfigured error reporting is disabled by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: ProfileScreen())),
      ),
    );
    await tester.pumpAndSettle();
    final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(tile.value, isFalse);
    expect(tile.onChanged, isNull);
    expect(find.text('此版本暂不可用'), findsOneWidget);
  });
  testWidgets(
    'enabling requires affirmative confirmation; disabling is immediate',
    (tester) async {
      final store = _Store();
      final controller = DiagnosticSettingsController(
        store: store,
        available: true,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [diagnosticsProvider.overrideWith((ref) => controller)],
          child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(find.text('允许发送错误报告？'), findsOneWidget);
      expect(store.value, isFalse);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(controller.state.enabled, isFalse);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('同意并开启'));
      await tester.pumpAndSettle();
      expect(store.value, isTrue);
      expect(controller.state.enabled, isTrue);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(store.value, isFalse);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}

class _Store implements DiagnosticConsentStore {
  bool value = false;
  @override
  Future<bool> read() async => value;
  @override
  Future<void> write(bool consent) async {
    value = consent;
  }
}
