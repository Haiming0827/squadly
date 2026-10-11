import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/auth/domain/repositories/auth_repository.dart';
import 'package:squadly/features/auth/presentation/providers/auth_provider.dart';
import 'package:squadly/features/auth/presentation/screens/password_recovery_screen.dart';

class _AuthRepository extends Mock implements AuthRepository {}

void main() {
  testWidgets('recovery hides account existence and validates before Auth', (
    tester,
  ) async {
    final repo = _AuthRepository();
    when(
      () => repo.requestPasswordRecovery(email: 'a@example.test'),
    ).thenAnswer((_) async => const Right(unit));
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          routerConfig: router,
        ),
      ),
    );

    await tester.tap(find.text('发送验证码'));
    await tester.pump();
    expect(find.text('请输入有效的邮箱地址'), findsOneWidget);
    verifyNever(() => repo.requestPasswordRecovery(email: any(named: 'email')));

    await tester.enterText(find.byType(TextField).first, 'a@example.test');
    await tester.tap(find.text('发送验证码'));
    await tester.pump();
    expect(find.text('如该邮箱已注册，验证码会发送到邮箱。'), findsOneWidget);
    expect(find.text('确认重置'), findsOneWidget);
    verify(
      () => repo.requestPasswordRecovery(email: 'a@example.test'),
    ).called(1);
  });

  testWidgets('wrong recovery code keeps form; success returns to login', (
    tester,
  ) async {
    final repo = _AuthRepository();
    when(
      () => repo.requestPasswordRecovery(email: 'a@example.test'),
    ).thenAnswer((_) async => const Right(unit));
    when(
      () => repo.completePasswordRecovery(
        email: 'a@example.test',
        code: '000000',
        newPassword: 'newPassword1',
      ),
    ).thenAnswer((_) async => const Left(Failure.server(message: '验证码错误或已过期')));
    when(
      () => repo.completePasswordRecovery(
        email: 'a@example.test',
        code: '123456',
        newPassword: 'newPassword1',
      ),
    ).thenAnswer((_) async => const Right(unit));
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          routerConfig: router,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'a@example.test');
    await tester.tap(find.text('发送验证码'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, '邮件验证码'), '000000');
    await tester.enterText(
      find.widgetWithText(TextField, '新密码'),
      'newPassword1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '确认新密码'),
      'newPassword1',
    );
    await tester.ensureVisible(find.text('确认重置'));
    await tester.tap(find.text('确认重置'));
    await tester.pump();
    expect(find.text('验证码错误或已过期'), findsOneWidget);
    expect(find.text('确认重置'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '邮件验证码'), '123456');
    await tester.ensureVisible(find.text('确认重置'));
    await tester.tap(find.text('确认重置'));
    await tester.pumpAndSettle();
    expect(find.text('登录页'), findsOneWidget);
    verify(
      () => repo.completePasswordRecovery(
        email: 'a@example.test',
        code: '123456',
        newPassword: 'newPassword1',
      ),
    ).called(1);
  });
}

GoRouter _router() => GoRouter(
  initialLocation: '/recover',
  routes: [
    GoRoute(
      path: '/recover',
      builder: (_, _) => const PasswordRecoveryScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (_, _) => const Scaffold(body: Text('登录页')),
    ),
  ],
);
