import 'package:fpdart/fpdart.dart';
import 'package:postgrest/postgrest.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/travel_plan.dart';
import '../../domain/repositories/travel_repository.dart';

typedef CurrentTravelUserId = Future<String?> Function();

final class CloudBaseTravelRepository implements TravelRepository {
  const CloudBaseTravelRepository({
    required this._client,
    required this._currentUserId,
  });

  final PostgrestClient _client;
  final CurrentTravelUserId _currentUserId;

  @override
  Future<Either<Failure, TravelPlan>> createTravelPlan({
    required String squadId,
    required String title,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required double budget,
    String? linkedFundId,
    String? notes,
  }) async {
    final userId = await _currentUserId();
    if (userId == null || userId.isEmpty) {
      return left(const Failure.unauthorized());
    }
    if (endDate.isBefore(startDate)) {
      return left(const Failure.validation(message: '结束日期不能早于开始日期'));
    }
    try {
      final row = await _client
          .from('travel_plans')
          .insert({
            'squad_id': squadId,
            'title': title.trim(),
            'destination': destination.trim(),
            'start_date': _date(startDate),
            'end_date': _date(endDate),
            'budget': budget,
            'linked_fund_id': linkedFundId,
            'notes': _text(notes),
            'created_by': userId,
          })
          .select()
          .single();
      return right(_plan(_map(row)));
    } on PostgrestException catch (error) {
      return left(_serverFailure(error));
    } catch (_) {
      return left(const Failure.network(message: '无法连接旅行服务'));
    }
  }

  @override
  Future<Either<Failure, List<TravelPlan>>> getSquadTravelPlans({
    required String squadId,
  }) async {
    try {
      final rows = await _client
          .from('travel_plans')
          .select()
          .eq('squad_id', squadId)
          .order('start_date');
      return right(
        (rows as List).map((row) => _plan(_map(row))).toList(growable: false),
      );
    } on PostgrestException catch (error) {
      return left(_serverFailure(error));
    } catch (_) {
      return left(const Failure.network(message: '无法连接旅行服务'));
    }
  }
}

TravelPlan _plan(Map<String, dynamic> row) => TravelPlan(
  id: row['id'] as String,
  squadId: row['squad_id'] as String,
  title: row['title'] as String,
  destination: row['destination'] as String,
  startDate: DateTime.parse(row['start_date'] as String),
  endDate: DateTime.parse(row['end_date'] as String),
  budget: (row['budget'] as num).toDouble(),
  linkedFundId: row['linked_fund_id'] as String?,
  createdBy: row['created_by'] as String,
  createdAt: DateTime.parse(row['created_at'] as String),
  notes: row['notes'] as String?,
);

Map<String, dynamic> _map(Object? row) => Map<String, dynamic>.from(row as Map);
String _date(DateTime value) => value.toIso8601String().split('T').first;
String? _text(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();
Failure _serverFailure(PostgrestException error) => switch (error.code) {
  '42501' || 'PGRST301' => const Failure.permissionDenied(),
  'PGRST116' => const Failure.notFound(),
  _ => const Failure.server(message: '旅行数据操作失败'),
};
