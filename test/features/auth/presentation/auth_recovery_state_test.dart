import 'dart:async';

import 'package:cloudbase_flutter/cloudbase_flutter.dart' hide CloudBaseConfig;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/core/network/cloudbase_client_provider.dart';
import 'package:squadly/features/auth/domain/entities/user.dart' as domain;
import 'package:squadly/features/auth/domain/repositories/auth_repository.dart';
import 'package:squadly/features/auth/presentation/providers/auth_provider.dart';

class _CloudBaseMock extends Mock implements CloudBase {}

class _CloudBaseAuthMock extends Mock implements CloudBaseAuth {}

class _AuthRepositoryMock extends Mock implements AuthRepository {}

void main() {
  test(
    'a missing CloudBase session leaves the login state signed out',
    () async {
      final authEvents = StreamController<CloudBaseAuthEvent>.broadcast();
      final app = _CloudBaseMock();
      final auth = _CloudBaseAuthMock();
      final repository = _AuthRepositoryMock();
      when(() => app.auth).thenReturn(auth);
      when(() => auth.getSession()).thenAnswer(
        (_) async => SignInRes(error: AuthError(code: 'no_session')),
      );
      final container = ProviderContainer(
        overrides: [
          useDemoBackendProvider.overrideWithValue(false),
          cloudBaseAppProvider.overrideWithValue(app),
          authRepositoryProvider.overrideWithValue(repository),
          cloudBaseAuthStateChangesProvider.overrideWith(
            (ref) => authEvents.stream,
          ),
        ],
      );
      addTearDown(authEvents.close);
      addTearDown(container.dispose);
      final subscription = container.listen(authNotifierProvider, (_, _) {});
      addTearDown(subscription.close);

      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(container.read(authNotifierProvider).value, isNull);
      expect(container.read(authNotifierProvider).hasError, isFalse);
    },
  );

  test(
    'late profile response cannot revive a signed-out CloudBase user',
    () async {
      final profileStarted = Completer<void>();
      final releaseProfile = Completer<Either<Failure, domain.User>>();
      final authEvents = StreamController<CloudBaseAuthEvent>.broadcast();
      final app = _CloudBaseMock();
      final auth = _CloudBaseAuthMock();
      final repository = _AuthRepositoryMock();
      var sessionReads = 0;

      when(() => app.auth).thenReturn(auth);
      when(() => auth.getSession()).thenAnswer((_) async {
        sessionReads++;
        return SignInRes(
          data: SignInResData(
            session: sessionReads == 1
                ? Session(accessToken: 'temporary-token')
                : null,
          ),
        );
      });
      when(() => repository.getCurrentUser()).thenAnswer((_) {
        profileStarted.complete();
        return releaseProfile.future;
      });
      final container = ProviderContainer(
        overrides: [
          useDemoBackendProvider.overrideWithValue(false),
          cloudBaseAppProvider.overrideWithValue(app),
          cloudBaseAuthStateChangesProvider.overrideWith(
            (ref) => authEvents.stream,
          ),
          authRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(authEvents.close);
      addTearDown(container.dispose);
      final subscription = container.listen(authNotifierProvider, (_, _) {});
      addTearDown(subscription.close);

      await profileStarted.future.timeout(const Duration(seconds: 3));
      authEvents.add(
        const CloudBaseAuthEvent(event: AuthStateChangeEvent.signedOut),
      );
      await Future<void>.delayed(Duration.zero);
      releaseProfile.complete(
        Right(
          domain.User(
            id: 'user-a',
            nickname: '阿青',
            createdAt: DateTime.utc(2026, 10, 8),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(container.read(authNotifierProvider).value, isNull);
    },
  );
}
