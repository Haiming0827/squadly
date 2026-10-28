import 'food_spot.dart';

final class FoodSnapshot {
  const FoodSnapshot({required this.spots, required this.caloriesBurned});

  final List<FoodSpot> spots;
  final int caloriesBurned;

  FoodSpot? get recommended {
    if (spots.isEmpty) return null;
    return spots.reduce(
      (current, candidate) =>
          candidate.score > current.score ? candidate : current,
    );
  }
}
