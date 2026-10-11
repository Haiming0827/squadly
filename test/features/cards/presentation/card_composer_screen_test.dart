import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/activity_import/data/activity_track_file_parser.dart';
import 'package:squadly/features/activity_import/data/gpx_activity_source.dart';
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
import 'package:squadly/features/secure_route/domain/route_models.dart';

void main() {
  testWidgets(
    'manual activity preview does not expose an unselected heart rate',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationRepositoryProvider.overrideWithValue(
              _RetryCardRepository(),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(splashFactory: InkRipple.splashFactory),
            home: const CardComposerScreen(
              squadId: 'squad-a',
              squadName: '晨跑小队',
            ),
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '标题'),
        '今天跑得很轻松',
      );
      await tester.enterText(find.widgetWithText(TextFormField, '距离（公里）'), '5');
      await tester.enterText(
        find.widgetWithText(TextFormField, '时长（分钟）'),
        '30',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '平均心率（可选）'),
        '128',
      );
      expect(find.textContaining('手工补正'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('预览卡片'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('预览卡片'));
      await tester.pumpAndSettle();

      expect(find.text('5.00 km'), findsOneWidget);
      expect(find.text('128 bpm'), findsNothing);
    },
  );

  testWidgets('selected Apple workout populates a local draft', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(
            _RetryCardRepository(),
          ),
          authNotifierProvider.overrideWith(_SignedInAuthNotifier.new),
          appleHealthAvailableProvider.overrideWithValue(true),
          appleHealthActivitySourceProvider.overrideWithValue(_AppleSource()),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const CardComposerScreen(squadId: 'squad-a', squadName: '晨跑小队'),
        ),
      ),
    );
    await tester.tap(find.text('从 Apple 健康选择记录'));
    await tester.pumpAndSettle();
    expect(find.textContaining('5.20 公里'), findsOneWidget);
    await tester.tap(find.textContaining('5.20 公里'));
    await tester.pumpAndSettle();
    expect(find.textContaining('来源：Apple Watch'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('预览卡片'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('预览卡片'));
    await tester.pumpAndSettle();
    expect(find.text('5.20 km'), findsOneWidget);
    expect(find.text('今天的跑步'), findsWidgets);
  });

  testWidgets('GPX file populates a local draft with route sharing off', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(
            _RetryCardRepository(),
          ),
          authNotifierProvider.overrideWith(_SignedInAuthNotifier.new),
          gpxActivitySourceProvider.overrideWithValue(
            GpxActivitySource(gateway: _GpxGateway()),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const CardComposerScreen(squadId: 'squad-a', squadName: '晨跑小队'),
        ),
      ),
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('徒步').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入 GPX／TCX／KML 文件（运动类型按当前选择）'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('0.11 公里'), findsOneWidget);
    await tester.tap(find.textContaining('0.11 公里'));
    await tester.pumpAndSettle();
    expect(find.textContaining('来源：GPX 文件（运动类型手选）'), findsOneWidget);
    expect(find.text('今天的徒步'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('分享精确轨迹'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    var routeToggle = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, '分享精确轨迹'),
    );
    expect(routeToggle.value, isFalse);
    expect(routeToggle.onChanged, isNull);
    await tester.ensureVisible(find.text('读取这条记录的精确路线'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('读取这条记录的精确路线'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('分享精确轨迹'));
    await tester.pumpAndSettle();
    routeToggle = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, '分享精确轨迹'),
    );
    expect(routeToggle.value, isFalse);
    expect(routeToggle.onChanged, isNotNull);
  });

  testWidgets('GPX heart rate is imported but not selected for sharing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(
            _RetryCardRepository(),
          ),
          gpxActivitySourceProvider.overrideWithValue(
            GpxActivitySource(gateway: _GpxGateway(withHeartRate: true)),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const CardComposerScreen(squadId: 'squad-a', squadName: '晨跑小队'),
        ),
      ),
    );
    await tester.tap(find.text('导入 GPX／TCX／KML 文件（运动类型按当前选择）'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('0.11 公里'));
    await tester.pumpAndSettle();

    final heartRate = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, '平均心率（可选）'),
    );
    expect(heartRate.controller?.text, '130');
    final sharing = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, '分享平均心率'),
    );
    expect(sharing.value, isFalse);
  });

  testWidgets('older GPX date can still open the correction date picker', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(
            _RetryCardRepository(),
          ),
          authNotifierProvider.overrideWith(_SignedInAuthNotifier.new),
          gpxActivitySourceProvider.overrideWithValue(
            GpxActivitySource(gateway: _GpxGateway(date: '2001-10-08')),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const CardComposerScreen(squadId: 'squad-a', squadName: '晨跑小队'),
        ),
      ),
    );
    await tester.tap(find.text('导入 GPX／TCX／KML 文件（运动类型按当前选择）'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('0.11 公里'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('运动日期：2001-10-8'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('unchanged card retry keeps card ID and nonce', (tester) async {
    final repository = _RetryCardRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
          authNotifierProvider.overrideWith(_SignedInAuthNotifier.new),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const CardComposerScreen(squadId: 'squad-a', squadName: '晨跑小队'),
        ),
      ),
    );
    await tester.enterText(find.widgetWithText(TextFormField, '标题'), '今晚跑步');
    await tester.enterText(find.widgetWithText(TextFormField, '距离（公里）'), '5');
    await tester.enterText(find.widgetWithText(TextFormField, '时长（分钟）'), '30');
    await tester.scrollUntilVisible(
      find.text('预览卡片'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('预览卡片'));
    await tester.pumpAndSettle();
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.scrollUntilVisible(
        find.text('确认发布到小队'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('确认发布到小队'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认发布'));
      await tester.pumpAndSettle();
      if (attempt == 0) {
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      }
    }
    expect(repository.cardIds, hasLength(2));
    expect(repository.cardIds[0], repository.cardIds[1]);
    expect(repository.nonces[0], repository.nonces[1]);
  });

  testWidgets('edited card after a failed send uses a new card ID', (
    tester,
  ) async {
    final repository = _RetryCardRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
          authNotifierProvider.overrideWith(_SignedInAuthNotifier.new),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const CardComposerScreen(squadId: 'squad-a', squadName: '晨跑小队'),
        ),
      ),
    );
    await tester.enterText(find.widgetWithText(TextFormField, '标题'), '今晚跑步');
    await tester.enterText(find.widgetWithText(TextFormField, '距离（公里）'), '5');
    await tester.enterText(find.widgetWithText(TextFormField, '时长（分钟）'), '30');
    await tester.scrollUntilVisible(
      find.text('预览卡片'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('预览卡片'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('确认发布到小队'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('确认发布到小队'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认发布'));
    await tester.pumpAndSettle();
    expect(repository.cardIds, hasLength(1));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, '标题'), '明早徒步');
    await tester.scrollUntilVisible(
      find.text('预览卡片'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('预览卡片'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('确认发布到小队'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('确认发布到小队'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认发布'));
    await tester.pumpAndSettle();
    expect(repository.cardIds, hasLength(2));
    expect(repository.cardIds[0], isNot(repository.cardIds[1]));
    expect(repository.nonces[0], isNot(repository.nonces[1]));
  });
}

final class _SignedInAuthNotifier extends AuthNotifier {
  @override
  AsyncValue<User?> build() => AsyncData(
    User(id: 'alice', nickname: '阿晴', createdAt: DateTime.utc(2026, 10, 8)),
  );
}

final class _GpxGateway implements GpxFileGateway {
  _GpxGateway({this.date = '2026-10-08', this.withHeartRate = false});

  final String date;
  final bool withHeartRate;

  @override
  Future<ActivityFilePayload?> chooseActivityFile() async {
    var document =
        '''<gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="test">
  <trk><trkseg>
    <trkpt lat="31.0000" lon="121.0000"><time>${date}T06:00:00+08:00</time></trkpt>
    <trkpt lat="31.0010" lon="121.0000"><time>${date}T06:10:00+08:00</time></trkpt>
  </trkseg></trk>
</gpx>''';
    if (withHeartRate) {
      document = document
          .replaceFirst(
            '</time></trkpt>',
            '</time><extensions><TrackPointExtension><hr>120</hr>'
                '</TrackPointExtension></extensions></trkpt>',
          )
          .replaceFirst(
            '</time></trkpt>',
            '</time><extensions><TrackPointExtension><hr>140</hr>'
                '</TrackPointExtension></extensions></trkpt>',
          );
    }
    return ActivityFilePayload(
      bytes: Uint8List.fromList(utf8.encode(document)),
      extension: 'gpx',
    );
  }
}

final class _AppleSource implements ActivitySource {
  final record = ActivityRecord(
    id: 'apple-1',
    source: ActivitySourceKind.appleHealth,
    kind: ActivityKind.run,
    startedAt: DateTime(2026, 10, 8, 6),
    utcOffsetMinutes: 480,
    distanceMeters: 5200,
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
      selected;
}

final class _RetryCardRepository implements ConversationRepository {
  final cardIds = <String>[];
  final nonces = <String>[];

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
    cardIds.add(cardId);
    nonces.add(clientNonce);
    if (cardIds.length == 1) {
      return left(const Failure.network(message: 'Acknowledgement lost'));
    }
    return right(
      TimelineEntry(
        id: 'entry-1',
        squadId: squadId,
        authorId: 'alice',
        authorName: '阿晴',
        kind: TimelineEntryKind.card,
        cardId: cardId,
        cardSnapshot: snapshot,
        clientNonce: clientNonce,
        createdAt: DateTime.utc(2026, 10, 8, 12),
      ),
    );
  }

  @override
  Future<Either<Failure, Map<String, String>>> loadMessageTexts({
    required String squadId,
    required List<String> messageIds,
  }) async => right(const {});

  @override
  Stream<void> watchTimeline(String squadId) => const Stream<void>.empty();
}
