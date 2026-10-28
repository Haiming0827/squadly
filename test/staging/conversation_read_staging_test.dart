import 'dart:convert';
import 'dart:io';

import 'package:cloudbase_flutter/cloudbase_flutter.dart' as sdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squadly/core/config/cloudbase_config.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/core/network/cloudbase_postgres_client.dart';
import 'package:squadly/features/auth/data/datasources/cloudbase_offline_session_source.dart';
import 'package:squadly/features/conversation/data/cloudbase_conversation_read_repository.dart';
import 'package:squadly/features/conversation/domain/conversation_target.dart';
import 'package:squadly/features/conversation/domain/message_read_receipt.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'staging SDK refresh and real read-receipt repositories',
    () async {
      // This explicitly requested live test uses real HTTPS and isolated preference
      // storage. Tokens are read at runtime and never embedded in an APK.
      final previousHttpOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = previousHttpOverrides);
      final file = File(
        Platform.environment['SQUADLY_STAGING_CONFIG'] ??
            'config/cloudbase-access.local.json',
      );
      expect(
        file.statSync().mode & 0x1ff,
        0x180,
        reason: 'Session config must be 0600',
      );
      final config =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect(
        config['environmentId'] == 'squadly-staging-d1fjsdpkc562fa9c',
        isTrue,
      );
      final actors = config['actors'] as Map<String, dynamic>;
      final fixture = config['readReceiptAcceptance'] as Map<String, dynamic>;
      expect(
        RegExp(r'^[0-9a-f]{12}$').hasMatch(fixture['runId'] as String),
        isTrue,
      );
      expect(actors['a']['userId'] != actors['b']['userId'], isTrue);
      final apps = <String, sdk.CloudBase>{};
      for (final name in ['a', 'b']) {
        final actor = actors[name] as Map<String, dynamic>;
        final deviceId = actor['deviceId'] as String;
        expect(deviceId.isNotEmpty, isTrue);
        SharedPreferences.setMockInitialValues({'device_id': deviceId});
        final app = await sdk.CloudBase.init(
          env: config['environmentId'] as String,
          region: config['region'] as String,
          accessKey: config['publishableKey'] as String,
        );
        addTearDown(() => app.httpClient.dio.close(force: true));
        final result = await app.auth.refreshSession(
          actor['refresh_token'] as String,
        );
        expect(
          result.isSuccess,
          isTrue,
          reason: 'SDK refresh must succeed for $name',
        );
        final session = result.data?.session;
        expect(session?.user?.id == actor['userId'], isTrue);
        expect(session?.user?.email == actor['email'], isTrue);
        expect(session?.accessToken?.isNotEmpty, isTrue);
        expect(session?.refreshToken?.isNotEmpty, isTrue);
        actor['jwt'] = session!.accessToken;
        actor['refresh_token'] = session.refreshToken;
        actor['expires_in'] = session.expiresIn;
        actor['authenticatedAt'] =
            DateTime.now().millisecondsSinceEpoch ~/ 1000;
        actor['deviceId'] = deviceId;
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(config),
        );
        final current = await app.auth.getUser();
        expect(
          current.isSuccess && current.data?.user?.id == actor['userId'],
          isTrue,
        );
        final offline = offlineSessionFromSdk(session);
        expect(
          offline.userId == actor['userId'] &&
              offline.isValidAt(DateTime.now()),
          isTrue,
          reason: 'Real SDK session must have a matching identity and unexpired absolute deadline',
        );
        apps[name] = app;
      }
      final repositories = <String, CloudBaseConversationReadRepository>{};
      for (final name in ['a', 'b']) {
        final app = apps[name]!;
        final client = CloudBasePostgresClient(
          config: CloudBaseConfig.fromValues(
            environmentId: config['environmentId'] as String,
            region: config['region'] as String,
            publishableKey: config['publishableKey'] as String,
            useDemo: 'false',
          ),
          accessTokenReader: () async =>
              (await app.auth.getSession()).data?.session?.accessToken,
        );
        addTearDown(client.close);
        repositories[name] = CloudBaseConversationReadRepository(client.rest);
      }
      final ownerClient = CloudBasePostgresClient(
        config: CloudBaseConfig.fromValues(
          useDemo: 'false',
          environmentId: config['environmentId'] as String,
          region: config['region'] as String,
          publishableKey: config['publishableKey'] as String,
        ),
        accessTokenReader: () async =>
            (await apps['a']!.auth.getSession()).data?.session?.accessToken,
      );
      addTearDown(ownerClient.close);
      final squadRows = await ownerClient.rest
          .from('squads')
          .select('name,created_by')
          .eq('id', fixture['memberSquad'] as String);
      expect(squadRows.length == 1, isTrue);
      expect(squadRows.single['name'] == '验收测试-已读-${fixture['runId']}', isTrue);
      expect(squadRows.single['created_by'] == actors['a']['userId'], isTrue);
      final target = ConversationTarget(
        squadId: fixture['memberSquad'] as String,
      );
      final message = fixture['latestMessages']['general_after_plan'] as String;
      final denied = await repositories['b']!.loadForMessages(
        target: target,
        messageIds: [message],
      );
      expect(
        denied.match(
          (failure) => failure is PermissionDeniedFailure,
          (_) => false,
        ),
        isTrue,
      );
      final advance = await repositories['b']!.advance(
        target: target,
        messageId: message,
      );
      expect(advance.isRight(), isTrue);
      final visible = await repositories['a']!.loadForMessages(
        target: target,
        messageIds: [message],
      );
      final rows = visible.getOrElse((_) => []);
      expect(rows.length == 1, isTrue);
      expect(rows.single.members.length == 1, isTrue);
      expect(
        rows.single.members.single.userId == actors['b']['userId'],
        isTrue,
      );
      expect(
        rows.single.members.single.status == ConversationReadStatus.read,
        isTrue,
      );
      await File(
        Platform.environment['SQUADLY_STAGING_REPORT'] ??
            '/tmp/squadly-staging-sdk-read-checks.json',
      ).writeAsString(
        jsonEncode({
          'passed': true,
          'checks': [
            'a_sdk_refresh_identity',
            'b_sdk_refresh_identity',
            'a_offline_session_absolute_expiry',
            'b_offline_session_absolute_expiry',
            'non_author_repository_permission_mapping',
            'reader_repository_advance',
            'author_repository_read_projection',
          ],
          'notVerified': [
            'device_foreground_visibility',
            'third_account_leave_rejoin',
          ],
        }),
      );
    },
    skip: Platform.environment['SQUADLY_RUN_STAGING_READ'] != 'true',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
