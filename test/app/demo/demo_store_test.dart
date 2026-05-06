import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/app/demo/demo_store.dart';
import 'package:squadly/core/constants/app_constants.dart';

void main() {
  group('DemoAppStore', () {
    test('signs in and selects first squad', () {
      final store = DemoAppStore();

      final user = store.signInWithEmail(
        email: 'haiming@example.com',
        password: 'password1',
      );

      expect(user.nickname, '海明');
      expect(store.state.currentUser?.id, user.id);
      expect(store.state.currentSquad?.name, '周末行动组');
    });

    test('private assets are visible only for current user', () {
      final store = DemoAppStore();
      store.signInWithEmail(
        email: 'haiming@example.com',
        password: 'password1',
      );

      final assetOwners = store.state.myPrivateAssets
          .map((asset) => asset.userId)
          .toSet();

      expect(assetOwners, {'user-haiming'});
      expect(
        store.state.myPrivateAssets.any((asset) => asset.userId == 'user-lina'),
        isFalse,
      );
    });

    test('prevents removing member below squad minimum', () {
      final store = DemoAppStore();
      store.signInWithEmail(
        email: 'haiming@example.com',
        password: 'password1',
      );
      store.selectSquad('squad-run');

      expect(
        () => store.removeMember(squadId: 'squad-run', userId: 'user-lina'),
        throwsStateError,
      );
      expect(
        store.state.membersFor('squad-run').length,
        AppConstants.squadMinMembers,
      );
    });

    test('updates fund balance when adding a transaction', () {
      final store = DemoAppStore();
      store.signInWithEmail(
        email: 'haiming@example.com',
        password: 'password1',
      );
      final before = store.state.fundBalance('fund-travel');

      store.addFundTransaction(
        fundId: 'fund-travel',
        amount: 120,
        description: '测试入账',
      );

      expect(store.state.fundBalance('fund-travel'), before + 120);
    });

    test('records only one check-in per task per user per day', () {
      final store = DemoAppStore();
      store.signInWithEmail(
        email: 'haiming@example.com',
        password: 'password1',
      );

      final first = store.checkInTask(
        taskId: 'task-stretch',
        squadId: 'squad-weekend',
        value: 10,
      );
      final second = store.checkInTask(
        taskId: 'task-stretch',
        squadId: 'squad-weekend',
        value: 15,
      );

      expect(second.id, first.id);
      expect(
        store.state.checkIns
            .where(
              (item) =>
                  item.taskId == 'task-stretch' &&
                  item.userId == 'user-haiming',
            )
            .length,
        1,
      );
    });
  });
}
