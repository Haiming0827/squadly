import 'dart:convert';
import 'dart:io';

import 'package:cloudbase_flutter/cloudbase_flutter.dart' as sdk;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:squadly/app/providers/conversation_cache_lifecycle_provider.dart';
import 'package:squadly/app/providers/conversation_cache_provider.dart';
import 'package:squadly/app/providers/current_user_provider.dart';
import 'package:squadly/app/providers/offline_access_provider.dart';
import 'package:squadly/app/providers/photo_providers.dart';
import 'package:squadly/app/providers/photo_widget_providers.dart';
import 'package:squadly/core/config/cloudbase_config.dart';
import 'package:squadly/core/network/cloudbase_auth_gate.dart';
import 'package:squadly/core/network/cloudbase_client_provider.dart';
import 'package:squadly/core/network/cloudbase_session_identity.dart';
import 'package:squadly/features/auth/data/datasources/cloudbase_offline_session_source.dart';
import 'package:squadly/features/auth/domain/offline_session.dart';
import 'package:squadly/features/photo_widget/data/native_photo_widget_store.dart';
import 'package:squadly/features/photo_widget/data/photo_background_credentials.dart';
import 'package:squadly/features/photo_widget/data/photo_background_renewal.dart';
import 'package:squadly/features/photo_widget/domain/photo_widget.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('VERIFY_SDK_RECOVERY_STAGING');
  const nativeRenewal = bool.fromEnvironment('VERIFY_SDK_NATIVE_RENEWAL');
  const memberPhoto = bool.fromEnvironment('VERIFY_SDK_NATIVE_MEMBER_PHOTO');
  const productionProviders = bool.fromEnvironment(
    'VERIFY_SDK_NATIVE_APP_PROVIDERS',
  );
  testWidgets(
    productionProviders
        ? 'production providers restore SDK and update native photo cache'
        : memberPhoto
        ? 'same ordinary member SDK rotation reaches native photo cache'
        : 'actual SDK refreshes controlled C and PG only receives a valid identity',
    (tester) async {
      expect(!memberPhoto || nativeRenewal, isTrue);
      expect(!productionProviders || memberPhoto, isTrue);
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/sdk-session-staging-fixture.json');
      final output = File('${directory.path}/sdk-session-staging-output.json');
      expect(file.statSync().mode & 0x1ff, 0x180);
      expect(output.statSync().mode & 0x1ff, 0x180);
      final fixture =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      await file.delete();
      expect(fixture['environmentId'], 'squadly-staging-d1fjsdpkc562fa9c');
      expect(fixture['region'], 'ap-shanghai');
      final app = await sdk.CloudBase.init(
        env: fixture['environmentId'] as String,
        region: 'ap-shanghai',
        accessKey: fixture['publishableKey'] as String,
      );
      // The SDK constructor accepts a controlled device ID, avoiding refresh of
      // either main A/B app and avoiding direct access to SDK preference keys.
      final http = sdk.CloudBaseHttpClient(
        app.config,
        fixture['deviceId'] as String,
      );
      final auth = sdk.CloudBaseAuth(app, http);
      http.currentSession = sdk.Session(
        accessToken: fixture['accessToken'] as String,
        refreshToken: fixture['refreshToken'] as String,
        expiresAt: DateTime.now()
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch,
        user: sdk.User(
          id: fixture['userId'] as String,
          createdAt: '2026-01-01T00:00:00Z',
        ),
      );
      final snapshots = <OfflineSession?>[];
      final subscription = CloudBaseOfflineSessionSource(auth)
          .watch()
          .listen(snapshots.add);
      ProviderContainer? container;
      PhotoBackgroundRenewalController? renewal;
      Map<String, Object>? memberPhotoResult;
      const store = NativePhotoWidgetStore();
      try {
        final sdk.SignInRes response;
        if (nativeRenewal) {
          expect(!memberPhoto || fixture['nativeMemberPhoto'] is Map, isTrue);
          final positive = fixture['nativeMemberPhoto'] as Map?;
          final squad = memberPhoto
              ? positive!['squadId'] as String
              : '00000000-0000-4000-8000-000000000001';
          expect(widgetUuid(squad), isTrue);
          if (memberPhoto) {
            expect(widgetUuid(positive!['messageId'] as String), isTrue);
          }
          final scope = await photoWidgetScope(
            PhotoWidgetContext(
              environmentId: fixture['environmentId'] as String,
              userId: fixture['userId'] as String,
              expiresAt: DateTime.now(),
            ),
          );
          final expiry = DateTime.now().add(const Duration(seconds: 1));
          final seeded = await store.synchronize(
            scope: scope,
            expiresAt: expiry,
          );
          final bound = await store.bind(
            lease: seeded.lease!,
            squadId: squad,
            squadName: 'SDK恢复合成验收',
          );
          await store.setPreview(expected: bound, enabled: true);
          final wait =
              expiry.difference(DateTime.now()) +
              const Duration(milliseconds: 30);
          if (wait > Duration.zero) await Future<void>.delayed(wait);
          await store.retainExpired(
            scope: scope,
            expiresAt: productionProviders
                ? DateTime.fromMillisecondsSinceEpoch(
                    http.currentSession!.expiresAt!,
                  )
                : expiry,
          );
          final expiredReference = await store.read();
          final observed = _ObservedRenewalChannel();
          sdk.SignInRes? refreshed;
          var holds = 0;
          if (!productionProviders) {
            renewal = PhotoBackgroundRenewalController(
              channel: observed,
              hold: (_) => holds++,
              release: () async {},
              read: (request, current) async {
                expect(
                  request.scope == scope,
                  isTrue,
                  reason: 'Native scope mismatch; values redacted',
                );
                refreshed = await CloudBaseAuthGate.forAuth(auth)
                    .session(isCurrent: current);
                final session = refreshed?.data?.session;
                if (session == null || !current()) return null;
                final identity = cloudBaseSessionIdentity(session);
                return PhotoBackgroundCredentialMaterial(
                  environmentId: fixture['environmentId'] as String,
                  region: 'ap-shanghai',
                  userId: identity.userId,
                  gateway: Uri.parse(fixture['photoGateway'] as String),
                  accessToken: session.accessToken!,
                  expiresAt: identity.expiresAt,
                );
              },
            );
          }
          final elapsed = Stopwatch()..start();
          final pendingNative = const MethodChannel('squadly/photo-background')
              .invokeMethod<String>('refresh');
          await Future<void>.delayed(const Duration(milliseconds: 100));
          if (productionProviders) {
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.paused,
            );
            container = _productionContainer(app.config, auth, fixture);
            container.listen(conversationCacheLifecycleProvider, (_, _) {});
            container.listen(photoWidgetLifecycleProvider, (_, _) {});
          } else {
            await renewal!.start();
          }
          final outcome = await pendingNative;
          if (productionProviders) {
            // Observe the SDK-owned result without initiating another refresh.
            response = sdk.SignInRes(
              data: sdk.SignInResData(
                session: http.currentSession,
                user: http.currentSession?.user,
              ),
            );
          } else {
            expect(
              observed.committed,
              isTrue,
              reason: 'Native SDK handoff did not accept fresh credential',
            );
            expect(holds, 1);
            expect(refreshed, isNotNull);
            response = refreshed!;
          }
          elapsed.stop();
          if (memberPhoto) {
            expect(outcome, 'newData');
            expect(elapsed.elapsedMilliseconds < 27000, isTrue);
            final shown = await store.read();
            final fresh = cloudBaseSessionIdentity(response.data!.session!);
            expect(
              shown.display == PhotoWidgetDisplay.photo &&
                  shown.messageId == positive!['messageId'],
              isTrue,
              reason: 'Native did not show the expected synthetic photo; values redacted',
            );
            expect(
              shown.binding?.scope == scope &&
                  shown.binding?.squadId == squad &&
                  shown.lease?.generation != expiredReference.lease?.generation,
              isTrue,
              reason:
                  'Native account/binding/generation mismatch; values redacted',
            );
            expect(
              shown.photoExpiresAt != null &&
                  DateTime.now().isBefore(shown.photoExpiresAt!) &&
                  !shown.photoExpiresAt!.isAfter(fresh.expiresAt),
              isTrue,
            );
            expect(
              await const MethodChannel('squadly/photo-background')
                  .invokeMethod<bool>('status'),
              isTrue,
            );
            expect(
              await const MethodChannel('squadly/photo-background')
                  .invokeMethod<String>('refresh'),
              'noData',
            );
            final duplicate = await store.read();
            expect(
              duplicate.photoExpiresAt == shown.photoExpiresAt &&
                  duplicate.lease == shown.lease,
              isTrue,
            );
            if (!productionProviders) {
              expect(
                holds,
                1,
                reason: 'Valid native credential must not renew SDK again',
              );
            }
            expect(
              http.currentSession?.accessToken ==
                  response.data?.session?.accessToken,
              isTrue,
              reason: 'Duplicate native fetch changed the SDK credential; values redacted',
            );
            memberPhotoResult = {
              'passed': false,
              'renewalAndFetchMilliseconds': elapsed.elapsedMilliseconds,
              'duplicateDidNotRenew': true,
              'readCursorUnchanged': false,
            };
          } else {
            // An unrelated synthetic UUID must fail membership before media.
            expect(outcome, 'failed');
            final diagnostics = await const MethodChannel(
              'squadly/photo-background',
            ).invokeMapMethod<String, Object?>('diagnostics');
            expect(diagnostics?['failure'], 'authorization');
            expect(diagnostics?['stage'], 'membership_initial');
            expect((await store.read()).messageId, isNull);
          }
        } else {
          response = await CloudBaseAuthGate.forAuth(auth)
              .session()
              .timeout(const Duration(seconds: 30));
        }
        expect(
          response.isSuccess,
          isTrue,
          reason: 'Controlled refresh must succeed; details redacted',
        );
        final session = response.data?.session;
        expect(session, isNotNull);
        final refreshedClaims = jsonDecode(
          utf8.decode(
            base64Url.decode(
              base64Url.normalize(session!.accessToken!.split('.')[1]),
            ),
          ),
        ) as Map;
        expect(
          ['user', 'authenticated'].contains(refreshedClaims['role']) &&
              refreshedClaims['is_system_admin'] != true,
          isTrue,
          reason: 'Ordinary-user role control failed; values redacted',
        );
        final identity = cloudBaseSessionIdentity(session);
        expect(
          identity.userId == fixture['userId'],
          isTrue,
          reason: 'SDK identity mismatch; values redacted',
        );
        expect(DateTime.now().isBefore(identity.expiresAt), isTrue);
        expect(
          session.accessToken != fixture['accessToken'],
          isTrue,
          reason: 'SDK access token did not rotate; values redacted',
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          snapshots.any(
            (s) =>
                s?.userId == fixture['userId'] && s!.isValidAt(DateTime.now()),
          ),
          isTrue,
        );
        container ??= ProviderContainer(
          overrides: [
            cloudBaseAppProvider.overrideWithValue(app),
            cloudBaseAuthProvider.overrideWithValue(auth),
            cloudBaseConfigProvider.overrideWithValue(
              CloudBaseConfig.fromValues(
                useDemo: 'false',
                environmentId: fixture['environmentId'] as String,
                region: 'ap-shanghai',
                publishableKey: fixture['publishableKey'] as String,
              ),
            ),
          ],
        );
        final reader = container.read(cloudBaseAccessTokenReaderProvider);
        expect(
          await reader() == session.accessToken,
          isTrue,
          reason: 'Reader token mismatch; values redacted',
        );
        final rows = await container
            .read(cloudBasePgRestClientProvider)
            .request<Object?>(
              method: 'GET',
              path: 'profiles',
              queryParameters: {'id': 'eq.${identity.userId}', 'select': 'id'},
            );
        expect(
          rows is List &&
              rows.length == 1 &&
              rows[0] is Map &&
              rows[0]['id'] == fixture['userId'],
          isTrue,
          reason: 'Profile positive control failed; values redacted',
        );
        if (productionProviders) {
          final deadline = DateTime.now().add(const Duration(seconds: 8));
          while (container.read(currentUserProvider).asData?.value?.id !=
                  fixture['userId'] &&
              DateTime.now().isBefore(deadline)) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
          expect(
            container.read(currentUserProvider).asData?.value?.id ==
                fixture['userId'],
            isTrue,
            reason: 'Production AuthNotifier profile restore failed; values redacted',
          );
          expect(
            container.read(offlineAccessProvider).canReadAt(DateTime.now()),
            isTrue,
          );
        }
        if (memberPhoto) {
          final fixturePhoto = fixture['nativeMemberPhoto'] as Map;
          final cursors = await container
              .read(cloudBasePgRestClientProvider)
              .request<Object?>(
                method: 'GET',
                path: 'conversation_read_cursors',
                queryParameters: {
                  'squad_id': 'eq.${fixturePhoto['squadId']}',
                  'select': 'read_message_id',
                },
              );
          expect(
            cursors is List && cursors.isEmpty,
            isTrue,
            reason: 'Native fetch advanced read cursor; values redacted',
          );
          memberPhotoResult!['readCursorUnchanged'] = true;
          memberPhotoResult['passed'] = true;
        }
      } finally {
        // Preserve any genuinely rotated C token even if a later assertion fails.
        final session = http.currentSession;
        if (session?.accessToken != null && session?.refreshToken != null) {
          final claims = jsonDecode(
            utf8.decode(
              base64Url.decode(
                base64Url.normalize(session!.accessToken!.split('.')[1]),
              ),
            ),
          ) as Map;
          if (claims['sub'] == fixture['userId'] &&
              (claims['exp'] as int) * 1000 >
                  DateTime.now().millisecondsSinceEpoch) {
            await output.writeAsString(
              jsonEncode({
                'accessToken': session.accessToken,
                'refreshToken': session.refreshToken,
                'nativeMemberPhoto': ?memberPhotoResult,
                'productionProviderBootstrap': productionProviders,
              }),
              flush: true,
            );
            expect(output.statSync().mode & 0x1ff, 0x180);
          }
        }
        container?.dispose();
        await Future<void>.delayed(Duration.zero);
        await renewal?.dispose();
        if (nativeRenewal) {
          await store.synchronize(scope: null, expiresAt: null);
          await const MethodChannel('squadly/photo-background')
              .invokeMethod<bool>('clear');
        }
        if (productionProviders) {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        }
        await subscription.cancel();
        http.dio.close(force: true);
        app.httpClient.dio.close(force: true);
      }
    },
    skip: !Platform.isIOS || !enabled,
  );
}

class _ObservedRenewalChannel extends MethodChannel {
  _ObservedRenewalChannel() : super('squadly/photo-renewal');
  bool committed = false;
  @override
  Future<T?> invokeMethod<T>(String method, [Object? arguments]) async {
    final result = await super.invokeMethod<T>(method, arguments);
    if (method == 'commit') committed = result == true;
    return result;
  }
}

// Inject only the SDK app boundary. All production consumers see the same real
// Auth instance; no SDK private preferences or second refresh engine is used.
class _BoundCloudBase implements sdk.CloudBase {
  _BoundCloudBase(this.config, this.auth);
  @override
  final sdk.CloudBaseConfig config;
  @override
  final sdk.CloudBaseAuth auth;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unused controlled SDK binding API');
}

ProviderContainer _productionContainer(
  sdk.CloudBaseConfig config,
  sdk.CloudBaseAuth auth,
  Map<String, dynamic> fixture,
) => ProviderContainer(
  overrides: [
    cloudBaseAppProvider.overrideWithValue(_BoundCloudBase(config, auth)),
    useDemoBackendProvider.overrideWithValue(false),
    cloudBaseConfigProvider.overrideWithValue(
      CloudBaseConfig.fromValues(
        useDemo: 'false',
        environmentId: fixture['environmentId'] as String,
        region: 'ap-shanghai',
        publishableKey: fixture['publishableKey'] as String,
      ),
    ),
    offlineSessionSourceProvider.overrideWithValue(
      CloudBaseOfflineSessionSource(auth),
    ),
    conversationCacheProvider.overrideWithValue(null),
    photoGatewayUrlProvider.overrideWithValue(
      Uri.parse(fixture['photoGateway'] as String),
    ),
  ],
);
