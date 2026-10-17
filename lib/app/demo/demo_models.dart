import '../../features/auth/domain/entities/user.dart';
import '../../features/finance/domain/entities/fund_transaction.dart';
import '../../features/finance/domain/entities/private_asset.dart';
import '../../features/finance/domain/entities/public_fund.dart';
import '../../features/finance/domain/entities/shared_expense.dart';
import '../../features/fitness/domain/entities/check_in.dart';
import '../../features/fitness/domain/entities/daily_task.dart';
import '../../features/fitness/domain/entities/health_snapshot.dart';
import '../../features/fitness/domain/entities/workout_plan.dart';
import '../../features/food/domain/entities/food_spot.dart';
import '../../features/social/domain/entities/circle_message.dart';
import '../../features/social/domain/entities/data_connection.dart';
import '../../features/social/domain/entities/external_data_item.dart';
import '../../features/social/domain/entities/social_post.dart';
import '../../features/squad/domain/entities/squad.dart';
import '../../features/squad/domain/entities/squad_member.dart';
import '../../features/travel/domain/entities/travel_plan.dart';

class DemoAppState {
  const DemoAppState({
    required this.users,
    required this.squads,
    required this.members,
    required this.workoutPlans,
    required this.dailyTasks,
    required this.checkIns,
    required this.healthSnapshots,
    required this.publicFunds,
    required this.fundTransactions,
    required this.privateAssets,
    required this.sharedExpenses,
    required this.travelPlans,
    required this.foodSpots,
    required this.externalDataItems,
    required this.dataConnections,
    required this.socialPosts,
    required this.circleMessages,
    this.currentUser,
    this.currentSquadId,
  });

  final User? currentUser;
  final String? currentSquadId;
  final List<User> users;
  final List<Squad> squads;
  final List<SquadMember> members;
  final List<WorkoutPlan> workoutPlans;
  final List<DailyTask> dailyTasks;
  final List<CheckIn> checkIns;
  final List<HealthSnapshot> healthSnapshots;
  final List<PublicFund> publicFunds;
  final List<FundTransaction> fundTransactions;
  final List<PrivateAsset> privateAssets;
  final List<SharedExpense> sharedExpenses;
  final List<TravelPlan> travelPlans;
  final List<FoodSpot> foodSpots;
  final List<ExternalDataItem> externalDataItems;
  final List<DataConnection> dataConnections;
  final List<SocialPost> socialPosts;
  final List<CircleMessage> circleMessages;

  List<Squad> get mySquads {
    final user = currentUser;
    if (user == null) return const [];
    final squadIds = members
        .where((member) => member.userId == user.id)
        .map((member) => member.squadId)
        .toSet();
    return squads.where((squad) => squadIds.contains(squad.id)).toList();
  }

  Squad? get currentSquad {
    final available = mySquads;
    if (available.isEmpty) return null;
    for (final squad in available) {
      if (squad.id == currentSquadId) return squad;
    }
    return available.first;
  }

  SquadMember? get myCurrentMembership {
    final user = currentUser;
    final squad = currentSquad;
    if (user == null || squad == null) return null;
    for (final member in members) {
      if (member.squadId == squad.id && member.userId == user.id) {
        return member;
      }
    }
    return null;
  }

  bool get isCaptain => myCurrentMembership?.role == 'captain';

  List<SquadMember> membersFor(String squadId) {
    return members.where((member) => member.squadId == squadId).toList();
  }

  User? userById(String userId) {
    for (final user in users) {
      if (user.id == userId) return user;
    }
    return null;
  }

  List<DailyTask> tasksFor(String squadId) {
    return dailyTasks
        .where((task) => task.squadId == squadId && task.isActive)
        .toList();
  }

  List<CheckIn> todayCheckInsFor(String squadId, DateTime today) {
    return checkIns
        .where(
          (checkIn) =>
              checkIn.squadId == squadId &&
              _isSameDate(checkIn.checkedAt, today),
        )
        .toList();
  }

  List<PublicFund> fundsFor(String squadId) {
    return publicFunds.where((fund) => fund.squadId == squadId).toList();
  }

  List<SharedExpense> expensesFor(String squadId) {
    return sharedExpenses
        .where((expense) => expense.squadId == squadId)
        .toList();
  }

  List<PrivateAsset> get myPrivateAssets {
    final user = currentUser;
    if (user == null) return const [];
    return privateAssets.where((asset) => asset.userId == user.id).toList();
  }

  List<TravelPlan> plansFor(String squadId) {
    return travelPlans.where((plan) => plan.squadId == squadId).toList();
  }

  List<FoodSpot> foodFor(String squadId) {
    final items = foodSpots.where((food) => food.squadId == squadId).toList();
    items.sort((a, b) => b.score.compareTo(a.score));
    return items;
  }

  List<ExternalDataItem> get myImportedData {
    final user = currentUser;
    if (user == null) return const [];
    final items = externalDataItems
        .where((item) => item.userId == user.id)
        .toList();
    items.sort((a, b) => b.importedAt.compareTo(a.importedAt));
    return items;
  }

  List<DataConnection> get myDataConnections {
    final user = currentUser;
    if (user == null) return const [];
    return dataConnections
        .where((connection) => connection.userId == user.id)
        .toList();
  }

  List<SocialPost> postsFor(String squadId) {
    final user = currentUser;
    if (user == null || !_isCurrentUserMemberOf(squadId)) return const [];
    final posts = socialPosts.where((post) {
      if (post.squadId != squadId) return false;
      return post.visibility == 'squad' ||
          post.authorId == user.id ||
          post.visibleToUserIds.contains(user.id);
    }).toList();
    posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return posts;
  }

  List<CircleMessage> messagesFor(String squadId) {
    if (!_isCurrentUserMemberOf(squadId)) return const [];
    final messages = circleMessages
        .where((message) => message.squadId == squadId)
        .toList();
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return messages;
  }

  bool _isCurrentUserMemberOf(String squadId) {
    final user = currentUser;
    if (user == null) return false;
    return members.any(
      (member) => member.squadId == squadId && member.userId == user.id,
    );
  }

  int caloriesBurnedBy(String userId, DateTime date) {
    return healthSnapshots
        .where(
          (snapshot) =>
              snapshot.userId == userId &&
              _isSameDate(snapshot.recordedDate, date),
        )
        .fold(0, (sum, snapshot) => sum + (snapshot.caloriesBurned ?? 0));
  }

  double fundBalance(String fundId) {
    final fund = publicFunds.where((item) => item.id == fundId).firstOrNull;
    if (fund == null) return 0;
    return fund.currentAmount;
  }

  DemoAppState copyWith({
    User? currentUser,
    bool clearCurrentUser = false,
    String? currentSquadId,
    bool clearCurrentSquad = false,
    List<User>? users,
    List<Squad>? squads,
    List<SquadMember>? members,
    List<WorkoutPlan>? workoutPlans,
    List<DailyTask>? dailyTasks,
    List<CheckIn>? checkIns,
    List<HealthSnapshot>? healthSnapshots,
    List<PublicFund>? publicFunds,
    List<FundTransaction>? fundTransactions,
    List<PrivateAsset>? privateAssets,
    List<SharedExpense>? sharedExpenses,
    List<TravelPlan>? travelPlans,
    List<FoodSpot>? foodSpots,
    List<ExternalDataItem>? externalDataItems,
    List<DataConnection>? dataConnections,
    List<SocialPost>? socialPosts,
    List<CircleMessage>? circleMessages,
  }) {
    return DemoAppState(
      currentUser: clearCurrentUser ? null : currentUser ?? this.currentUser,
      currentSquadId: clearCurrentSquad
          ? null
          : currentSquadId ?? this.currentSquadId,
      users: users ?? this.users,
      squads: squads ?? this.squads,
      members: members ?? this.members,
      workoutPlans: workoutPlans ?? this.workoutPlans,
      dailyTasks: dailyTasks ?? this.dailyTasks,
      checkIns: checkIns ?? this.checkIns,
      healthSnapshots: healthSnapshots ?? this.healthSnapshots,
      publicFunds: publicFunds ?? this.publicFunds,
      fundTransactions: fundTransactions ?? this.fundTransactions,
      privateAssets: privateAssets ?? this.privateAssets,
      sharedExpenses: sharedExpenses ?? this.sharedExpenses,
      travelPlans: travelPlans ?? this.travelPlans,
      foodSpots: foodSpots ?? this.foodSpots,
      externalDataItems: externalDataItems ?? this.externalDataItems,
      dataConnections: dataConnections ?? this.dataConnections,
      socialPosts: socialPosts ?? this.socialPosts,
      circleMessages: circleMessages ?? this.circleMessages,
    );
  }
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
