import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../fitness/domain/repositories/fitness_repository.dart';
import '../entities/food_snapshot.dart';
import '../repositories/food_repository.dart';

final class GetFoodSnapshot {
  const GetFoodSnapshot({
    required this._foodRepository,
    required this._fitnessRepository,
  });

  final FoodRepository _foodRepository;
  final FitnessRepository _fitnessRepository;

  Future<Either<Failure, FoodSnapshot>> call({
    required String squadId,
    required String? userId,
    required DateTime date,
  }) async {
    final foods = await _foodRepository.getSquadFoodSpots(squadId: squadId);
    return foods.fold((failure) async => left(failure), (spots) async {
      final id = userId;
      if (id == null || id.isEmpty) {
        return left(const Failure.unauthorized());
      }
      final calories = await _fitnessRepository.getDailyCaloriesBurned(
        userId: id,
        date: date,
      );
      return calories.map(
        (value) => FoodSnapshot(spots: spots, caloriesBurned: value),
      );
    });
  }
}
