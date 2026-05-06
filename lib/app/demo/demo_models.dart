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

class TravelPlan {
  const TravelPlan({
    required this.id,
    required this.squadId,
    required this.title,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.budget,
    required this.linkedFundId,
    required this.createdBy,
    required this.createdAt,
    this.notes,
  });

  final String id;
  final String squadId;
  final String title;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final double budget;
  final String? linkedFundId;
  final String createdBy;
  final DateTime createdAt;
  final String? notes;

  TravelPlan copyWith({
    String? id,
    String? squadId,
    String? title,
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    double? budget,
    String? linkedFundId,
    String? createdBy,
    DateTime? createdAt,
    String? notes,
  }) {
    return TravelPlan(
      id: id ?? this.id,
      squadId: squadId ?? this.squadId,
      title: title ?? this.title,
      destination: destination ?? this.destination,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      budget: budget ?? this.budget,
      linkedFundId: linkedFundId ?? this.linkedFundId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
    );
  }
}

class FoodSpot {
  const FoodSpot({
    required this.id,
    required this.squadId,
    required this.name,
    required this.category,
    required this.averageCost,
    required this.caloriesEstimate,
    required this.addedBy,
    required this.createdAt,
    this.address,
    this.note,
    this.votes = const {},
  });

  final String id;
  final String squadId;
  final String name;
  final String category;
  final double averageCost;
  final int caloriesEstimate;
  final String addedBy;
  final DateTime createdAt;
  final String? address;
  final String? note;
  final Map<String, int> votes;

  int get score => votes.values.fold(0, (sum, vote) => sum + vote);

  FoodSpot copyWith({
    String? id,
    String? squadId,
    String? name,
    String? category,
    double? averageCost,
    int? caloriesEstimate,
    String? addedBy,
    DateTime? createdAt,
    String? address,
    String? note,
    Map<String, int>? votes,
  }) {
    return FoodSpot(
      id: id ?? this.id,
      squadId: squadId ?? this.squadId,
      name: name ?? this.name,
      category: category ?? this.category,
      averageCost: averageCost ?? this.averageCost,
      caloriesEstimate: caloriesEstimate ?? this.caloriesEstimate,
      addedBy: addedBy ?? this.addedBy,
      createdAt: createdAt ?? this.createdAt,
      address: address ?? this.address,
      note: note ?? this.note,
      votes: votes ?? this.votes,
    );
  }
}

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
    final id =
        currentSquadId ?? (mySquads.isNotEmpty ? mySquads.first.id : null);
    if (id == null) return null;
    for (final squad in squads) {
      if (squad.id == id) return squad;
    }
    return mySquads.isNotEmpty ? mySquads.first : null;
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
    );
  }
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
