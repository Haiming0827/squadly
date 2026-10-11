import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/activity_import/domain/activity_record.dart';
import 'package:squadly/features/activity_import/domain/activity_source.dart';
import 'package:squadly/features/activity_import/presentation/activity_source_provider.dart';
import 'package:squadly/features/auth/domain/entities/user.dart';
import 'package:squadly/features/auth/presentation/providers/auth_provider.dart';
import 'package:squadly/features/cards/domain/card_composer.dart';
import 'package:squadly/features/cards/presentation/card_composer_screen.dart';
import 'package:squadly/features/conversation/domain/conversation_repository.dart';
import 'package:squadly/features/conversation/domain/timeline_entry.dart';
import 'package:squadly/features/conversation/presentation/conversation_provider.dart';
import 'package:squadly/features/secure_route/data/route_crypto.dart';
import 'package:squadly/features/secure_route/data/route_device_key_store.dart';
import 'package:squadly/features/secure_route/data/route_encryption_service.dart';
import 'package:squadly/features/secure_route/presentation/route_reader_provider.dart';
import 'package:squadly/features/squad/domain/entities/squad_member.dart';
import 'package:squadly/features/squad/presentation/providers/squad_provider.dart';

final class _SignedIn extends AuthNotifier {
  @override
  AsyncValue<User?> build() => AsyncData(
    User(id: 'alice', nickname: '阿青', createdAt: DateTime.utc(2026, 10, 8)),
  );
}

final class _Source implements ActivitySource {
  final record = ActivityRecord(
    id: 'workout-a',
    source: ActivitySourceKind.appleHealth,
    kind: ActivityKind.run,
    startedAt: DateTime(2026, 10, 8, 6),
    utcOffsetMinutes: 480,
    distanceMeters: 5000,
    durationSeconds: 1800,
    sourceLabel: 'Apple Watch',
  );

  @override
  Future<List<ActivityRecord>> listEligibleActivities({
    required DateTime from,
    required DateTime to,
  }) async => [record];

  @override
  Future<ActivityRecord> readActivity(String id) async => record;

  @override
  Future<ActivityRecord> readPreciseRoute(ActivityRecord selected) async =>
      selected.copyWith(
        preciseRoute: const [
          RouteCoordinate(latitude: 31.2, longitude: 121.5),
          RouteCoordinate(latitude: 31.3, longitude: 121.6),
        ],
      );
}

final class _Vault implements RouteSecretVault {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

final class _Directory implements RouteKeyDirectory {
  _Directory(this.bob);

  final RouteDeviceKey bob;
  final devices = <RouteRecipient>[];

  @override
  Future<void> registerDevice(RouteRecipient device) async {
    devices.removeWhere((entry) => entry.deviceId == device.deviceId);
    devices.add(device);
  }

  @override
  Future<List<RouteRecipient>> listRecipients(String squadId) async => [
    ...devices,
    RouteRecipient(
      userId: 'bob',
      deviceId: bob.deviceId,
      publicKeyBase64: bob.publicKeyBase64,
    ),
  ];
}

final class _Conversation implements ConversationRepository {
  final updates = StreamController<void>.broadcast();
  int publishCalls = 0;
  String? cardId;
  CardSnapshot? snapshot;
  EncryptedRouteBundle? route;

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadRecent(
    String squadId,
  ) async => right(const []);

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadAfter(
    String squadId,
    TimelineCursor cursor,
  ) async => right(const []);

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadBefore(
    String squadId,
    TimelineCursor cursor,
  ) async => right(const []);

  @override
  Future<Either<Failure, TimelineEntry>> sendText({
    required String squadId,
    required String body,
    required String clientNonce,
    String? replyToEntryId,
  }) async => left(const Failure.server(message: 'Not used'));

  @override
  Future<Either<Failure, TimelineEntry>> publishCard({
    required String squadId,
    required String cardId,
    required CardSnapshot snapshot,
    required String clientNonce,
    EncryptedRouteBundle? encryptedRoute,
  }) async {
    publishCalls++;
    this.cardId = cardId;
    this.snapshot = snapshot;
    route = encryptedRoute;
    return left(const Failure.server(message: 'Stop before navigation'));
  }

  @override
  Future<Either<Failure, Map<String, String>>> loadMessageTexts({
    required String squadId,
    required List<String> messageIds,
  }) async => right(const {});

  @override
  Stream<void> watchTimeline(String squadId) => updates.stream;
}

void main() {
  testWidgets('route publishing requires per-card and per-device approval', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final crypto = RouteCrypto();
    final bob = await crypto.generateDeviceKey(deviceId: 'bob-phone');
    final directory = _Directory(bob);
    final keyStore = RouteDeviceKeyStore(vault: _Vault(), crypto: crypto);
    final conversation = _Conversation();
    addTearDown(conversation.updates.close);
    final members = [
      SquadMember(
        id: 'membership-a',
        squadId: 'squad-a',
        userId: 'alice',
        role: 'captain',
        joinedAt: DateTime.utc(2026, 10, 8),
        nickname: '阿青',
      ),
      SquadMember(
        id: 'membership-b',
        squadId: 'squad-a',
        userId: 'bob',
        role: 'member',
        joinedAt: DateTime.utc(2026, 10, 8),
        nickname: '阿博',
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_SignedIn.new),
          appleHealthAvailableProvider.overrideWithValue(true),
          appleHealthActivitySourceProvider.overrideWithValue(_Source()),
          squadMembersProvider('squad-a').overrideWith((ref) async => members),
          conversationRepositoryProvider.overrideWithValue(conversation),
          routeDeviceKeyStoreProvider.overrideWithValue(keyStore),
          routeKeyDirectoryProvider.overrideWithValue(directory),
          routeEncryptionServiceProvider.overrideWithValue(
            RouteEncryptionService(
              keyStore: keyStore,
              directory: directory,
              crypto: crypto,
            ),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const CardComposerScreen(squadId: 'squad-a', squadName: '晨跑小队'),
        ),
      ),
    );

    await tester.tap(find.text('从 Apple 健康选择记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('5.00 公里'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('读取这条记录的精确路线'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('读取这条记录的精确路线'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('分享精确轨迹'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('分享精确轨迹'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('预览卡片'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('预览卡片'));
    await tester.pumpAndSettle();
    expect(find.text('本次路线'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('确认发布到小队'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('确认发布到小队'));
    await tester.pumpAndSettle();
    expect(find.textContaining('精确轨迹：已选择'), findsOneWidget);
    expect(conversation.publishCalls, 0);
    await tester.tap(find.text('确认发布'));
    await tester.pumpAndSettle();

    final approve = find.widgetWithText(FilledButton, '已逐台核对并加密');
    expect(tester.widget<FilledButton>(approve).onPressed, isNull);
    expect(find.textContaining('阿博'), findsOneWidget);
    final teammateToggle = find.ancestor(
      of: find.textContaining('阿博'),
      matching: find.byType(CheckboxListTile),
    );
    expect(tester.widget<CheckboxListTile>(teammateToggle).value, isFalse);
    await tester.tap(
      find.descendant(of: teammateToggle, matching: find.byType(Checkbox)),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(teammateToggle).value, isTrue);
    expect(tester.widget<FilledButton>(approve).onPressed, isNotNull);
    await tester.tap(approve);
    await tester.pumpAndSettle();

    expect(conversation.publishCalls, 1);
    expect(conversation.snapshot?.hasEncryptedRoute, isTrue);
    expect(conversation.route, isNotNull);
    expect(jsonEncode(conversation.snapshot!.payload), isNot(contains('31.2')));
    expect(jsonEncode(conversation.route!.toJson()), isNot(contains('31.2')));
    final decoded = await crypto.decryptForMe(
      bundle: conversation.route!,
      squadId: 'squad-a',
      cardId: conversation.cardId!,
      templateVersion: conversation.snapshot!.templateVersion,
      userId: 'bob',
      key: bob,
    );
    expect(decoded, hasLength(2));
    expect(decoded.first.latitude, 31.2);
  });
}
