import 'package:cloudbase_flutter/cloudbase_flutter.dart' hide CloudBaseConfig;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:squadly/core/config/cloudbase_config.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/core/network/cloudbase_client_provider.dart';
import 'package:squadly/core/network/cloudbase_postgres_client.dart';
import 'package:squadly/features/auth/presentation/providers/auth_provider.dart';

class _CloudBaseMock extends Mock implements CloudBase {}

class _CloudBaseAuthMock extends Mock implements CloudBaseAuth {}

class _SignInWithOtpReqFake extends Fake implements SignInWithOtpReq {}

void main() {
  setUpAll(() {
    registerFallbackValue(_SignInWithOtpReqFake());
  });

  test(
    'keeps the phone verification callback after auth repository auto-disposes',
    () async {
      final app = _CloudBaseMock();
      final auth = _CloudBaseAuthMock();
      var verifiedCode = '';
      when(() => app.auth).thenReturn(auth);
      when(() => auth.getSession()).thenAnswer(
        (_) async => SignInRes(error: AuthError(code: 'no_session')),
      );
      when(() => auth.signInWithOtp(any())).thenAnswer((_) async {
        return SignInWithOtpRes(
          data: SignInWithOtpResData(
            verifyOtp: (params) async {
              verifiedCode = params.token;
              return SignInRes(error: AuthError(message: 'invalid otp'));
            },
          ),
        );
      });
      final postgres = CloudBasePostgresClient(
        config: CloudBaseConfig.fromValues(
          useDemo: 'false',
          environmentId: 'squadly-test-123456',
          region: 'ap-shanghai',
          publishableKey: 'public-publishable-key-for-tests',
        ),
        accessTokenReader: () async => null,
        httpClient: MockClient(
          (_) async => throw StateError('unexpected HTTP'),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          useDemoBackendProvider.overrideWithValue(false),
          cloudBaseAppProvider.overrideWithValue(app),
          cloudBasePostgresClientProvider.overrideWithValue(postgres),
          cloudBaseAuthStateChangesProvider.overrideWith(
            (ref) => const Stream.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(postgres.close);
      final subscription = container.listen(authNotifierProvider, (_, _) {});
      addTearDown(subscription.close);

      expect(container.read(authNotifierProvider), isA<AsyncData<dynamic>>());

      await Future<void>.delayed(const Duration(milliseconds: 30));
      final notifier = container.read(authNotifierProvider.notifier);
      expect(
        await notifier.sendPhoneVerification(phone: '17816862845'),
        isTrue,
      );

      // A frame boundary lets the auto-dispose repository/data-source providers
      // be collected between the send-code and verify-code user actions.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await notifier.verifyPhoneCode(phone: '17816862845', code: '192348');

      expect(verifiedCode, '192348');
      final state = container.read(authNotifierProvider);
      expect(state, isA<AsyncError<dynamic>>());
      expect(authFailureMessage(state.error! as Failure), 'invalid otp');
    },
  );
}
