import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:squadly/app/providers/photo_widget_providers.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/conversation/domain/photo_head.dart';
import 'package:squadly/features/conversation/domain/timeline_entry.dart';
import 'package:squadly/features/photo_widget/domain/photo_widget.dart';
import 'package:squadly/features/photo_widget/domain/photo_widget_service.dart';
import 'package:squadly/features/photo_widget/presentation/photo_widget_entry_screen.dart';
import 'package:squadly/features/photo_widget/presentation/photo_widget_settings_screen.dart';
import 'package:squadly/features/photos/domain/photo.dart';
import 'package:squadly/features/squad/domain/entities/squad.dart';

const squadId = '00000000-0000-4000-8000-000000000001';
const bindingId = '00000000-0000-4000-8000-000000000002';
const messageId = '00000000-0000-4000-8000-000000000003';
const generation = '00000000-0000-4000-8000-000000000004';

class _Store extends Mock implements PhotoWidgetStore {}

final now = DateTime.utc(2026, 10, 28);
final photo = TimelineEntry(
  id: messageId,
  squadId: squadId,
  authorId: 'friend',
  authorName: '队友',
  kind: TimelineEntryKind.photo,
  clientNonce: 'nonce',
  createdAt: now,
  photo: const PhotoAttachment(
    mediaId: 'media',
    width: 4,
    height: 3,
    byteLength: 600,
    isRevoked: false,
  ),
);
PhotoImage image() => PhotoImage(
  bytes: File('test/features/photos/fixtures/sanitized.jpg').readAsBytesSync(),
  width: 4,
  height: 3,
  sha256: 'a' * 64,
);

class Harness {
  PhotoWidgetContext? owner = PhotoWidgetContext(
    environmentId: 'staging',
    userId: 'alice',
    expiresAt: now.add(const Duration(hours: 1)),
  );
  final store = _Store();
  late PhotoWidgetSnapshot state;
  late PhotoWidgetService service;
  int latestCalls = 0;
  int loadCalls = 0;
  final writes = <String>[];
  bool allowed = true;
  Future<Either<Failure, PhotoHead>> Function()? latest;
  Future<Either<Failure, PhotoImage>> Function()? load;
  TimelineEntry? parent = photo;

  Future<void> init({bool preview = true}) async {
    final scope = await photoWidgetScope(owner!);
    state = PhotoWidgetSnapshot(
      display: preview ? PhotoWidgetDisplay.empty : PhotoWidgetDisplay.hidden,
      scheme: 'squadly',
      lease: PhotoWidgetLease(
        scope: scope,
        generation: generation,
        expiresAt: owner!.expiresAt,
      ),
      binding: PhotoWidgetBinding(
        id: bindingId,
        scope: scope,
        squadId: squadId,
        squadName: '周末小队',
        previewEnabled: preview,
      ),
    );
    when(
      () => store.synchronize(
        scope: any(named: 'scope'),
        expiresAt: any(named: 'expiresAt'),
      ),
    ).thenAnswer((_) async => state);
    when(() => store.read()).thenAnswer((_) async => state);
    when(
      () => store.invalidate(
        expected: any(named: 'expected'),
        failed: any(named: 'failed'),
      ),
    ).thenAnswer((call) async {
      state = state.copyWith(
        display: PhotoWidgetDisplay.unavailable,
        messageId: null,
      );
      return state;
    });
    when(
      () => store.applyHead(
        expected: any(named: 'expected'),
        head: any(named: 'head'),
        image: any(named: 'image'),
      ),
    ).thenAnswer((call) async {
      final id = (call.namedArguments[#head] as PhotoHead).photo?.id;
      if (id != null) writes.add(id);
      state = state.copyWith(
        display: id == null
            ? PhotoWidgetDisplay.empty
            : PhotoWidgetDisplay.photo,
        messageId: id,
      );
      return state;
    });
    service = PhotoWidgetService(
      store: store,
      context: () => owner,
      clock: () => now,
      squad: (context, id) async => allowed
          ? right(
              Squad(
                id: id,
                name: '周末小队',
                inviteCode: 'invitation',
                createdBy: 'alice',
                createdAt: now,
              ),
            )
          : left(const Failure.permissionDenied()),
      latest: (_, _) async {
        latestCalls++;
        return latest == null
            ? right(PhotoHead(revision: '1', photo: photo))
            : latest!();
      },
      find: (_, _, _) async => right(parent),
      load: (_, _, _) async {
        loadCalls++;
        return load == null ? right(image()) : load!();
      },
    );
  }

  PhotoWidgetEntry get entry => PhotoWidgetEntry(
    squadId: squadId,
    bindingId: bindingId,
    scope: state.binding!.scope,
    messageId: messageId,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const PhotoWidgetSnapshot(
        display: PhotoWidgetDisplay.empty,
        scheme: 'squadly',
      ),
    );
    registerFallbackValue(const PhotoHead(revision: '0'));
    registerFallbackValue(now);
    registerFallbackValue(image());
  });

  test(
    'hide fences in-flight pixels and stale server head/deep link',
    () async {
      final h = Harness();
      await h.init();
      final pixels = Completer<Either<Failure, PhotoImage>>();
      h.load = () => pixels.future;
      final pending = h.service.refresh();
      while (h.loadCalls == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      await h.service.suppressPhoto(squadId, messageId);
      pixels.complete(right(image()));
      expect((await pending).isLeft(), isTrue);
      expect(h.writes, isEmpty);
      final calls = h.loadCalls;
      expect((await h.service.refresh()).isLeft(), isTrue);
      expect(h.loadCalls, calls);
      expect(h.writes, isEmpty);
      expect((await h.service.resolve(h.entry)).isLeft(), isTrue);
    },
  );
  test(
    'a higher personal head can replace the suppressed latest with empty state',
    () async {
      final h = Harness();
      await h.init();
      await h.service.suppressPhoto(squadId, messageId);
      h.latest = () async => right(const PhotoHead(revision: '2'));
      expect((await h.service.refresh()).isRight(), isTrue);
      expect(h.state.display, PhotoWidgetDisplay.empty);
      expect(h.writes, isEmpty);
    },
  );
  testWidgets(
    'settings distinguishes hidden binding from zero installed widgets on a narrow screen',
    (tester) async {
      final h = Harness();
      await h.init(preview: false);
      when(() => h.store.isAvailable()).thenAnswer((_) async => true);
      when(() => h.store.installedCount()).thenAnswer((_) async => 0);
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            photoWidgetServiceProvider.overrideWithValue(h.service),
            photoWidgetContextProvider.overrideWithValue(h.owner),
          ],
          child: const MaterialApp(
            home: PhotoWidgetSettingsScreen(
              squadId: squadId,
              squadName: '周末小队的长中文名字',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('已绑定这个小队'), findsOneWidget);
      expect(find.text('桌面上尚未检测到小队组件'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(h.latestCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('unavailable platform has no misleading add success', (
    tester,
  ) async {
    final h = Harness();
    await h.init();
    when(() => h.store.isAvailable()).thenAnswer((_) async => false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoWidgetServiceProvider.overrideWithValue(h.service),
          photoWidgetContextProvider.overrideWithValue(h.owner),
        ],
        child: const MaterialApp(
          home: PhotoWidgetSettingsScreen(squadId: squadId, squadName: '小队'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('当前设备或版本暂不支持桌面组件'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
  });
  testWidgets('revoked parent stops entry before the camera destination', (
    tester,
  ) async {
    final h = Harness();
    await h.init();
    h.parent = null;
    var cameras = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoWidgetServiceProvider.overrideWithValue(h.service),
          photoWidgetContextProvider.overrideWithValue(h.owner),
        ],
        child: MaterialApp(
          home: PhotoWidgetEntryScreen(
            entry: h.entry,
            cameraBuilder: (_) {
              cameras++;
              return const Text('camera');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('原照片已无法回拍，请返回小队查看'), findsOneWidget);
    expect(cameras, 0);
  });
  test('hidden preview never fetches or writes photos', () async {
    final h = Harness();
    await h.init(preview: false);
    expect((await h.service.refresh()).isRight(), isTrue);
    expect(h.latestCalls, 0);
    expect(h.loadCalls, 0);
    expect(h.writes, isEmpty);
  });
  test(
    'visible preview fetches a photo but has no read receipt dependency',
    () async {
      final h = Harness();
      await h.init();
      expect(
        (await h.service.refresh()).getRight().toNullable()!.messageId,
        messageId,
      );
      expect(h.writes, [messageId]);
    },
  );
  test('network and membership failures invalidate the old pixels', () async {
    for (final permission in [false, true]) {
      final h = Harness();
      await h.init();
      h.allowed = permission;
      h.latest = () async => left(const Failure.network());
      expect((await h.service.refresh()).isLeft(), isTrue);
      verify(
        () =>
            h.store.invalidate(expected: any(named: 'expected'), failed: true),
      ).called(1);
      expect(h.loadCalls, 0);
    }
  });
  test('versioned empty head clears without downloading pixels', () async {
    final h = Harness();
    await h.init();
    h.latest = () async => right(const PhotoHead(revision: '9'));
    expect(
      (await h.service.refresh()).getRight().toNullable()?.display,
      PhotoWidgetDisplay.empty,
    );
    expect(h.loadCalls, 0);
    verify(
      () => h.store.applyHead(
        expected: any(named: 'expected'),
        head: const PhotoHead(revision: '9'),
      ),
    ).called(1);
  });
  test(
    'revocation or a new photo during download rejects the earlier pixels',
    () async {
      for (final revoked in [true, false]) {
        final h = Harness();
        await h.init();
        h.load = () async {
          h.latest = () async =>
              right(PhotoHead(revision: '2', photo: revoked ? null : photo));
          return right(image());
        };
        expect((await h.service.refresh()).isLeft(), isTrue);
        expect(h.writes, isEmpty);
        verify(
          () => h.store.invalidate(
            expected: any(named: 'expected'),
            failed: true,
          ),
        ).called(1);
      }
    },
  );
  test('authorization failure after download clears bytes instead of caching success', () async {
    final h = Harness();
    await h.init();
    h.load = () async {
      h.latest = () async => left(const Failure.permissionDenied());
      return right(image());
    };
    expect(
      (await h.service.refresh()).getLeft().toNullable(),
      isA<PermissionDeniedFailure>(),
    );
    expect(h.writes, isEmpty);
  });
  test('A to B to A identity revision rejects an in-flight image', () async {
    final h = Harness();
    await h.init();
    final waiting = Completer<Either<Failure, PhotoImage>>();
    final started = Completer<void>();
    h.load = () {
      started.complete();
      return waiting.future;
    };
    final pending = h.service.refresh();
    await started.future;
    h.owner = h.owner!.copyWith(revision: 2);
    waiting.complete(right(image()));
    expect((await pending).isLeft(), isTrue);
    expect(h.writes, isEmpty);
  });
  test('a slower older refresh cannot overwrite a newer result', () async {
    final h = Harness();
    await h.init();
    final waiting = Completer<Either<Failure, PhotoImage>>();
    final started = Completer<void>();
    h.load = () {
      started.complete();
      return waiting.future;
    };
    final older = h.service.refresh();
    await started.future;
    h.load = null;
    expect((await h.service.refresh()).isRight(), isTrue);
    waiting.complete(right(image()));
    expect((await older).isLeft(), isTrue);
    expect(h.writes, [messageId]);
  });
  test('expired or foreign context cannot resolve a widget entry', () async {
    final h = Harness();
    await h.init();
    expect(
      (await h.service.resolve(h.entry.copyWith(scope: 'b' * 64))).isLeft(),
      isTrue,
    );
    h.owner = h.owner!.copyWith(expiresAt: now);
    expect((await h.service.resolve(h.entry)).isLeft(), isTrue);
  });
  test(
    'fixed entry retains original squad and parent without retargeting',
    () async {
      final h = Harness();
      await h.init();
      final target = (await h.service.resolve(h.entry))
          .getRight()
          .toNullable()!;
      expect(target.squadId, squadId);
      expect(target.replyToMessageId, messageId);
      h.parent = null;
      expect((await h.service.resolve(h.entry)).isLeft(), isTrue);
      h.parent = TimelineEntry(
        id: messageId,
        squadId: squadId,
        authorId: 'friend',
        authorName: '队友',
        kind: TimelineEntryKind.photo,
        clientNonce: 'nonce',
        createdAt: now,
        photo: photo.photo!.copyWith(isRevoked: true),
      );
      expect((await h.service.resolve(h.entry)).isLeft(), isTrue);
      expect(
        (await h.service.resolve(h.entry.copyWith(bindingId: generation)))
            .isLeft(),
        isTrue,
      );
    },
  );
  test(
    'scope separates backend environments and accounts but not auth revision',
    () async {
      final h = Harness();
      await h.init();
      final scope = await photoWidgetScope(h.owner!);
      expect(await photoWidgetScope(h.owner!.copyWith(revision: 8)), scope);
      expect(
        await photoWidgetScope(h.owner!.copyWith(environmentId: 'production')),
        isNot(scope),
      );
      expect(
        await photoWidgetScope(h.owner!.copyWith(userId: 'bob')),
        isNot(scope),
      );
    },
  );
}
