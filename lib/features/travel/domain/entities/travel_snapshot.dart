import '../../../finance/domain/entities/public_fund.dart';
import 'travel_plan.dart';

final class TravelSnapshot {
  const TravelSnapshot({required this.plans, required this.funds});

  final List<TravelPlan> plans;
  final List<PublicFund> funds;
}
