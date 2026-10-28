import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/app/demo/demo_store.dart';
import 'package:squadly/core/constants/app_constants.dart';
import 'package:squadly/features/plan/domain/entities/squad_plan.dart';

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

    test('nickname edit updates only the signed-in member', () {
      final store = DemoAppStore();
      final user = store.signInWithEmail(
        email: 'haiming@example.com',
        password: 'password1',
      );
      final teammate = store.state.users.firstWhere(
        (candidate) => candidate.id != user.id,
      );

      final updated = store.updateNickname('晨跑海明');

      expect(updated.nickname, '晨跑海明');
      expect(store.state.currentUser?.nickname, '晨跑海明');
      expect(
        store.state.users.firstWhere((item) => item.id == user.id).nickname,
        '晨跑海明',
      );
      expect(
        store.state.members
            .firstWhere((item) => item.userId == user.id)
            .nickname,
        '晨跑海明',
      );
      expect(
        store.state.users.firstWhere((item) => item.id == teammate.id),
        teammate,
      );
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

    test('private plans and tasks remain hidden from other squad members', () {
      final store = DemoAppStore();
      store.signInWithEmail(email: 'lina@example.com', password: 'password1');

      expect(store.getVisiblePlans('squad-weekend').map((plan) => plan.id), [
        'squad-plan-weekend',
        'squad-plan-legacy-workout',
      ]);
      expect(store.getVisiblePlanTasks('squad-plan-private-training'), isEmpty);
      expect(store.getVisiblePlanTasks('squad-plan-weekend').length, 2);
    });

    test(
      'private plans keep squad association and only owner can add tasks',
      () {
        final store = DemoAppStore();
        store.signInWithEmail(
          email: 'haiming@example.com',
          password: 'password1',
        );
        final plan = store.createPlan(
          squadId: 'squad-weekend',
          title: '只自己查看',
          category: PlanCategory.custom,
          visibility: PlanVisibility.private,
        );

        expect(plan.squadId, 'squad-weekend');
        expect(store.getVisiblePlans(plan.squadId), contains(plan));
        final task = store.createPlanTask(
          planId: plan.id,
          squadId: plan.squadId,
          title: '私人任务',
        );
        expect(task.planId, plan.id);
        expect(store.getVisiblePlanTasks(plan.id), contains(task));

        store.signInWithEmail(email: 'lina@example.com', password: 'password1');
        expect(store.getVisiblePlans(plan.squadId), isNot(contains(plan)));
        expect(
          () => store.createPlanTask(
            planId: plan.id,
            squadId: plan.squadId,
            title: '越权任务',
          ),
          throwsStateError,
        );
      },
    );

    test('only the owner can edit a private plan', () {
      final store = DemoAppStore();
      store.signInWithEmail(
        email: 'haiming@example.com',
        password: 'password1',
      );
      final plan = store.createPlan(
        squadId: 'squad-weekend',
        title: '私密计划',
        category: PlanCategory.custom,
        visibility: PlanVisibility.private,
      );

      store.signInWithEmail(email: 'lina@example.com', password: 'password1');
      expect(
        () => store.updatePlan(
          planId: plan.id,
          title: '越权修改',
          category: plan.category,
          visibility: plan.visibility,
        ),
        throwsStateError,
      );
      expect(
        store.state.squadPlans.firstWhere((item) => item.id == plan.id).title,
        '私密计划',
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
