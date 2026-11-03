import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloudbase_flutter/cloudbase_flutter.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:postgrest/postgrest.dart' show PostgrestClient;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squadly/core/network/cloudbase_auth_gate.dart';
import 'package:squadly/core/network/cloudbase_client_provider.dart';
import 'package:squadly/features/auth/data/datasources/auth_remote_datasource.dart';

import 'cloudbase_session_reader_test.dart' show jwt;

final class RacingSdkTransport implements HttpClientAdapter {
  final started = Completer<void>();
  final release = Completer<void>();
  final calls = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelled,
  ) async {
    calls.add(options.path);
    Object body = {};
    if (options.path == '/auth/v1/token') {
      started.complete();
      await release.future;
      body = {
        'access_token': jwt(DateTime.now().add(const Duration(hours: 1))),
        'refresh_token': 'synthetic-next-refresh',
        'expires_in': 3600,
      };
    } else if (options.path == '/auth/v1/signin') {
      String encode(Object v) =>
          base64UrlEncode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
      body = {
        'access_token':
            '${encode({'alg': 'RS256'})}.${encode({'sub': 'fixture-b', 'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000})}.${base64UrlEncode(List.filled(32, 42)).replaceAll('=', '')}',
        'refresh_token': 'synthetic-b-refresh',
        'expires_in': 3600,
      };
    } else if (options.path == '/auth/v1/user/me') {
      final token = (options.headers['Authorization'] as String).substring(7);
      body = {
        'sub': (jsonDecode(
          utf8.decode(
            base64Url.decode(base64Url.normalize(token.split('.')[1])),
          ),
        ) as Map)['sub'],
      };
    } else if (options.path != '/auth/v1/revoke') {
      throw StateError('Unexpected SDK request');
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('late SDK refresh cannot revive a session after app logout', () async {
    SharedPreferences.setMockInitialValues({});
    final app = await CloudBase.init(
      env: 'fixture-env',
      region: 'ap-shanghai',
      accessKey: 'fixture-publishable-key-00000',
    );
    final old = DateTime.now().subtract(const Duration(hours: 1));
    app.httpClient.currentSession = Session(
      accessToken: jwt(old),
      refreshToken: 'synthetic-refresh',
      expiresAt: old.millisecondsSinceEpoch,
      user: User(id: 'fixture-a', createdAt: '2026-01-01T00:00:00Z'),
    );
    final adapter = RacingSdkTransport();
    app.httpClient.dio.httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [cloudBaseAppProvider.overrideWithValue(app)],
    );
    addTearDown(container.dispose);
    final pg = PostgrestClient('https://fixture.invalid');
    addTearDown(pg.dispose);
    final datasource = AuthRemoteDatasource(app, pg);
    final reading = container
        .read(cloudBaseAccessTokenReaderProvider)()
        .catchError((Object _) => null);
    await adapter.started.future;
    final leaving = datasource.signOut();
    await Future<void>.delayed(Duration.zero);
    adapter.release.complete();
    expect(
      await reading,
      isNull,
      reason: 'Superseded token must not leave the reader',
    );
    await leaving;
    expect(
      app.httpClient.currentSession == null,
      isTrue,
      reason: 'A completed app logout must remain signed out after the earlier SDK refresh finishes',
    );
  });
  test(
    'new login remains authoritative after an earlier SDK refresh',
    () async {
      SharedPreferences.setMockInitialValues({});
      final app = await CloudBase.init(
        env: 'fixture-env',
        region: 'ap-shanghai',
        accessKey: 'fixture-publishable-key-00000',
      );
      final old = DateTime.now().subtract(const Duration(hours: 1));
      app.httpClient.currentSession = Session(
        accessToken: jwt(old),
        refreshToken: 'synthetic-refresh',
        expiresAt: old.millisecondsSinceEpoch,
        user: User(id: 'fixture-a', createdAt: '2026-01-01T00:00:00Z'),
      );
      final adapter = RacingSdkTransport();
      app.httpClient.dio.httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [cloudBaseAppProvider.overrideWithValue(app)],
      );
      addTearDown(container.dispose);
      final pg = PostgrestClient(
        'https://fixture.invalid',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'id': 'fixture-b',
              'nickname': '合成B',
              'created_at': '2026-01-01T00:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      addTearDown(pg.dispose);
      final reading = container
          .read(cloudBaseAccessTokenReaderProvider)()
          .catchError((Object _) => null);
      await adapter.started.future;
      Future<SignInRes>? listenerReading;
      final subscription = app.auth
          .onAuthStateChange((event, session, info) {
            if (event == AuthStateChangeEvent.signedIn) {
              listenerReading = CloudBaseAuthGate.forAuth(app.auth).session();
            }
          })
          .data
          ?.subscription;
      addTearDown(() => subscription?.unsubscribe());
      final signingIn = AuthRemoteDatasource(
        app,
        pg,
      ).signInWithEmail(email: 'b@example.test', password: 'synthetic-only');
      final nextReading = container.read(cloudBaseAccessTokenReaderProvider)();
      await Future<void>.delayed(Duration.zero);
      adapter.release.complete();
      expect(await reading, isNull);
      final user = await signingIn;
      expect(user.id, 'fixture-b');
      expect(app.httpClient.currentSession?.user?.id, 'fixture-b');
      expect(await nextReading, app.httpClient.currentSession?.accessToken);
      expect(listenerReading, isNotNull);
      expect(
        (await listenerReading!.timeout(const Duration(seconds: 2)))
            .data
            ?.session
            ?.user
            ?.id,
        'fixture-b',
      );
    },
  );
  test(
    'same-epoch SDK session reads coalesce and stale queued reads are skipped',
    () async {
      final auth = _Auth();
      final gate = CloudBaseAuthGate.forAuth(auth);
      final response = Completer<SignInRes>();
      when(() => auth.getSession()).thenAnswer((_) => response.future);
      final first = gate.session(), second = gate.session();
      expect(identical(first, second), isTrue);
      await Future<void>.delayed(Duration.zero);
      verify(() => auth.getSession()).called(1);
      response.complete(SignInRes(data: SignInResData()));
      await first;
      final blocked = Completer<void>();
      final waiting = gate.read(() => blocked.future);
      var active = true;
      final queued = gate.session(isCurrent: () => active);
      active = false;
      blocked.complete();
      await waiting;
      expect((await queued).error?.code, 'session_changed');
      verifyNoMoreInteractions(auth);
    },
  );
  test(
    'caller timeout does not release the SDK before its actual completion',
    () async {
      final auth = _Auth();
      final gate = CloudBaseAuthGate.forAuth(auth);
      final response = Completer<SignInRes>();
      when(() => auth.getSession()).thenAnswer((_) => response.future);
      final reading = gate.session();
      await expectLater(
        reading.timeout(const Duration(milliseconds: 1)),
        throwsA(isA<TimeoutException>()),
      );
      var mutated = false;
      final mutation = gate.mutate(() async {
        mutated = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(mutated, isFalse);
      response.complete(SignInRes(data: SignInResData()));
      await mutation;
      expect(mutated, isTrue);
      expect((await reading).error?.code, 'session_changed');
    },
  );
  test(
    'SDK failures leave the queue usable and instances remain independent',
    () async {
      final a = CloudBaseAuthGate.forAuth(_Auth()),
          b = CloudBaseAuthGate.forAuth(_Auth());
      final stuck = Completer<void>();
      final holding = a.read(() => stuck.future);
      expect(await b.read(() async => 7), 7);
      stuck.complete();
      await holding;
      await expectLater(
        a.mutate(() async => throw StateError('controlled')),
        throwsStateError,
      );
      expect(await a.read(() async => 9), 9);
    },
  );
}

class _Auth extends Mock implements CloudBaseAuth {}
