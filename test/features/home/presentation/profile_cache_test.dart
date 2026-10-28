import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/app/demo/demo_store.dart';
import 'package:squadly/app/providers/conversation_cache_provider.dart';
import 'package:squadly/features/conversation/domain/conversation_cache.dart';
import 'package:squadly/features/home/presentation/screens/profile_screen.dart';

void main() {
  testWidgets(
    'local clear confirms scope; cancel keeps records; confirmed clear targets signed-in account',
    (tester) async {
      final cache = _Cache();
      final container = ProviderContainer(
        overrides: [conversationCacheProvider.overrideWithValue(cache)],
      );
      addTearDown(container.dispose);
      final user = container
          .read(demoAppStoreProvider.notifier)
          .signInWithEmail(email: 'local@example.test', password: 'password1');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('清理本机聊天记录'));
      await tester.tap(find.text('清理本机聊天记录'));
      await tester.pumpAndSettle();
      expect(find.textContaining('不删除服务器记录或未发送内容'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(cache.cleared, isEmpty);
      await tester.tap(find.text('清理本机聊天记录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('清理'));
      await tester.pumpAndSettle();
      expect(cache.cleared, [user.id]);
      expect(find.text('本机聊天记录已清理'), findsOneWidget);
    },
  );
}

class _Cache implements ConversationCache {
  final cleared = <String>[];
  @override
  Future<void> clearUser(String userId, {bool suspend = false}) async {
    cleared.add(userId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
