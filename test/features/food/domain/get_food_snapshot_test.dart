import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/fitness/domain/repositories/fitness_repository.dart';
import 'package:squadly/features/food/domain/entities/food_spot.dart';
import 'package:squadly/features/food/domain/repositories/food_repository.dart';
import 'package:squadly/features/food/domain/usecases/get_food_snapshot.dart';

void main() {
  final date = DateTime.utc(2026, 10, 18);

  test('combines Squad food and the current member calories', () async {
    final spots = [
      _spot(id: 'a', votes: const {'u1': 1}),
      _spot(id: 'b', votes: const {'u1': 2, 'u2': 1}),
    ];
    final foods = _FoodRepository(right(spots));
    final fitness = _FitnessRepository(right(321));

    final result = await GetFoodSnapshot(
      foodRepository: foods,
      fitnessRepository: fitness,
    )(squadId: 'squad-a', userId: 'user-a', date: date);

    expect(
      result.match((failure) => failure, (snapshot) => snapshot.spots),
      spots,
    );
    expect(
      result.match((failure) => failure, (snapshot) => snapshot.caloriesBurned),
      321,
    );
    expect(
      result.match(
        (failure) => failure,
        (snapshot) => snapshot.recommended?.id,
      ),
      'b',
    );
    expect(fitness.requestedUserId, 'user-a');
    expect(fitness.requestedDate, date);
  });

  test('returns food access failure without requesting health data', () async {
    const failure = Failure.network(message: 'offline');
    final fitness = _FitnessRepository(right(0));
    final result = await GetFoodSnapshot(
      foodRepository: _FoodRepository(left(failure)),
      fitnessRepository: fitness,
    )(squadId: 'squad-a', userId: 'user-a', date: date);

    expect(result.match((value) => value, (_) => null), failure);
    expect(fitness.requestCount, 0);
  });

  test('does not request health data without a signed-in member', () async {
    final fitness = _FitnessRepository(right(0));
    final result = await GetFoodSnapshot(
      foodRepository: _FoodRepository(right(const [])),
      fitnessRepository: fitness,
    )(squadId: 'squad-a', userId: null, date: date);

    expect(result.isLeft(), isTrue);
    expect(fitness.requestCount, 0);
  });
}

FoodSpot _spot({required String id, required Map<String, int> votes}) =>
    FoodSpot(
      id: id,
      squadId: 'squad-a',
      name: id,
      category: '主食',
      averageCost: 10,
      caloriesEstimate: 400,
      addedBy: 'user-a',
      createdAt: DateTime.utc(2026, 10, 18),
      votes: votes,
    );

final class _FoodRepository implements FoodRepository {
  _FoodRepository(this.foods);

  final Either<Failure, List<FoodSpot>> foods;

  @override
  Future<Either<Failure, List<FoodSpot>>> getSquadFoodSpots({
    required String squadId,
  }) async => foods;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FitnessRepository implements FitnessRepository {
  _FitnessRepository(this.calories);

  final Either<Failure, int> calories;
  String? requestedUserId;
  DateTime? requestedDate;
  int requestCount = 0;

  @override
  Future<Either<Failure, int>> getDailyCaloriesBurned({
    required String userId,
    required DateTime date,
  }) async {
    requestCount++;
    requestedUserId = userId;
    requestedDate = date;
    return calories;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
