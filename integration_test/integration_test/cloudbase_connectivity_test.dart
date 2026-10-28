import 'dart:convert';
import 'dart:io';

import 'package:cloudbase_flutter/cloudbase_flutter.dart' as cb;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:squadly/core/config/cloudbase_config.dart';

/// Opt-in network probe. Invalid/missing recipients cannot trigger an SMS.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('RUN_CLOUDBASE_NETWORK_PROBE');

  testWidgets('CloudBase verification endpoint responds without a recipient', (
    tester,
  ) async {
    final config = CloudBaseConfig.fromEnvironment();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    addTearDown(() => client.close(force: true));
    final watch = Stopwatch()..start();
    var stage = 'DNS';
    try {
      final addresses = await InternetAddress.lookup(
        Uri.parse(config.apiBaseUrl).host,
      ).timeout(const Duration(seconds: 5));
      debugPrint(
        '[cloudbase-connectivity] DNS families: '
        '${addresses.map((address) => address.type.name).toList()}',
      );
      stage = 'HTTPS connect';
      final request = await client
          .postUrl(
            Uri.parse('${config.apiBaseUrl}/auth/v1/verification')
                .replace(queryParameters: {'client_id': config.environmentId}),
          )
          .timeout(const Duration(seconds: 8));
      request.headers.contentType = ContentType.json;
      request.write('{}');
      stage = 'verification response';
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      await response.drain<void>().timeout(const Duration(seconds: 5));
      debugPrint(
        '[cloudbase-connectivity] HTTP ${response.statusCode} '
        'in ${watch.elapsedMilliseconds}ms',
      );
      expect(response.statusCode, 400);
    } catch (error) {
      debugPrint(
        '[cloudbase-connectivity] failed at $stage '
        'after ${watch.elapsedMilliseconds}ms: ${error.runtimeType}',
      );
      rethrow;
    }
  }, skip: !enabled);

  testWidgets('CloudBase OTP SDK rejects invalid recipient without timeout', (
    tester,
  ) async {
    final config = CloudBaseConfig.fromEnvironment();
    final app = await cb.CloudBase.init(
      env: config.environmentId,
      region: config.region,
      accessKey: config.publishableKey,
    );
    addTearDown(() => app.httpClient.dio.close(force: true));
    final watch = Stopwatch()..start();
    final response = await app.auth.signInWithOtp(
      cb.SignInWithOtpReq(phone: 'invalid'),
    );
    debugPrint(
      '[cloudbase-connectivity] SDK result: '
      '${jsonEncode({'code': response.error?.code, 'status': response.error?.status})} '
      'in ${watch.elapsedMilliseconds}ms',
    );
    expect(response.isSuccess, isFalse);
    expect(response.error?.code, 'INVALID_ARGUMENT');
    expect(response.error?.status, 400);
  }, skip: !enabled);
}
