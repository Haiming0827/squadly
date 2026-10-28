import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/app/providers/social_providers.dart';
import 'package:squadly/core/theme/app_theme.dart';
import 'package:squadly/features/social/domain/entities/social_post.dart';
import 'package:squadly/features/social/presentation/screens/social_feed_screen.dart';

void main() {
  testWidgets('shows published snapshot and explicit audience in Squad feed', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          squadSocialPostsProvider('squad-1')
              .overrideWith((ref) => Stream.value([_post()])),
          currentSocialUserIdProvider.overrideWith((ref) => 'user-a'),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SocialFeedScreen(squadId: 'squad-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('小队动态'), findsOneWidget);
    expect(find.text('晨跑记录'), findsOneWidget);
    expect(find.text('小队可见'), findsOneWidget);
    expect(find.text('8,420'), findsOneWidget);
    expect(find.text('鼓励'), findsOneWidget);
  });

  testWidgets('shows a clear empty state when the Squad has no dynamics', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          squadSocialPostsProvider('squad-1')
              .overrideWith((ref) => Stream.value(const <SocialPost>[])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SocialFeedScreen(squadId: 'squad-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('还没有小队动态'), findsOneWidget);
  });

  testWidgets('releases the feed subscription when its page is removed', (
    tester,
  ) async {
    final cancelled = Completer<void>();
    final posts = StreamController<List<SocialPost>>(
      onCancel: cancelled.complete,
    );
    final feedOverride = squadSocialPostsProvider('squad-1')
        .overrideWith((ref) => posts.stream);
    addTearDown(() => unawaited(posts.close()));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [feedOverride],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SocialFeedScreen(squadId: 'squad-1'),
        ),
      ),
    );
    await tester.pump();
    expect(posts.hasListener, isTrue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [feedOverride],
        child: const MaterialApp(home: SizedBox.shrink()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(cancelled.isCompleted, isTrue);
    expect(posts.hasListener, isFalse);
  });

  testWidgets('handles narrow width and 1.4x Chinese text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          squadSocialPostsProvider('squad-1').overrideWith(
            (ref) => Stream.value([
              _post().copyWith(
                title: '周末和小队伙伴一起完成了很棒的晨间慢跑训练',
                body: '记录今天的运动状态，继续保持轻松稳定的节奏。',
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(1.4),
            ),
            child: SocialFeedScreen(squadId: 'squad-1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('周末和小队伙伴'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

SocialPost _post() => SocialPost(
  id: 'post-1',
  squadId: 'squad-1',
  authorId: 'user-a',
  authorName: '小明',
  title: '晨跑记录',
  body: '完成今天的跑步',
  template: 'story',
  visibility: 'squad',
  sourceLabel: 'Apple 健康',
  metricValue: '8,420',
  metricUnit: '步',
  rangeStart: DateTime.utc(2026, 10, 18),
  rangeEnd: DateTime.utc(2026, 10, 18, 23, 59),
  createdAt: DateTime.utc(2026, 10, 18, 8),
);
