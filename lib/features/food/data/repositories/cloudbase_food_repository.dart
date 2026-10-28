import 'package:fpdart/fpdart.dart';
import 'package:postgrest/postgrest.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/food_spot.dart';
import '../../domain/repositories/food_repository.dart';

typedef CurrentFoodUserId = Future<String?> Function();

final class CloudBaseFoodRepository implements FoodRepository {
  const CloudBaseFoodRepository({
    required this._client,
    required this._currentUserId,
  });

  final PostgrestClient _client;
  final CurrentFoodUserId _currentUserId;

  @override
  Future<Either<Failure, List<FoodSpot>>> getSquadFoodSpots({
    required String squadId,
  }) async {
    try {
      final rows = await _client
          .from('food_spots')
          .select()
          .eq('squad_id', squadId)
          .order('created_at', ascending: false);
      final spots = (rows as List)
          .map((row) => _map(row))
          .toList(growable: false);
      if (spots.isEmpty) return right(const []);

      final votes = await _client
          .from('food_votes')
          .select('food_spot_id,user_id,vote')
          .inFilter(
            'food_spot_id',
            spots.map((spot) => spot['id'] as String).toList(),
          );
      final votesBySpot = <String, Map<String, int>>{};
      for (final row in votes as List) {
        final vote = _map(row);
        (votesBySpot[vote['food_spot_id'] as String] ??= {})[vote['user_id']
            as String] = (vote['vote'] as num)
            .toInt();
      }
      return right(
        spots
            .map(
              (row) => _spot(row, votesBySpot[row['id'] as String] ?? const {}),
            )
            .toList(growable: false),
      );
    } on PostgrestException catch (error) {
      return left(_serverFailure(error));
    } catch (_) {
      return left(const Failure.network(message: '无法连接美食服务'));
    }
  }

  @override
  Future<Either<Failure, FoodSpot>> addFoodSpot({
    required String squadId,
    required String name,
    required String category,
    required double averageCost,
    required int caloriesEstimate,
    String? address,
    String? note,
  }) async {
    final userId = await _currentUserId();
    if (userId == null || userId.isEmpty) {
      return left(const Failure.unauthorized());
    }
    try {
      final row = await _client
          .from('food_spots')
          .insert({
            'squad_id': squadId,
            'name': name.trim(),
            'category': category,
            'average_cost': averageCost,
            'calories_estimate': caloriesEstimate,
            'address': _text(address),
            'note': _text(note),
            'added_by': userId,
          })
          .select()
          .single();
      return right(_spot(_map(row), const {}));
    } on PostgrestException catch (error) {
      return left(_serverFailure(error));
    } catch (_) {
      return left(const Failure.network(message: '无法连接美食服务'));
    }
  }

  @override
  Future<Either<Failure, Unit>> voteFoodSpot({
    required String foodSpotId,
    required int vote,
  }) async {
    if (vote < -1 || vote > 1) {
      return left(const Failure.validation(message: '投票值无效'));
    }
    final userId = await _currentUserId();
    if (userId == null || userId.isEmpty) {
      return left(const Failure.unauthorized());
    }
    try {
      await _client.from('food_votes').upsert({
        'food_spot_id': foodSpotId,
        'user_id': userId,
        'vote': vote,
      }, onConflict: 'food_spot_id,user_id');
      return right(unit);
    } on PostgrestException catch (error) {
      return left(_serverFailure(error));
    } catch (_) {
      return left(const Failure.network(message: '无法提交投票'));
    }
  }
}

FoodSpot _spot(Map<String, dynamic> row, Map<String, int> votes) => FoodSpot(
  id: row['id'] as String,
  squadId: row['squad_id'] as String,
  name: row['name'] as String,
  category: row['category'] as String,
  averageCost: (row['average_cost'] as num).toDouble(),
  caloriesEstimate: (row['calories_estimate'] as num).toInt(),
  addedBy: row['added_by'] as String,
  createdAt: DateTime.parse(row['created_at'] as String),
  address: row['address'] as String?,
  note: row['note'] as String?,
  votes: votes,
);

Map<String, dynamic> _map(Object? row) => Map<String, dynamic>.from(row as Map);
String? _text(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();
Failure _serverFailure(PostgrestException error) => switch (error.code) {
  '42501' || 'PGRST301' => const Failure.permissionDenied(),
  'PGRST116' => const Failure.notFound(),
  _ => const Failure.server(message: '美食数据操作失败'),
};
