import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/app/app.dart';
import 'package:squadly/app/providers/conversation_cache_provider.dart';
import 'package:squadly/app/router.dart';
import 'package:squadly/features/auth/domain/entities/user.dart';
import 'package:squadly/features/auth/presentation/providers/auth_provider.dart';
import 'package:squadly/features/squad/presentation/providers/squad_provider.dart';

final class _SignedIn extends AuthNotifier {
  @override
  AsyncValue<User?> build() => AsyncData(
    User(id: 'alice', nickname: '阿青', createdAt: DateTime.utc(2026, 10, 8)),
  );
}

final class _SignedOut extends AuthNotifier {
  @override
  AsyncValue<User?> build() => const AsyncData(null);
}

void main() {
  const useDemoBackend = bool.fromEnvironment(
    'USE_DEMO_BACKEND',
    defaultValue: true,
  );
  testWidgets('real build routes to remote shell with no demo squad', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationCacheProvider.overrideWithValue(null),
          authNotifierProvider.overrideWith(_SignedIn.new),
          currentSquadProvider.overrideWithValue(const AsyncData(null)),
          mySquadsProvider.overrideWith((ref) async => []),
        ],
        child: const SquadlyApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('会话'), findsOneWidget);
    expect(find.text('创建或加入小队'), findsOneWidget);
    expect(find.textContaining('本地演示'), findsNothing);
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(find.text('账号与联系方式'), findsOneWidget);
    await tester.tap(find.text('账号与联系方式'));
    await tester.pumpAndSettle();
    expect(find.text('仅你自己可以查看和管理这里的联系方式。'), findsOneWidget);
  }, skip: useDemoBackend);

  testWidgets('signed-out user can open password recovery', (tester) async {
    final container = ProviderContainer(
      overrides: [authNotifierProvider.overrideWith(_SignedOut.new)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SquadlyApp(),
      ),
    );
    container.read(routerProvider).go('/recover');
    await tester.pumpAndSettle();
    expect(find.text('找回密码'), findsOneWidget);
    expect(find.text('发送验证码'), findsOneWidget);
  }, skip: useDemoBackend);
}
