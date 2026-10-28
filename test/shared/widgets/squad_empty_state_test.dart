import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/core/theme/app_theme.dart';
import 'package:squadly/shared/widgets/squad_empty_state.dart';

void main() {
  testWidgets('explains squad capabilities without sample activity data', (
    tester,
  ) async {
    var createCount = 0;
    var joinCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SquadEmptyState(
            onCreate: () => createCount++,
            onJoin: () => joinCount++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('一起制定计划'), findsOneWidget);
    expect(find.text('在小队内沟通和分享'), findsOneWidget);
    expect(find.text('保留个人隐私'), findsOneWidget);
    expect(find.text('周末城市漫步'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, '创建小队'));
    await tester.tap(find.text('输入邀请码加入'));
    expect(createCount, 1);
    expect(joinCount, 1);
  });

  testWidgets('fits a narrow screen with increased text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: SquadEmptyState(onCreate: _noop, onJoin: _noop),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('还没有小队'), findsOneWidget);
  });
}

void _noop() {}
