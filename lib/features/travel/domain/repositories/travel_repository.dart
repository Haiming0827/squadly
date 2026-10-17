import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/travel_plan.dart';

abstract class TravelRepository {
  Future<Either<Failure, TravelPlan>> createTravelPlan({
    required String squadId,
    required String title,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required double budget,
    String? linkedFundId,
    String? notes,
  });

  Future<Either<Failure, List<TravelPlan>>> getSquadTravelPlans({
    required String squadId,
  });
}
