import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:squadly/app/demo/demo_store.dart';
import 'package:squadly/app/providers/domain_repository_providers.dart';
import 'package:squadly/app/router.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/core/theme/app_theme.dart';
import 'package:squadly/features/auth/presentation/providers/auth_provider.dart';
import 'package:squadly/features/squad/domain/repositories/squad_repository.dart';

class _SquadRepositoryMock extends Mock implements SquadRepository {}

void main() {
  for (final transition in [
    'switch',
    'scenario-switch',
    'rapid-switch',
    'sign-out',
    'same-user',
  ]) {
    testWidgets('private routes follow the $transition identity transition', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = DemoAppStore()
        ..signInWithEmail(email: 'haiming@example.com', password: 'password1');
      final container = ProviderContainer(
        overrides: [demoAppStoreProvider.overrideWith((ref) => store)],
      );
      addTearDown(container.dispose);
      final routerSubscription = container.listen(routerProvider, (_, _) {});
      addTearDown(routerSubscription.close);
      final router = container.read(routerProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final navigationBar = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      navigationBar.onDestinationSelected!(2);
      await tester.pumpAndSettle();
      if (transition == 'scenario-switch') {
        router.go('/scenarios/finance');
        await tester.pumpAndSettle();
      }
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      ScaffoldMessenger.of(navigator.context).showSnackBar(
        const SnackBar(content: Text('原账号的私有提示'), duration: Duration(days: 1)),
      );
      await tester.pumpAndSettle();
      final pageResult = navigator.push<String>(
        MaterialPageRoute<String>(
          builder: (_) => const Scaffold(body: Text('原账号的私有表单')),
        ),
      );
      await tester.pumpAndSettle();
      final dialogResult = showDialog<bool>(
        context: navigator.context,
        builder: (_) => const AlertDialog(title: Text('原账号的私有确认')),
      );
      await tester.pumpAndSettle();

      if (transition == 'sign-out') {
        store.signOut();
      } else {
        if (transition == 'rapid-switch') store.signOut();
        store.signInWithEmail(
          email: transition == 'same-user'
              ? 'haiming@example.com'
              : 'lina@example.com',
          password: 'password1',
        );
      }
      await tester.pumpAndSettle();

      expect(container.read(routerProvider), same(router));
      if (transition == 'same-user') {
        expect(find.text('原账号的私有确认'), findsOneWidget);
        expect(find.text('原账号的私有表单'), findsOneWidget);
        expect(find.text('原账号的私有提示'), findsOneWidget);
      } else {
        await expectLater(pageResult, completion(isNull));
        await expectLater(dialogResult, completion(isNull));
        expect(find.text('原账号的私有确认'), findsNothing);
        expect(find.text('原账号的私有表单'), findsNothing);
        expect(find.text('原账号的私有提示'), findsNothing);
        expect(
          router.routeInformationProvider.value.uri.path,
          transition == 'sign-out' ? '/login' : '/',
        );
        if (transition != 'sign-out') {
          expect(
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
                .selectedIndex,
            0,
          );
        }
      }
    });
  }

  testWidgets('first login retains the invitation return path', (tester) async {
    final store = DemoAppStore();
    final repository = _SquadRepositoryMock();
    when(() => repository.redeemInvitation(credential: 'opaque-invite'))
        .thenAnswer(
          (_) async => const Left(Failure.validation(message: '测试邀请等待重新确认')),
        );
    final container = ProviderContainer(
      overrides: [
        demoAppStoreProvider.overrideWith((ref) => store),
        squadRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(routerProvider, (_, _) {});
    addTearDown(subscription.close);
    final router = container.read(routerProvider)..go('/invite/opaque-invite');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/login');
    expect(
      router.routeInformationProvider.value.uri.queryParameters['from'],
      '/invite/opaque-invite',
    );

    store.signInWithEmail(email: 'haiming@example.com', password: 'password1');
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/invite/opaque-invite',
    );
    expect(find.text('测试邀请等待重新确认'), findsOneWidget);
    verify(() => repository.redeemInvitation(credential: 'opaque-invite'))
        .called(1);
  });

  test(
    'keeps the router instance stable across authentication changes',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialRouter = container.read(routerProvider);

      await container
          .read(authNotifierProvider.notifier)
          .signInWithEmail(email: 'haiming@example.com', password: 'password1');

      expect(container.read(routerProvider), same(initialRouter));
    },
  );
}
