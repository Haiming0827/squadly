import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../features/auth/domain/entities/user.dart';
import '../../features/finance/domain/entities/fund_transaction.dart';
import '../../features/finance/domain/entities/private_asset.dart';
import '../../features/finance/domain/entities/public_fund.dart';
import '../../features/finance/domain/entities/shared_expense.dart';
import '../../features/fitness/domain/entities/check_in.dart';
import '../../features/fitness/domain/entities/daily_task.dart';
import '../../features/fitness/domain/entities/health_snapshot.dart';
import '../../features/fitness/domain/entities/workout_plan.dart';
import '../../features/squad/domain/entities/squad.dart';
import '../../features/squad/domain/entities/squad_member.dart';
import 'demo_models.dart';

final demoAppStoreProvider = StateNotifierProvider<DemoAppStore, DemoAppState>((
  ref,
) {
  return DemoAppStore();
});

class DemoAppStore extends StateNotifier<DemoAppState> {
  DemoAppStore() : super(_seedState());

  static const _uuid = Uuid();

  User signInWithEmail({required String email, required String password}) {
    final normalized = email.trim().toLowerCase();
    var user = state.users
        .where((item) => item.email?.toLowerCase() == normalized)
        .firstOrNull;

    user ??= _createUser(
      nickname: normalized.split('@').first,
      email: normalized,
    );

    _setSignedInUser(user);
    return user;
  }

  User signUpWithEmail({
    required String email,
    required String password,
    required String nickname,
  }) {
    final normalized = email.trim().toLowerCase();
    final existing = state.users
        .where((item) => item.email?.toLowerCase() == normalized)
        .firstOrNull;
    final user =
        existing ?? _createUser(nickname: nickname.trim(), email: normalized);
    _setSignedInUser(user);
    return user;
  }

  void sendPhoneVerification({required String phone}) {}

  User verifyPhoneCode({required String phone, required String code}) {
    var user = state.users.where((item) => item.phone == phone).firstOrNull;
    user ??= _createUser(
      nickname: '用户${phone.substring(max(0, phone.length - 4))}',
      phone: phone,
    );
    _setSignedInUser(user);
    return user;
  }

  User signInWithApple() {
    final user = state.users.first;
    _setSignedInUser(user);
    return user;
  }

  User? getCurrentUser() => state.currentUser;

  void signOut() {
    state = state.copyWith(clearCurrentUser: true);
  }

  void selectSquad(String squadId) {
    state = state.copyWith(currentSquadId: squadId);
  }

  Squad createSquad({required String name, String? description}) {
    final user = _requireUser();
    final now = DateTime.now();
    final squad = Squad(
      id: _uuid.v4(),
      name: name.trim(),
      description: description?.trim().isEmpty ?? true
          ? null
          : description?.trim(),
      inviteCode: _inviteCode(),
      maxMembers: AppConstants.squadMaxMembers,
      createdBy: user.id,
      createdAt: now,
    );
    final member = SquadMember(
      id: _uuid.v4(),
      squadId: squad.id,
      userId: user.id,
      role: AppConstants.roleCaptain,
      joinedAt: now,
      nickname: user.nickname,
      avatarUrl: user.avatarUrl,
    );

    state = state.copyWith(
      squads: [...state.squads, squad],
      members: [...state.members, member],
      currentSquadId: squad.id,
    );
    return squad;
  }

  Squad joinSquad({required String inviteCode}) {
    final user = _requireUser();
    final normalized = inviteCode.trim().toUpperCase();
    final squad = state.squads
        .where((item) => item.inviteCode.toUpperCase() == normalized)
        .firstOrNull;
    if (squad == null) {
      throw StateError('邀请码无效');
    }
    final existing = state.members.any(
      (member) => member.squadId == squad.id && member.userId == user.id,
    );
    if (existing) {
      state = state.copyWith(currentSquadId: squad.id);
      return squad;
    }
    if (state.membersFor(squad.id).length >= squad.maxMembers) {
      throw StateError('小队已满员');
    }

    final member = SquadMember(
      id: _uuid.v4(),
      squadId: squad.id,
      userId: user.id,
      role: AppConstants.roleMember,
      joinedAt: DateTime.now(),
      nickname: user.nickname,
      avatarUrl: user.avatarUrl,
    );
    state = state.copyWith(
      members: [...state.members, member],
      currentSquadId: squad.id,
    );
    return squad;
  }

  void removeMember({required String squadId, required String userId}) {
    final current = _requireUser();
    _requireCaptain(squadId);
    if (current.id == userId) {
      throw StateError('队长不能移除自己');
    }
    if (state.membersFor(squadId).length <= AppConstants.squadMinMembers) {
      throw StateError('小队至少需要 2 人');
    }
    state = state.copyWith(
      members: state.members
          .where(
            (member) => !(member.squadId == squadId && member.userId == userId),
          )
          .toList(),
    );
  }

  void transferCaptain({
    required String squadId,
    required String newCaptainId,
  }) {
    final current = _requireUser();
    _requireCaptain(squadId);
    state = state.copyWith(
      members: state.members.map((member) {
        if (member.squadId != squadId) return member;
        if (member.userId == current.id) {
          return member.copyWith(role: AppConstants.roleMember);
        }
        if (member.userId == newCaptainId) {
          return member.copyWith(role: AppConstants.roleCaptain);
        }
        return member;
      }).toList(),
    );
  }

  void leaveSquad(String squadId) {
    final user = _requireUser();
    final membership = state.members
        .where(
          (member) => member.squadId == squadId && member.userId == user.id,
        )
        .firstOrNull;
    if (membership == null) return;
    if (membership.role == AppConstants.roleCaptain) {
      throw StateError('队长需要先转让队长');
    }
    if (state.membersFor(squadId).length <= AppConstants.squadMinMembers) {
      throw StateError('小队至少需要 2 人');
    }
    final nextMembers = state.members
        .where(
          (member) => !(member.squadId == squadId && member.userId == user.id),
        )
        .toList();
    final nextState = state.copyWith(members: nextMembers);
    state = nextState.copyWith(
      currentSquadId: nextState.mySquads.isNotEmpty
          ? nextState.mySquads.first.id
          : null,
      clearCurrentSquad: nextState.mySquads.isEmpty,
    );
  }

  DailyTask createDailyTask({
    required String squadId,
    required String title,
    required String taskType,
    double? targetValue,
    String? targetUnit,
  }) {
    _requireMember(squadId);
    final task = DailyTask(
      id: _uuid.v4(),
      squadId: squadId,
      title: title.trim(),
      taskType: taskType,
      targetValue: targetValue,
      targetUnit: targetUnit,
      recurringDays: const [1, 2, 3, 4, 5, 6, 7],
      createdAt: DateTime.now(),
    );
    state = state.copyWith(dailyTasks: [...state.dailyTasks, task]);
    return task;
  }

  CheckIn checkInTask({
    required String taskId,
    required String squadId,
    double? value,
    String? note,
  }) {
    final user = _requireUser();
    _requireMember(squadId);
    final today = _today();
    final task = state.dailyTasks.firstWhere((item) => item.id == taskId);
    final existing = state.checkIns
        .where(
          (item) =>
              item.taskId == taskId &&
              item.userId == user.id &&
              _isSameDate(item.checkedAt, today),
        )
        .firstOrNull;
    final checkIn = CheckIn(
      id: existing?.id ?? _uuid.v4(),
      taskId: taskId,
      userId: user.id,
      squadId: squadId,
      value: value,
      note: note,
      checkedAt: today,
      createdAt: existing?.createdAt ?? DateTime.now(),
      userNickname: user.nickname,
      taskTitle: task.title,
    );
    final next = [
      ...state.checkIns.where((item) => item.id != checkIn.id),
      checkIn,
    ];
    state = state.copyWith(checkIns: next);
    return checkIn;
  }

  HealthSnapshot recordHealthSnapshot({
    required String squadId,
    double? weight,
    int? workoutMinutes,
    int? caloriesBurned,
  }) {
    final user = _requireUser();
    _requireMember(squadId);
    final today = _today();
    final existing = state.healthSnapshots
        .where(
          (snapshot) =>
              snapshot.userId == user.id &&
              snapshot.squadId == squadId &&
              _isSameDate(snapshot.recordedDate, today),
        )
        .firstOrNull;
    final snapshot = HealthSnapshot(
      id: existing?.id ?? _uuid.v4(),
      userId: user.id,
      squadId: squadId,
      weight: weight,
      workoutMinutes: workoutMinutes,
      caloriesBurned: caloriesBurned,
      recordedDate: today,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );
    state = state.copyWith(
      healthSnapshots: [
        ...state.healthSnapshots.where((item) => item.id != snapshot.id),
        snapshot,
      ],
    );
    return snapshot;
  }

  PublicFund createFund({
    required String squadId,
    required String name,
    required String fundType,
    double targetAmount = 0,
  }) {
    final user = _requireUser();
    _requireMember(squadId);
    final fund = PublicFund(
      id: _uuid.v4(),
      squadId: squadId,
      name: name.trim(),
      fundType: fundType,
      targetAmount: targetAmount,
      currentAmount: 0,
      createdBy: user.id,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(publicFunds: [...state.publicFunds, fund]);
    return fund;
  }

  FundTransaction addFundTransaction({
    required String fundId,
    required double amount,
    String? description,
  }) {
    final user = _requireUser();
    final fund = state.publicFunds.firstWhere((item) => item.id == fundId);
    _requireMember(fund.squadId);
    final transaction = FundTransaction(
      id: _uuid.v4(),
      fundId: fundId,
      userId: user.id,
      amount: amount,
      description: description,
      transactionDate: DateTime.now(),
      userNickname: user.nickname,
    );
    state = state.copyWith(
      publicFunds: state.publicFunds.map((item) {
        if (item.id != fundId) return item;
        return item.copyWith(currentAmount: item.currentAmount + amount);
      }).toList(),
      fundTransactions: [...state.fundTransactions, transaction],
    );
    return transaction;
  }

  PrivateAsset createPrivateAsset({
    required String assetType,
    required String name,
    double amount = 0,
    String? note,
  }) {
    final user = _requireUser();
    final now = DateTime.now();
    final asset = PrivateAsset(
      id: _uuid.v4(),
      userId: user.id,
      assetType: assetType,
      name: name.trim(),
      amount: amount,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
    state = state.copyWith(privateAssets: [...state.privateAssets, asset]);
    return asset;
  }

  PrivateAsset updatePrivateAsset({
    required String assetId,
    String? name,
    double? amount,
    String? note,
  }) {
    final user = _requireUser();
    late PrivateAsset updated;
    state = state.copyWith(
      privateAssets: state.privateAssets.map((asset) {
        if (asset.id != assetId) return asset;
        if (asset.userId != user.id) throw StateError('不能修改他人的私密资产');
        updated = asset.copyWith(
          name: name ?? asset.name,
          amount: amount ?? asset.amount,
          note: note ?? asset.note,
          updatedAt: DateTime.now(),
        );
        return updated;
      }).toList(),
    );
    return updated;
  }

  void deletePrivateAsset(String assetId) {
    final user = _requireUser();
    state = state.copyWith(
      privateAssets: state.privateAssets
          .where((asset) => asset.id != assetId || asset.userId != user.id)
          .toList(),
    );
  }

  SharedExpense recordSharedExpense({
    required String squadId,
    required double amount,
    required String category,
    String? description,
    bool needsApproval = false,
  }) {
    final user = _requireUser();
    _requireMember(squadId);
    final expense = SharedExpense(
      id: _uuid.v4(),
      squadId: squadId,
      paidBy: user.id,
      amount: amount,
      category: category,
      description: description,
      expenseDate: _today(),
      needsApproval: needsApproval,
      approvedCount: needsApproval ? 1 : 0,
      createdAt: DateTime.now(),
      paidByNickname: user.nickname,
    );
    state = state.copyWith(sharedExpenses: [...state.sharedExpenses, expense]);
    return expense;
  }

  TravelPlan createTravelPlan({
    required String squadId,
    required String title,
    required String destination,
    required double budget,
    String? linkedFundId,
    String? notes,
  }) {
    final user = _requireUser();
    _requireMember(squadId);
    final now = DateTime.now();
    final plan = TravelPlan(
      id: _uuid.v4(),
      squadId: squadId,
      title: title.trim(),
      destination: destination.trim(),
      startDate: now.add(const Duration(days: 30)),
      endDate: now.add(const Duration(days: 34)),
      budget: budget,
      linkedFundId: linkedFundId,
      createdBy: user.id,
      createdAt: now,
      notes: notes,
    );
    state = state.copyWith(travelPlans: [...state.travelPlans, plan]);
    return plan;
  }

  FoodSpot addFoodSpot({
    required String squadId,
    required String name,
    required String category,
    required double averageCost,
    required int caloriesEstimate,
    String? address,
    String? note,
  }) {
    final user = _requireUser();
    _requireMember(squadId);
    final spot = FoodSpot(
      id: _uuid.v4(),
      squadId: squadId,
      name: name.trim(),
      category: category,
      averageCost: averageCost,
      caloriesEstimate: caloriesEstimate,
      address: address,
      note: note,
      addedBy: user.id,
      createdAt: DateTime.now(),
      votes: {user.id: 1},
    );
    state = state.copyWith(foodSpots: [...state.foodSpots, spot]);
    return spot;
  }

  void voteFoodSpot({required String foodSpotId, required int delta}) {
    final user = _requireUser();
    state = state.copyWith(
      foodSpots: state.foodSpots.map((spot) {
        if (spot.id != foodSpotId) return spot;
        final votes = Map<String, int>.from(spot.votes);
        votes[user.id] = delta.clamp(-1, 1);
        return spot.copyWith(votes: votes);
      }).toList(),
    );
  }

  FoodSpot? decideFood(String squadId) {
    final options = state.foodFor(squadId);
    if (options.isEmpty) return null;
    return options.first;
  }

  User _createUser({required String nickname, String? email, String? phone}) {
    final user = User(
      id: _uuid.v4(),
      nickname: nickname.isEmpty ? '小队成员' : nickname,
      email: email,
      phone: phone,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(users: [...state.users, user]);
    return user;
  }

  void _setSignedInUser(User user) {
    final next = state.copyWith(currentUser: user);
    final currentSquadId = next.mySquads.isNotEmpty
        ? next.mySquads.first.id
        : null;
    state = next.copyWith(
      currentSquadId: currentSquadId,
      clearCurrentSquad: currentSquadId == null,
    );
  }

  User _requireUser() {
    final user = state.currentUser;
    if (user == null) throw StateError('请先登录');
    return user;
  }

  void _requireMember(String squadId) {
    final user = _requireUser();
    final isMember = state.members.any(
      (member) => member.squadId == squadId && member.userId == user.id,
    );
    if (!isMember) throw StateError('你不是该小队成员');
  }

  void _requireCaptain(String squadId) {
    final user = _requireUser();
    final isCaptain = state.members.any(
      (member) =>
          member.squadId == squadId &&
          member.userId == user.id &&
          member.role == AppConstants.roleCaptain,
    );
    if (!isCaptain) throw StateError('仅队长可以操作');
  }
}

DemoAppState _seedState() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final users = [
    User(
      id: 'user-haiming',
      nickname: '海明',
      email: 'haiming@example.com',
      phone: '13800138000',
      createdAt: now.subtract(const Duration(days: 120)),
    ),
    User(
      id: 'user-lina',
      nickname: '李娜',
      email: 'lina@example.com',
      createdAt: now.subtract(const Duration(days: 80)),
    ),
    User(
      id: 'user-chen',
      nickname: '陈晨',
      email: 'chen@example.com',
      createdAt: now.subtract(const Duration(days: 60)),
    ),
  ];

  final squads = [
    Squad(
      id: 'squad-weekend',
      name: '周末行动组',
      description: '健身、旅行、攒钱和吃饭都认真一点。',
      inviteCode: 'WKND09',
      createdBy: users.first.id,
      createdAt: now.subtract(const Duration(days: 45)),
    ),
    Squad(
      id: 'squad-run',
      name: '夜跑搭子',
      description: '工作日晚上一起动一动。',
      inviteCode: 'RUN520',
      createdBy: users.first.id,
      createdAt: now.subtract(const Duration(days: 20)),
    ),
  ];

  final members = [
    SquadMember(
      id: 'member-1',
      squadId: 'squad-weekend',
      userId: 'user-haiming',
      role: AppConstants.roleCaptain,
      joinedAt: now.subtract(const Duration(days: 45)),
      nickname: '海明',
    ),
    SquadMember(
      id: 'member-2',
      squadId: 'squad-weekend',
      userId: 'user-lina',
      role: AppConstants.roleMember,
      joinedAt: now.subtract(const Duration(days: 43)),
      nickname: '李娜',
    ),
    SquadMember(
      id: 'member-3',
      squadId: 'squad-weekend',
      userId: 'user-chen',
      role: AppConstants.roleMember,
      joinedAt: now.subtract(const Duration(days: 41)),
      nickname: '陈晨',
    ),
    SquadMember(
      id: 'member-4',
      squadId: 'squad-run',
      userId: 'user-haiming',
      role: AppConstants.roleCaptain,
      joinedAt: now.subtract(const Duration(days: 20)),
      nickname: '海明',
    ),
    SquadMember(
      id: 'member-5',
      squadId: 'squad-run',
      userId: 'user-lina',
      role: AppConstants.roleMember,
      joinedAt: now.subtract(const Duration(days: 19)),
      nickname: '李娜',
    ),
  ];

  final workoutPlans = [
    WorkoutPlan(
      id: 'plan-1',
      squadId: 'squad-weekend',
      name: '四周体能恢复',
      planType: 'body_shaping',
      description: '低冲击有氧 + 拉伸 + 核心训练。',
      createdBy: 'user-haiming',
      createdAt: now.subtract(const Duration(days: 14)),
    ),
  ];

  final dailyTasks = [
    DailyTask(
      id: 'task-stretch',
      squadId: 'squad-weekend',
      title: '睡前拉伸',
      taskType: 'stretch',
      targetValue: 15,
      targetUnit: 'minutes',
      recurringDays: const [1, 2, 3, 4, 5, 6, 7],
      createdAt: now.subtract(const Duration(days: 12)),
    ),
    DailyTask(
      id: 'task-run',
      squadId: 'squad-weekend',
      title: '轻松跑',
      taskType: 'night_run',
      targetValue: 3,
      targetUnit: 'km',
      recurringDays: const [2, 4, 6],
      createdAt: now.subtract(const Duration(days: 10)),
    ),
  ];

  final checkIns = [
    CheckIn(
      id: 'check-1',
      taskId: 'task-stretch',
      userId: 'user-lina',
      squadId: 'squad-weekend',
      value: 18,
      note: '肩颈轻松很多',
      checkedAt: today,
      createdAt: now.subtract(const Duration(hours: 4)),
      userNickname: '李娜',
      taskTitle: '睡前拉伸',
    ),
    CheckIn(
      id: 'check-2',
      taskId: 'task-run',
      userId: 'user-chen',
      squadId: 'squad-weekend',
      value: 3.2,
      note: '配速稳定',
      checkedAt: today,
      createdAt: now.subtract(const Duration(hours: 2)),
      userNickname: '陈晨',
      taskTitle: '轻松跑',
    ),
  ];

  final healthSnapshots = [
    HealthSnapshot(
      id: 'health-1',
      userId: 'user-haiming',
      squadId: 'squad-weekend',
      weight: 72.5,
      workoutMinutes: 35,
      caloriesBurned: 320,
      recordedDate: today,
      createdAt: now.subtract(const Duration(hours: 1)),
    ),
  ];

  final publicFunds = [
    PublicFund(
      id: 'fund-travel',
      squadId: 'squad-weekend',
      name: '春季旅行基金',
      fundType: 'travel',
      targetAmount: 6000,
      currentAmount: 2680,
      createdBy: 'user-haiming',
      createdAt: now.subtract(const Duration(days: 30)),
    ),
    PublicFund(
      id: 'fund-dinner',
      squadId: 'squad-weekend',
      name: '聚餐储备',
      fundType: 'dining',
      targetAmount: 1200,
      currentAmount: 460,
      createdBy: 'user-lina',
      createdAt: now.subtract(const Duration(days: 18)),
    ),
  ];

  final fundTransactions = [
    FundTransaction(
      id: 'tx-1',
      fundId: 'fund-travel',
      userId: 'user-haiming',
      amount: 1000,
      description: '本月旅行基金',
      transactionDate: now.subtract(const Duration(days: 12)),
      userNickname: '海明',
    ),
    FundTransaction(
      id: 'tx-2',
      fundId: 'fund-travel',
      userId: 'user-lina',
      amount: 800,
      description: '补齐机票预算',
      transactionDate: now.subtract(const Duration(days: 8)),
      userNickname: '李娜',
    ),
  ];

  final privateAssets = [
    PrivateAsset(
      id: 'asset-1',
      userId: 'user-haiming',
      assetType: 'savings',
      name: '旅行备用金',
      amount: 12000,
      note: '只在本人空间展示',
      createdAt: now.subtract(const Duration(days: 10)),
      updatedAt: now.subtract(const Duration(days: 2)),
    ),
    PrivateAsset(
      id: 'asset-2',
      userId: 'user-lina',
      assetType: 'fund',
      name: '指数基金',
      amount: 8500,
      note: '隐私隔离测试数据',
      createdAt: now.subtract(const Duration(days: 8)),
      updatedAt: now.subtract(const Duration(days: 1)),
    ),
  ];

  final sharedExpenses = [
    SharedExpense(
      id: 'expense-1',
      squadId: 'squad-weekend',
      paidBy: 'user-chen',
      amount: 238,
      category: 'dining',
      description: '周六火锅',
      expenseDate: today.subtract(const Duration(days: 2)),
      createdAt: now.subtract(const Duration(days: 2)),
      paidByNickname: '陈晨',
    ),
  ];

  final travelPlans = [
    TravelPlan(
      id: 'travel-1',
      squadId: 'squad-weekend',
      title: '杭州两日散步',
      destination: '杭州',
      startDate: today.add(const Duration(days: 32)),
      endDate: today.add(const Duration(days: 34)),
      budget: 5200,
      linkedFundId: 'fund-travel',
      createdBy: 'user-haiming',
      createdAt: now.subtract(const Duration(days: 6)),
      notes: '西湖、良渚、咖啡店和一次夜跑。',
    ),
  ];

  final foodSpots = [
    FoodSpot(
      id: 'food-1',
      squadId: 'squad-weekend',
      name: '巷口牛肉面',
      category: '简餐',
      averageCost: 38,
      caloriesEstimate: 620,
      addedBy: 'user-lina',
      createdAt: now.subtract(const Duration(days: 7)),
      address: '人民路 18 号',
      votes: const {'user-haiming': 1, 'user-lina': 1},
    ),
    FoodSpot(
      id: 'food-2',
      squadId: 'squad-weekend',
      name: '低卡轻食店',
      category: '轻食',
      averageCost: 52,
      caloriesEstimate: 410,
      addedBy: 'user-chen',
      createdAt: now.subtract(const Duration(days: 5)),
      address: '湖滨银泰 B1',
      votes: const {'user-chen': 1},
    ),
  ];

  return DemoAppState(
    users: users,
    squads: squads,
    members: members,
    workoutPlans: workoutPlans,
    dailyTasks: dailyTasks,
    checkIns: checkIns,
    healthSnapshots: healthSnapshots,
    publicFunds: publicFunds,
    fundTransactions: fundTransactions,
    privateAssets: privateAssets,
    sharedExpenses: sharedExpenses,
    travelPlans: travelPlans,
    foodSpots: foodSpots,
  );
}

String _inviteCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random();
  return List.generate(
    6,
    (_) => alphabet[random.nextInt(alphabet.length)],
  ).join();
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
