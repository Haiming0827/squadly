import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/app/demo/demo_store.dart';
import 'package:squadly/features/auth/presentation/providers/auth_provider.dart';
import 'package:squadly/features/home/presentation/screens/profile_screen.dart';

void main() {
  testWidgets('member can edit public nickname without touching contact', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final before = container
        .read(demoAppStoreProvider.notifier)
        .signInWithEmail(email: 'haiming@example.com', password: 'password1');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const Scaffold(body: ProfileScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('编辑昵称'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '晨跑海明');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('晨跑海明'), findsOneWidget);
    final after = container.read(authNotifierProvider).value;
    expect(after?.nickname, '晨跑海明');
    expect(after?.email, before.email);
    expect(after?.phone, before.phone);
  });

  testWidgets('invalid nickname leaves current account signed in', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(demoAppStoreProvider.notifier)
        .signInWithEmail(email: 'haiming@example.com', password: 'password1');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const Scaffold(body: ProfileScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('编辑昵称'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, ' ');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('编辑昵称'), findsOneWidget);
    expect(container.read(authNotifierProvider).value, isNotNull);
  });
}
