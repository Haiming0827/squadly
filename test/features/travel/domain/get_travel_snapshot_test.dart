import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/finance/domain/entities/public_fund.dart';
import 'package:squadly/features/finance/domain/repositories/finance_repository.dart';
import 'package:squadly/features/travel/domain/entities/travel_plan.dart';
import 'package:squadly/features/travel/domain/repositories/travel_repository.dart';
import 'package:squadly/features/travel/domain/usecases/get_travel_snapshot.dart';

void main() {
  test(
    'combines Squad trips with shared funds through domain repositories',
    () async {
      final plan = TravelPlan(
        id: 'trip-a',
        squadId: 'squad-a',
        title: '海边周末',
        destination: '青岛',
        startDate: DateTime.utc(2026, 11, 1),
        endDate: DateTime.utc(2026, 11, 3),
        budget: 2000,
        createdBy: 'user-a',
        createdAt: DateTime.utc(2026, 10, 18),
      );
      final fund = PublicFund(
        id: 'fund-a',
        squadId: 'squad-a',
        name: '旅行基金',
        fundType: 'travel',
        createdBy: 'user-a',
        createdAt: DateTime.utc(2026, 10, 1),
      );
      final travel = _TravelRepository(right([plan]));
      final finance = _FinanceRepository(right([fund]));

      final result = await GetTravelSnapshot(
        travelRepository: travel,
        financeRepository: finance,
      )(squadId: 'squad-a');

      expect(result.match((failure) => failure, (snapshot) => snapshot.plans), [
        plan,
      ]);
      expect(result.match((failure) => failure, (snapshot) => snapshot.funds), [
        fund,
      ]);
      expect(finance.requestedSquadId, 'squad-a');
    },
  );

  test('returns trip failure without requesting public funds', () async {
    final finance = _FinanceRepository(right(const []));
    final result = await GetTravelSnapshot(
      travelRepository: _TravelRepository(
        left(const Failure.network(message: 'offline')),
      ),
      financeRepository: finance,
    )(squadId: 'squad-a');

    expect(result.isLeft(), isTrue);
    expect(finance.requestCount, 0);
  });
}

final class _TravelRepository implements TravelRepository {
  _TravelRepository(this.plans);

  final Either<Failure, List<TravelPlan>> plans;

  @override
  Future<Either<Failure, List<TravelPlan>>> getSquadTravelPlans({
    required String squadId,
  }) async => plans;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FinanceRepository implements FinanceRepository {
  _FinanceRepository(this.funds);

  final Either<Failure, List<PublicFund>> funds;
  String? requestedSquadId;
  int requestCount = 0;

  @override
  Future<Either<Failure, List<PublicFund>>> getSquadFunds({
    required String squadId,
  }) async {
    requestedSquadId = squadId;
    requestCount++;
    return funds;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
