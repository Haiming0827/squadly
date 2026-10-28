import 'dart:async';

import 'package:cloudbase_flutter/cloudbase_flutter.dart' as cb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:squadly/app/demo/demo_store.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/core/network/cloudbase_client_provider.dart';
import 'package:squadly/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:squadly/features/auth/domain/entities/user.dart';
import 'package:squadly/features/auth/domain/repositories/auth_repository.dart';
import 'package:squadly/features/auth/presentation/providers/auth_provider.dart';
import 'package:squadly/features/notifications/push_registration_provider.dart';

class _AppMock extends Mock implements cb.CloudBase {}

class _AuthMock extends Mock implements cb.CloudBaseAuth {}

class _RepositoryMock extends Mock implements AuthRepository {}

class _DatasourceMock extends Mock implements AuthRemoteDatasource {}

void main() {
  test(
    'successful sign-out clears password setup without an SDK event',
    () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      when(() => harness.auth.getSession()).thenAnswer(
        (_) async => cb.SignInRes(error: cb.AuthError(code: 'no_session')),
      );
      when(() => harness.repository.signOut())
          .thenAnswer((_) async => const Right(unit));
      final notifier = harness.start();
      await Future<void>.delayed(Duration.zero);
      harness.container
              .read(phonePasswordSetupRequiredProvider.notifier)
              .state =
          true;

      await notifier.signOut();

      expect(harness.container.read(authNotifierProvider).value, isNull);
      expect(
        harness.container.read(phonePasswordSetupRequiredProvider),
        isFalse,
      );
    },
  );

  test(
    'demo profile refresh uses the local repository without CloudBase',
    () async {
      final store = DemoAppStore()
        ..signInWithEmail(email: 'haiming@example.com', password: 'password1');
      final container = ProviderContainer(
        overrides: [
          useDemoBackendProvider.overrideWithValue(true),
          demoAppStoreProvider.overrideWith((ref) => store),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(authNotifierProvider, (_, _) {});
      addTearDown(subscription.close);
      final originalUser = container.read(authNotifierProvider).value;

      await container.read(authNotifierProvider.notifier).refreshCurrentUser();

      expect(container.read(authNotifierProvider).value, originalUser);
      expect(container.read(authNotifierProvider).hasError, isFalse);
    },
  );

  test('an empty session token never establishes a user', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    when(() => harness.auth.getSession()).thenAnswer(
      (_) async => cb.SignInRes(
        data: cb.SignInResData(
          session: cb.Session(
            accessToken: '   ',
            user: cb.User(id: 'alice', createdAt: '2026-01-01T00:00:00Z'),
          ),
        ),
      ),
    );
    when(() => harness.repository.getCurrentUser())
        .thenAnswer((_) => Future<Either<Failure, User>>.value(Right(_alice)));
    harness.start();
    await Future<void>.delayed(Duration.zero);

    expect(harness.container.read(authNotifierProvider).value, isNull);
    verifyNever(() => harness.repository.getCurrentUser());
  });

  test(
    'a profile from another session never becomes the current user',
    () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      when(() => harness.auth.getSession()).thenAnswer((_) async => _session());
      when(() => harness.repository.getCurrentUser()).thenAnswer(
        (_) => Future<Either<Failure, User>>.value(
          Right(_alice.copyWith(id: 'bob')),
        ),
      );
      harness.start();
      await Future<void>.delayed(Duration.zero);

      final state = harness.container.read(authNotifierProvider);
      expect(state.value, isNull);
      expect(state.error, isA<UnauthorizedFailure>());
    },
  );

  test('a thrown SDK session failure becomes a safe auth error', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    when(() => harness.auth.getSession()).thenAnswer(
      (_) => Future<cb.SignInRes>.error(StateError('sensitive-backend-state')),
    );
    harness.start();
    await Future<void>.delayed(Duration.zero);

    final state = harness.container.read(authNotifierProvider);
    expect(state.error, isA<NetworkFailure>());
    expect(state.error.toString(), isNot(contains('sensitive-backend-state')));
  });

  for (final code in ['no_session', 'session_timeout']) {
    test(
      'late startup $code cannot replace a successful explicit login',
      () async {
        final harness = _Harness();
        addTearDown(harness.dispose);
        final restoring = Completer<void>();
        final session = Completer<cb.SignInRes>();
        when(() => harness.auth.getSession()).thenAnswer((_) {
          restoring.complete();
          return session.future;
        });
        when(
          () => harness.repository.signInWithEmail(
            email: 'alice@example.test',
            password: 'password1',
          ),
        ).thenAnswer((_) async => Right(_alice));
        final notifier = harness.start();
        await restoring.future;
        await notifier.signInWithEmail(
          email: 'alice@example.test',
          password: 'password1',
        );
        expect(harness.container.read(authNotifierProvider).value?.id, 'alice');

        session.complete(cb.SignInRes(error: cb.AuthError(code: code)));
        await Future<void>.delayed(Duration.zero);
        expect(harness.container.read(authNotifierProvider).value?.id, 'alice');
        expect(harness.container.read(authNotifierProvider).hasError, isFalse);
      },
    );
  }

  test('late profile refresh cannot overwrite a saved nickname', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    when(() => harness.auth.getSession()).thenAnswer((_) async => _session());
    final refreshStarted = Completer<void>();
    final oldProfile = Completer<Either<Failure, User>>();
    var reads = 0;
    when(() => harness.repository.getCurrentUser()).thenAnswer((_) {
      if (++reads == 1) return Future.value(Right(_alice));
      refreshStarted.complete();
      return oldProfile.future;
    });
    when(() => harness.repository.updateNickname(nickname: '新昵称'))
        .thenAnswer((_) async => Right(_alice.copyWith(nickname: '新昵称')));
    final notifier = harness.start();
    await Future<void>.delayed(Duration.zero);
    expect(harness.container.read(authNotifierProvider).value?.id, 'alice');
    final refresh = notifier.refreshCurrentUser();
    await refreshStarted.future;
    expect(await notifier.updateNickname('新昵称'), isNull);

    oldProfile.complete(Right(_alice));
    await refresh;
    expect(harness.container.read(authNotifierProvider).value?.nickname, '新昵称');
  });

  test(
    'a signed-out session cannot receive a late password-setup flag',
    () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      final lookupStarted = Completer<void>();
      final passwordSetup = Completer<bool>();
      when(() => harness.auth.getSession()).thenAnswer((_) async => _session());
      when(() => harness.datasource.currentUserNeedsPasswordSetup())
          .thenAnswer((_) {
            lookupStarted.complete();
            return passwordSetup.future;
          });
      when(
        () => harness.repository.getCurrentUser(),
      ).thenAnswer((_) => Future<Either<Failure, User>>.value(Right(_alice)));
      harness.start();
      await lookupStarted.future;
      harness.events.add(
        const CloudBaseAuthEvent(event: cb.AuthStateChangeEvent.signedOut),
      );
      await Future<void>.delayed(Duration.zero);
      when(() => harness.auth.getSession()).thenAnswer(
        (_) async => cb.SignInRes(error: cb.AuthError(code: 'no_session')),
      );
      passwordSetup.complete(true);
      await Future<void>.delayed(Duration.zero);

      expect(harness.container.read(authNotifierProvider).value, isNull);
      expect(
        harness.container.read(phonePasswordSetupRequiredProvider),
        isFalse,
      );
    },
  );

  test('a startup response after provider disposal is ignored', () async {
    final harness = _Harness();
    final reading = Completer<void>();
    final session = Completer<cb.SignInRes>();
    when(() => harness.auth.getSession()).thenAnswer((_) {
      reading.complete();
      return session.future;
    });
    harness.start();
    await reading.future;
    await harness.dispose();
    session.complete(cb.SignInRes(error: cb.AuthError(code: 'no_session')));
    await Future<void>.delayed(Duration.zero);
  });
}

final _alice = User(
  id: 'alice',
  nickname: '旧昵称',
  createdAt: DateTime.utc(2026),
);

cb.SignInRes _session() => cb.SignInRes(
  data: cb.SignInResData(
    session: cb.Session(
      accessToken: 'alice-session-token',
      user: cb.User(id: 'alice', createdAt: '2026-01-01T00:00:00Z'),
    ),
  ),
);

class _Harness {
  _Harness() {
    when(() => app.auth).thenReturn(auth);
    when(() => datasource.currentUserNeedsPasswordSetup())
        .thenAnswer((_) async => false);
    container = ProviderContainer(
      overrides: [
        useDemoBackendProvider.overrideWithValue(false),
        cloudBaseAppProvider.overrideWithValue(app),
        authRepositoryProvider.overrideWithValue(repository),
        authRemoteDatasourceProvider.overrideWithValue(datasource),
        pushRegistrationProvider.overrideWith(
          (ref) => throw StateError(
            'Push transport intentionally unavailable in this fixture',
          ),
        ),
        cloudBaseAuthStateChangesProvider.overrideWith((ref) => events.stream),
      ],
    );
  }
  final app = _AppMock();
  final auth = _AuthMock();
  final repository = _RepositoryMock();
  final datasource = _DatasourceMock();
  final events = StreamController<CloudBaseAuthEvent>.broadcast();
  late final ProviderContainer container;
  ProviderSubscription<AsyncValue<User?>>? _subscription;

  AuthNotifier start() {
    _subscription = container.listen(authNotifierProvider, (_, _) {});
    return container.read(authNotifierProvider.notifier);
  }

  Future<void> dispose() async {
    _subscription?.close();
    container.dispose();
    await events.close();
  }
}
