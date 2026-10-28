import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../finance/domain/repositories/finance_repository.dart';
import '../entities/travel_snapshot.dart';
import '../repositories/travel_repository.dart';

final class GetTravelSnapshot {
  const GetTravelSnapshot({
    required this._travelRepository,
    required this._financeRepository,
  });

  final TravelRepository _travelRepository;
  final FinanceRepository _financeRepository;

  Future<Either<Failure, TravelSnapshot>> call({
    required String squadId,
  }) async {
    final plans = await _travelRepository.getSquadTravelPlans(squadId: squadId);
    return plans.fold((failure) async => left(failure), (items) async {
      final funds = await _financeRepository.getSquadFunds(squadId: squadId);
      return funds.map((value) => TravelSnapshot(plans: items, funds: value));
    });
  }
}
