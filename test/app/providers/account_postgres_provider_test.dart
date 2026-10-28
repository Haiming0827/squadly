import 'dart:async';

import 'package:cloudbase_flutter/cloudbase_flutter.dart' as cb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:squadly/app/providers/account_postgres_provider.dart';
import 'package:squadly/app/providers/current_user_provider.dart';
import 'package:squadly/core/config/cloudbase_config.dart';
import 'package:squadly/core/network/cloudbase_client_provider.dart';
import 'package:squadly/features/auth/domain/entities/user.dart';

class _CloudBaseMock extends Mock implements cb.CloudBase {}

class _AuthMock extends Mock implements cb.CloudBaseAuth {}

final _identity = StateProvider<AsyncValue<User?>>(
  (ref) => AsyncData(_user('alice')),
);

void main() {
  late _CloudBaseMock app;
  late _AuthMock auth;
  late ProviderContainer container;

  setUp(() {
    app = _CloudBaseMock();
    auth = _AuthMock();
    when(() => app.auth).thenReturn(auth);
    container = ProviderContainer(
      overrides: [
        cloudBaseAppProvider.overrideWithValue(app),
        cloudBaseConfigProvider.overrideWithValue(
          CloudBaseConfig.fromValues(
            useDemo: 'false',
            environmentId: 'squadly-test-123456',
            region: 'ap-shanghai',
            publishableKey: 'test-publishable-key',
          ),
        ),
        currentUserProvider.overrideWith((ref) => ref.watch(_identity)),
      ],
    );
  });
  tearDown(() => container.dispose());

  test(
    'account switch replaces the business client and closes old requests',
    () async {
      final oldClient = container.read(accountPostgresClientProvider);
      final authClient = container.read(cloudBasePostgresClientProvider);
      container.read(_identity.notifier).state = AsyncData(_user('bob'));
      final newClient = container.read(accountPostgresClientProvider);

      expect(identical(newClient, oldClient), isFalse);
      expect(
        identical(container.read(cloudBasePostgresClientProvider), authClient),
        isTrue,
      );
      await expectLater(
        oldClient.rest.rpc('send_text_message'),
        throwsA(isA<http.ClientException>()),
      );
      verifyNever(() => auth.getSession());
    },
  );

  test('refreshes the token while retaining the originating user', () async {
    var token = 'alice-token-1';
    when(() => auth.getSession())
        .thenAnswer((_) async => _session('alice', token));
    final readToken = container.read(accountAccessTokenReaderProvider);

    expect(await readToken(), 'alice-token-1');
    token = 'alice-token-2';
    expect(await readToken(), 'alice-token-2');
  });

  test('rejects the SDK token of a different user', () async {
    when(() => auth.getSession())
        .thenAnswer((_) async => _session('bob', 'bob-token'));

    await expectLater(
      container.read(accountAccessTokenReaderProvider)(),
      throwsA(isA<CloudBaseSessionException>()),
    );
  });

  test('business requests never fall back to an anonymous token', () async {
    when(() => auth.getSession()).thenAnswer(
      (_) async => cb.SignInRes(error: cb.AuthError(code: 'no_session')),
    );

    await expectLater(
      container.read(accountAccessTokenReaderProvider)(),
      throwsA(isA<CloudBaseSessionException>()),
    );
  });

  test('a signed-out app rejects work before querying the SDK', () async {
    container.read(_identity.notifier).state = const AsyncData(null);

    await expectLater(
      container.read(accountAccessTokenReaderProvider)(),
      throwsA(isA<CloudBaseSessionException>()),
    );
    verifyNever(() => auth.getSession());
  });

  for (final returnedUser in ['alice', 'bob']) {
    test(
      'a pending token read cannot outlive an account switch ($returnedUser result)',
      () async {
        final response = Completer<cb.SignInRes>();
        when(() => auth.getSession()).thenAnswer((_) => response.future);
        final originalReader = container.read(accountAccessTokenReaderProvider);
        final pending = originalReader();
        final rejected = expectLater(
          pending,
          throwsA(isA<CloudBaseSessionException>()),
        );

        container.read(_identity.notifier).state = AsyncData(_user('bob'));
        final newReader = container.read(accountAccessTokenReaderProvider);
        expect(identical(newReader, originalReader), isFalse);
        response.complete(_session(returnedUser, '$returnedUser-token'));
        await rejected;

        when(() => auth.getSession())
            .thenAnswer((_) async => _session('bob', 'bob-token'));
        expect(await newReader(), 'bob-token');
        await expectLater(
          originalReader(),
          throwsA(isA<CloudBaseSessionException>()),
        );
      },
    );
  }
}

User _user(String id) =>
    User(id: id, nickname: id, createdAt: DateTime.utc(2026));

cb.SignInRes _session(String id, String token) => cb.SignInRes(
  data: cb.SignInResData(
    session: cb.Session(
      user: cb.User(id: id, createdAt: '2026-01-01T00:00:00Z'),
      accessToken: token,
    ),
  ),
);
