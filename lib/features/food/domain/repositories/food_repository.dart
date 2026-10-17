import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/food_spot.dart';

abstract class FoodRepository {
  Future<Either<Failure, List<FoodSpot>>> getSquadFoodSpots({
    required String squadId,
  });

  Future<Either<Failure, FoodSpot>> addFoodSpot({
    required String squadId,
    required String name,
    required String category,
    required double averageCost,
    required int caloriesEstimate,
    String? address,
    String? note,
  });

  Future<Either<Failure, Unit>> voteFoodSpot({
    required String foodSpotId,
    required int vote,
  });
}
