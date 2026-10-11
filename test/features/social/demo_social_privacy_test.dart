import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/app/demo/demo_store.dart';

void main() {
  group('Demo social privacy', () {
    test('outsiders cannot select or read a squad conversation', () {
      final store = DemoAppStore();
      store.signInWithEmail(
        email: 'outsider@example.com',
        password: 'password1',
      );

      expect(() => store.selectSquad('squad-weekend'), throwsStateError);
      expect(store.state.currentSquad, isNull);
      expect(store.state.postsFor('squad-weekend'), isEmpty);
      expect(store.state.messagesFor('squad-weekend'), isEmpty);
    });

    test('membership in one squad does not expose another squad', () {
      final store = DemoAppStore();
      store.signInWithEmail(
        email: 'haiming@example.com',
        password: 'password1',
      );
      store.publishDataPost(
        squadId: 'squad-run',
        dataItemId: 'external-evening-run',
        title: '今晚跑步',
        body: '一起跑',
        template: 'story',
        visibility: 'squad',
      );
      store.sendCircleMessage(squadId: 'squad-run', text: '今晚出发');

      store.signInWithEmail(email: 'chen@example.com', password: 'password1');

      expect(store.state.postsFor('squad-run'), isEmpty);
      expect(store.state.messagesFor('squad-run'), isEmpty);
    });

    test('selected posts are visible only to author and recipients', () {
      final store = DemoAppStore();
      store.signInWithEmail(
        email: 'haiming@example.com',
        password: 'password1',
      );
      final post = store.publishDataPost(
        squadId: 'squad-weekend',
        dataItemId: 'external-sleep',
        title: '昨晚睡得不错',
        body: '给李娜看看',
        template: 'minimal',
        visibility: 'selected',
        visibleToUserIds: const ['user-lina'],
      );
      expect(
        store.state.postsFor('squad-weekend').any((item) => item.id == post.id),
        isTrue,
      );

      store.signInWithEmail(email: 'lina@example.com', password: 'password1');
      expect(
        store.state.postsFor('squad-weekend').any((item) => item.id == post.id),
        isTrue,
      );
      store.togglePostReaction(post.id);
      expect(
        store.state.socialPosts
            .firstWhere((item) => item.id == post.id)
            .reactionUserIds,
        contains('user-lina'),
      );

      store.signInWithEmail(email: 'chen@example.com', password: 'password1');
      expect(
        store.state.postsFor('squad-weekend').any((item) => item.id == post.id),
        isFalse,
      );
      expect(() => store.togglePostReaction(post.id), throwsStateError);
      expect(
        store.state.socialPosts
            .firstWhere((item) => item.id == post.id)
            .reactionUserIds,
        isNot(contains('user-chen')),
      );
    });

    test('outsiders cannot react even to squad-wide posts', () {
      final store = DemoAppStore();
      store.signInWithEmail(
        email: 'outsider@example.com',
        password: 'password1',
      );

      expect(() => store.togglePostReaction('post-run-lina'), throwsStateError);
      expect(
        store.state.socialPosts
            .firstWhere((post) => post.id == 'post-run-lina')
            .reactionUserIds,
        isNot(contains(store.state.currentUser!.id)),
      );
    });

    test(
      'imported data is owner-only and cannot be shared by another user',
      () {
        final store = DemoAppStore();
        store.signInWithEmail(
          email: 'haiming@example.com',
          password: 'password1',
        );
        expect(store.state.myImportedData, isNotEmpty);
        expect(
          store.state.myImportedData.every(
            (item) => item.userId == 'user-haiming',
          ),
          isTrue,
        );

        store.signInWithEmail(email: 'lina@example.com', password: 'password1');
        expect(store.state.myImportedData, isEmpty);
        expect(store.state.myDataConnections, isEmpty);
        expect(
          () => store.publishDataPost(
            squadId: 'squad-weekend',
            dataItemId: 'external-weekly-activity',
            title: '不属于我的数据',
            body: '',
            template: 'story',
            visibility: 'squad',
          ),
          throwsStateError,
        );
      },
    );

    test('demo connections cannot claim a real account was connected', () {
      final store = DemoAppStore();
      store.signInWithEmail(
        email: 'haiming@example.com',
        password: 'password1',
      );

      expect(
        () => store.connectDataSource('connection-apple-health'),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        store.state.myDataConnections.every((item) => !item.isConnected),
        isTrue,
      );
    });
  });
}
