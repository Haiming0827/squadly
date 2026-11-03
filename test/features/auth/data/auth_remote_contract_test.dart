import 'dart:async';

import 'package:cloudbase_flutter/cloudbase_flutter.dart' hide CloudBaseConfig;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:postgrest/postgrest.dart';
import 'package:squadly/core/error/exceptions.dart';
import 'package:squadly/core/network/cloudbase_auth_gate.dart';
import 'package:squadly/features/auth/data/datasources/auth_remote_datasource.dart';

class _CloudBaseMock extends Mock implements CloudBase {}

class _CloudBaseAuthMock extends Mock implements CloudBaseAuth {}

class _SignInWithPasswordReqFake extends Fake
    implements SignInWithPasswordReq {}

class _SignUpReqFake extends Fake implements SignUpReq {}

class _UpdateUserReqFake extends Fake implements UpdateUserReq {}

class _SignInWithOtpReqFake extends Fake implements SignInWithOtpReq {}

void main() {
  setUpAll(() {
    registerFallbackValue(_SignInWithPasswordReqFake());
    registerFallbackValue(_SignUpReqFake());
    registerFallbackValue(_SignInWithOtpReqFake());
    registerFallbackValue(_UpdateUserReqFake());
  });

  test(
    'email signup verifies OTP then saves the requested nickname to profile',
    () async {
      final app = _CloudBaseMock();
      final auth = _CloudBaseAuthMock();
      when(() => app.auth).thenReturn(auth);
      VerifyOtpParams? verifiedParams;
      when(() => auth.signUp(any())).thenAnswer((_) async {
        return SignUpRes(
          data: SignUpResData(
            verifyOtp: (params) async {
              verifiedParams = params;
              return SignInRes(
                data: SignInResData(
                  user: User(
                    id: 'user-a',
                    email: 'a@example.test',
                    createdAt: '2026-10-12T00:00:00Z',
                  ),
                ),
              );
            },
          ),
        );
      });
      when(() => auth.getSession()).thenAnswer(
        (_) async => SignInRes(
          data: SignInResData(
            session: Session(
              user: User(
                id: 'user-a',
                email: 'a@example.test',
                createdAt: '2026-10-12T00:00:00Z',
              ),
            ),
          ),
        ),
      );
      final client = PostgrestClient(
        'https://pg.example.test/v1/rdb/rest',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/v1/rdb/rest/profiles');
          expect(request.url.queryParameters['id'], 'eq.user-a');
          expect(request.method, 'PATCH');
          expect(request.body, contains('"nickname":"阿青"'));
          return http.Response(
            '{"id":"user-a","nickname":"阿青","avatar_url":null,"created_at":"2026-10-12T00:00:00Z"}',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final source = AuthRemoteDatasource(app, client);

      expect(
        await source.signUpWithEmail(
          email: ' a@example.test ',
          password: 'password1',
          nickname: '阿青',
        ),
        isNull,
      );
      final profile = await source.verifyEmailSignup(
        email: 'a@example.test',
        code: ' 123456 ',
      );

      expect(verifiedParams?.token, '123456');
      expect(profile.id, 'user-a');
      expect(profile.nickname, '阿青');
      expect(profile.email, 'a@example.test');
      verify(() => auth.signUp(any(that: isA<SignUpReq>()))).called(1);
    },
  );

  test(
    'password recovery consumes its OTP then closes the temporary session',
    () async {
      final app = _CloudBaseMock();
      final auth = _CloudBaseAuthMock();
      when(() => app.auth).thenReturn(auth);
      UpdateUserAttributes? receivedAttributes;
      when(() => auth.resetPasswordForEmail(any())).thenAnswer((_) async {
        return ResetPasswordForEmailRes(
          data: ResetPasswordForEmailResData(
            updateUser: (attributes) async {
              receivedAttributes = attributes;
              return SignInRes();
            },
          ),
        );
      });
      when(() => auth.getSession()).thenAnswer(
        (_) async => SignInRes(error: AuthError(code: 'no_session')),
      );
      when(() => auth.signOut()).thenAnswer((_) async => SignOutRes());
      final client = PostgrestClient('https://pg.example.test/v1/rdb/rest');
      addTearDown(client.dispose);
      final source = AuthRemoteDatasource(app, client);

      await source.requestPasswordRecovery(email: ' a@example.test ');
      await source.completePasswordRecovery(
        email: 'a@example.test',
        code: ' 123456 ',
        newPassword: 'newPassword1',
      );

      expect(receivedAttributes?.nonce, '123456');
      expect(receivedAttributes?.password, 'newPassword1');
      verify(() => auth.signOut()).called(1);
    },
  );

  test(
    'recovery keeps temporary session private until SDK logout completes',
    () async {
      final app = _CloudBaseMock(), auth = _CloudBaseAuthMock();
      when(() => app.auth).thenReturn(auth);
      final logoutStarted = Completer<void>(),
          logoutRelease = Completer<void>();
      var temporary = false;
      when(() => auth.resetPasswordForEmail(any())).thenAnswer(
        (_) async => ResetPasswordForEmailRes(
          data: ResetPasswordForEmailResData(
            updateUser: (_) async {
              temporary = true;
              return SignInRes();
            },
          ),
        ),
      );
      when(() => auth.getSession()).thenAnswer(
        (_) async => temporary
            ? SignInRes(
                data: SignInResData(
                  session: Session(user: User(id: 'temporary')),
                ),
              )
            : SignInRes(error: AuthError(code: 'no_session')),
      );
      when(() => auth.signOut()).thenAnswer((_) async {
        logoutStarted.complete();
        await logoutRelease.future;
        temporary = false;
        return SignOutRes();
      });
      final pg = PostgrestClient('https://fixture.invalid');
      addTearDown(pg.dispose);
      final source = AuthRemoteDatasource(app, pg);
      await source.requestPasswordRecovery(email: 'fixture@example.test');
      final recovering = source.completePasswordRecovery(
        email: 'fixture@example.test',
        code: '123456',
        newPassword: 'synthetic-password',
      );
      await logoutStarted.future;
      var readFinished = false;
      final reading = CloudBaseAuthGate.forAuth(auth).session().then((value) {
        readFinished = true;
        return value;
      });
      await Future<void>.delayed(Duration.zero);
      expect(readFinished, isFalse);
      logoutRelease.complete();
      await recovering;
      expect((await reading).data?.session, isNull);
    },
  );

  test('recovery checks signed-in state inside the SDK transaction', () async {
    final app = _CloudBaseMock(), auth = _CloudBaseAuthMock();
    when(() => app.auth).thenReturn(auth);
    var verified = false;
    when(() => auth.resetPasswordForEmail(any())).thenAnswer(
      (_) async => ResetPasswordForEmailRes(
        data: ResetPasswordForEmailResData(
          updateUser: (_) async {
            verified = true;
            return SignInRes();
          },
        ),
      ),
    );
    when(() => auth.getSession()).thenAnswer(
      (_) async => SignInRes(
        data: SignInResData(
          session: Session(user: User(id: 'new-login')),
        ),
      ),
    );
    final pg = PostgrestClient('https://fixture.invalid');
    addTearDown(pg.dispose);
    final source = AuthRemoteDatasource(app, pg);
    await source.requestPasswordRecovery(email: 'fixture@example.test');
    final gate = CloudBaseAuthGate.forAuth(auth);
    final blocked = Completer<void>();
    final holding = gate.read(() => blocked.future);
    final recovering = source.completePasswordRecovery(
      email: 'fixture@example.test',
      code: '123456',
      newPassword: 'synthetic-password',
    );
    blocked.complete();
    await holding;
    await expectLater(recovering, throwsA(isA<ServerException>()));
    expect(verified, isFalse);
    verifyNever(() => auth.signOut());
  });

  test(
    'logout discards email-change and password-setup SDK verifiers',
    () async {
      final app = _CloudBaseMock(), auth = _CloudBaseAuthMock();
      when(() => app.auth).thenReturn(auth);
      var emailCalls = 0, passwordCalls = 0;
      when(() => auth.updateUser(any())).thenAnswer(
        (_) async => UpdateUserRes(
          data: UpdateUserResData(
            verifyOtp: (_) async {
              emailCalls++;
              return GetUserRes(error: AuthError(code: 'controlled'));
            },
          ),
        ),
      );
      when(() => auth.reauthenticate()).thenAnswer(
        (_) async => ReauthenticateRes(
          data: ReauthenticateResData(
            updateUser: (_) async {
              passwordCalls++;
              return SignInRes(error: AuthError(code: 'controlled'));
            },
          ),
        ),
      );
      when(() => auth.signOut()).thenAnswer((_) async => SignOutRes());
      final pg = PostgrestClient('https://fixture.invalid');
      addTearDown(pg.dispose);
      final source = AuthRemoteDatasource(app, pg);
      await source.requestEmailChange(email: 'fixture@example.test');
      await source.sendPasswordSetupVerification();
      await source.signOut();
      await expectLater(
        source.verifyEmailChange(code: '123456'),
        throwsA(isA<ServerException>()),
      );
      await expectLater(
        source.setPassword(code: '123456', password: 'synthetic-only'),
        throwsA(isA<ServerException>()),
      );
      expect(
        emailCalls,
        0,
        reason: 'Old email verifier must be discarded at logout',
      );
      expect(
        passwordCalls,
        0,
        reason: 'Old password verifier must be discarded at logout',
      );
    },
  );

  test('email login delegates to CloudBase Auth and maps its error', () async {
    final app = _CloudBaseMock();
    final auth = _CloudBaseAuthMock();
    when(() => app.auth).thenReturn(auth);
    when(() => auth.signInWithPassword(any())).thenAnswer(
      (_) async => SignInRes(error: AuthError(message: 'invalid credentials')),
    );
    final client = PostgrestClient('https://pg.example.test/v1/rdb/rest');
    addTearDown(client.dispose);
    final source = AuthRemoteDatasource(app, client);

    await expectLater(
      source.signInWithEmail(email: '  a@example.test ', password: 'pass12345'),
      throwsA(
        isA<ServerException>().having(
          (error) => error.message,
          'message',
          'invalid credentials',
        ),
      ),
    );
    verify(
      () => auth.signInWithPassword(any(that: isA<SignInWithPasswordReq>())),
    ).called(1);
  });

  test(
    'email signup explains when the CloudBase email provider is disabled',
    () async {
      final app = _CloudBaseMock();
      final auth = _CloudBaseAuthMock();
      when(() => app.auth).thenReturn(auth);
      when(() => auth.signUp(any())).thenAnswer(
        (_) async =>
            SignUpRes(error: AuthError(message: 'provider email not found')),
      );
      final client = PostgrestClient('https://pg.example.test/v1/rdb/rest');
      addTearDown(client.dispose);
      final source = AuthRemoteDatasource(app, client);

      await expectLater(
        source.signUpWithEmail(
          email: 'a@example.test',
          password: 'password1',
          nickname: '阿青',
        ),
        throwsA(
          isA<ServerException>().having(
            (error) => error.message,
            'message',
            contains('未启用邮箱登录'),
          ),
        ),
      );
    },
  );

  test(
    'phone login explains when the CloudBase phone provider is disabled',
    () async {
      final app = _CloudBaseMock();
      final auth = _CloudBaseAuthMock();
      when(() => app.auth).thenReturn(auth);
      when(() => auth.signInWithOtp(any())).thenAnswer(
        (_) async => SignInWithOtpRes(
          error: AuthError(message: '请联系开发者在身份源列表开启手机号验证码登录'),
        ),
      );
      final client = PostgrestClient('https://pg.example.test/v1/rdb/rest');
      addTearDown(client.dispose);
      final source = AuthRemoteDatasource(app, client);

      await expectLater(
        source.sendPhoneVerification(phone: '17816862845'),
        throwsA(
          isA<ServerException>().having(
            (error) => error.message,
            'message',
            allOf(contains('未启用手机号验证码登录'), contains('上海地域')),
          ),
        ),
      );
    },
  );

  test('phone login preserves CloudBase connectivity error details', () async {
    final app = _CloudBaseMock();
    final auth = _CloudBaseAuthMock();
    when(() => app.auth).thenReturn(auth);
    when(() => auth.signInWithOtp(any())).thenAnswer(
      (_) async => SignInWithOtpRes(
        error: AuthError(code: 'unreachable', message: '网络连接失败，请检查网络设置'),
      ),
    );
    final client = PostgrestClient('https://pg.example.test/v1/rdb/rest');
    addTearDown(client.dispose);
    final source = AuthRemoteDatasource(app, client);

    await expectLater(
      source.sendPhoneVerification(phone: '17816862845'),
      throwsA(
        isA<ServerException>()
            .having(
              (error) => error.message,
              'message',
              allOf(
                contains('连接 CloudBase 验证服务失败'),
                contains('网络连接失败，请检查网络设置'),
                contains('unreachable'),
              ),
            )
            .having((error) => error.statusCode, 'statusCode', isNull),
      ),
    );
  });

  test(
    'phone signup reports that a newly created account needs a password',
    () async {
      final app = _CloudBaseMock();
      final auth = _CloudBaseAuthMock();
      final authUser = User(
        id: 'phone-user',
        phone: '+8617816862845',
        userMetadata: UserMetadata(hasPassword: false),
      );
      when(() => app.auth).thenReturn(auth);
      when(() => auth.signInWithOtp(any())).thenAnswer(
        (_) async => SignInWithOtpRes(
          data: SignInWithOtpResData(
            verifyOtp: (_) async =>
                SignInRes(data: SignInResData(user: authUser)),
          ),
        ),
      );
      when(() => auth.getUser()).thenAnswer(
        (_) async => GetUserRes(data: GetUserResData(user: authUser)),
      );
      final client = PostgrestClient(
        'https://pg.example.test/v1/rdb/rest',
        httpClient: MockClient((request) async {
          return http.Response(
            '{"id":"phone-user","nickname":"新成员","created_at":"2026-10-15T00:00:00Z"}',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final source = AuthRemoteDatasource(app, client);

      await source.sendPhoneVerification(phone: '17816862845');
      final (_, needsPasswordSetup) = await source.verifyPhoneCode(
        phone: '17816862845',
        code: '123456',
      );

      expect(needsPasswordSetup, isTrue);
    },
  );

  test(
    'Apple login fails closed until CloudBase supports nonce validation',
    () {
      final source = AuthRemoteDatasource(
        _CloudBaseMock(),
        PostgrestClient('https://pg.example.test/v1/rdb/rest'),
      );
      expect(source.signInWithApple(), throwsA(isA<ServerException>()));
    },
  );
}
