/// Supabase 表名常量
class SupabaseConstants {
  SupabaseConstants._();

  // 核心表
  static const String profiles = 'profiles';
  static const String squads = 'squads';
  static const String squadMembers = 'squad_members';

  // 健身模块
  static const String workoutPlans = 'workout_plans';
  static const String dailyTasks = 'daily_tasks';
  static const String checkIns = 'check_ins';
  static const String healthSnapshots = 'health_snapshots';
  static const String squadRules = 'squad_rules';

  // 理财模块
  static const String publicFunds = 'public_funds';
  static const String fundTransactions = 'fund_transactions';
  static const String privateAssets = 'private_assets';
  static const String sharedExpenses = 'shared_expenses';
  static const String watchlistItems = 'watchlist_items';

  // 旅行模块
  static const String travelPlans = 'travel_plans';

  // 美食模块
  static const String foodSpots = 'food_spots';
  static const String foodVotes = 'food_votes';
}
