import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/core/theme/app_theme.dart';
import 'package:squadly/features/auth/domain/entities/user.dart';
import 'package:squadly/features/auth/presentation/providers/auth_provider.dart';
import 'package:squadly/features/auth/presentation/screens/login_screen.dart';

final class _LoadingAuthNotifier extends AuthNotifier {
  @override
  AsyncValue<User?> build() => const AsyncLoading();
}

void main() {
  testWidgets(
    'login primary action uses the V1.0 action color and full width',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const LoginScreen(),
          ),
        ),
      );

      final buttonFinder = find.byType(FilledButton);
      expect(buttonFinder, findsOneWidget);
      expect(find.text('登录'), findsOneWidget);
      expect(
        tester.getSize(buttonFinder).width,
        greaterThan(
          tester.view.physicalSize.width / tester.view.devicePixelRatio * 0.8,
        ),
      );

      final buttonContext = tester.element(buttonFinder);
      final theme = Theme.of(buttonContext);
      expect(
        theme.filledButtonTheme.style!.backgroundColor!.resolve({}),
        AppTheme.action,
      );
    },
  );

  testWidgets('login and phone actions retain visible busy labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_LoadingAuthNotifier.new),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const LoginScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('正在登录…'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.tap(find.text('手机登录'));
    await tester.pump();
    expect(find.text('正在发送验证码…'), findsOneWidget);
  });
}
