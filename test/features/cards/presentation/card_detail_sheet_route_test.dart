import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/auth/domain/entities/user.dart';
import 'package:squadly/features/auth/presentation/providers/auth_provider.dart';
import 'package:squadly/features/cards/domain/card_composer.dart';
import 'package:squadly/features/cards/domain/device_image_share.dart';
import 'package:squadly/features/cards/presentation/card_detail_sheet.dart';
import 'package:squadly/features/conversation/domain/timeline_entry.dart';
import 'package:squadly/features/secure_route/domain/route_models.dart';
import 'package:squadly/features/secure_route/domain/route_reader.dart';
import 'package:squadly/features/secure_route/presentation/route_reader_provider.dart';

final class _SignedIn extends AuthNotifier {
  @override
  AsyncValue<User?> build() => AsyncData(
    User(id: 'alice', nickname: '阿青', createdAt: DateTime.utc(2026, 10, 8)),
  );
}

final class _RouteReader implements RouteReader {
  _RouteReader({this.fail = false});

  final bool fail;

  @override
  Future<List<RouteCoordinate>> loadForMe({
    required String squadId,
    required String cardId,
    required int templateVersion,
    required String userId,
  }) async {
    if (fail) throw const RouteKeyMissing();
    expect(squadId, 'squad-a');
    expect(cardId, 'card-a');
    expect(userId, 'alice');
    return const [
      RouteCoordinate(latitude: 31.2, longitude: 121.5),
      RouteCoordinate(latitude: 31.3, longitude: 121.6),
    ];
  }
}

final class _DeviceImageShare implements DeviceImageShare {
  Uint8List? savedImage;
  Uint8List? sharedImage;
  ShareOutcome shareOutcome = ShareOutcome.selectedTarget;

  @override
  Future<void> saveImage(Uint8List pngBytes) async {
    savedImage = pngBytes;
  }

  @override
  Future<ShareOutcome> shareImage(Uint8List pngBytes) async {
    sharedImage = pngBytes;
    return shareOutcome;
  }
}

TimelineEntry _entry() => TimelineEntry(
  id: 'entry-a',
  squadId: 'squad-a',
  authorId: 'alice',
  authorName: '阿青',
  kind: TimelineEntryKind.card,
  cardId: 'card-a',
  cardSnapshot: CardSnapshot(
    kind: CardKind.activity,
    payload: const {
      'activity_type': 'run',
      'date': '2026-10-08',
      'distance_m': 5000,
      'duration_s': 1800,
      'pace_s_per_km': 360,
      'title': '晨跑',
    },
    hasEncryptedRoute: true,
  ),
  clientNonce: 'nonce-a',
  createdAt: DateTime.utc(2026, 10, 8),
);

void main() {
  testWidgets('saves rendered card PNG to the local photo adapter', (
    tester,
  ) async {
    final imageShare = _DeviceImageShare();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_SignedIn.new),
          routeReaderProvider.overrideWithValue(_RouteReader()),
          deviceImageShareProvider.overrideWithValue(imageShare),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Scaffold(
            body: CardDetailSheet(
              squadId: 'squad-a',
              squadName: '晨跑小队',
              entry: _entry(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final save = tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '存到相册'))
        .onPressed!;
    await tester.runAsync(() async => save());
    await tester.pumpAndSettle();

    expect(imageShare.savedImage, isNotNull);
    expect(imageShare.savedImage!.take(8), [
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
    ]);
    expect(find.text('图片已保存到相册'), findsOneWidget);
  });

  testWidgets('hands a local PNG to system share without claiming receipt', (
    tester,
  ) async {
    final imageShare = _DeviceImageShare();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_SignedIn.new),
          routeReaderProvider.overrideWithValue(_RouteReader()),
          deviceImageShareProvider.overrideWithValue(imageShare),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Scaffold(
            body: CardDetailSheet(
              squadId: 'squad-a',
              squadName: '晨跑小队',
              entry: _entry(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final share = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, '转发图片'))
        .onPressed!;
    await tester.runAsync(() async => share());
    await tester.pumpAndSettle();

    expect(imageShare.sharedImage, isNotNull);
    expect(imageShare.sharedImage!.take(8), [
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
    ]);
    expect(find.textContaining('已发送至微信'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('decrypts route locally before enabling image export', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_SignedIn.new),
          routeReaderProvider.overrideWithValue(_RouteReader()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CardDetailSheet(
              squadId: 'squad-a',
              squadName: '晨跑小队',
              entry: _entry(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本次路线'), findsOneWidget);
    final save = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '存到相册'),
    );
    expect(save.onPressed, isNotNull);
  });

  testWidgets('lost key explains failure and blocks incomplete export', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_SignedIn.new),
          routeReaderProvider.overrideWithValue(_RouteReader(fail: true)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CardDetailSheet(
              squadId: 'squad-a',
              squadName: '晨跑小队',
              entry: _entry(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('没有这张卡的历史路线密钥'), findsOneWidget);
    expect(find.text('本次路线'), findsNothing);
    final save = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '存到相册'),
    );
    expect(save.onPressed, isNull);
  });
}
