import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:postgrest/postgrest.dart';

import '../../../core/error/failures.dart';
import '../domain/entities/data_connection.dart';
import '../domain/entities/external_data_item.dart';
import '../domain/entities/social_post.dart';
import '../domain/repositories/social_repository.dart';

typedef CurrentSocialUserId = Future<String?> Function();

/// CloudBase adapter for owner-only imported materials and published snapshots.
/// Live updates use bounded polling until CloudBase Realtime is verified.
final class CloudBaseSocialRepository implements SocialRepository {
  const CloudBaseSocialRepository({
    required this._client,
    required this._currentUserId,
    this.pollInterval = const Duration(seconds: 20),
  });

  final PostgrestClient _client;
  final CurrentSocialUserId _currentUserId;
  final Duration pollInterval;

  @override
  Future<Either<Failure, List<ExternalDataItem>>> getMyImportedData() =>
      _capture(() async {
        final userId = await _requireUserId();
        final rows = await _client
            .from('external_data_items')
            .select()
            .eq('user_id', userId)
            .order('imported_at', ascending: false)
            .limit(200);
        return (rows as List)
            .map((row) => _externalItem(_map(row)))
            .toList(growable: false);
      });

  @override
  Future<Either<Failure, List<DataConnection>>> getMyConnections() =>
      _capture(() async {
        final userId = await _requireUserId();
        final rows = await _client
            .from('external_data_connections')
            .select()
            .eq('user_id', userId)
            .order('provider');
        return (rows as List)
            .map((row) => _connection(_map(row)))
            .toList(growable: false);
      });

  @override
  Future<Either<Failure, ExternalDataItem>> importDataItem({
    required ExternalDataItem item,
  }) => _capture(() async {
    final userId = await _requireUserId();
    _validateDataItem(item);
    final row = await _client
        .from('external_data_items')
        .insert({
          'user_id': userId,
          'source': item.source,
          'source_label': item.sourceLabel,
          'category': item.category,
          'title': item.title.trim(),
          'summary': item.summary,
          'metric_value': item.value,
          'metric_unit': item.unit,
          'range_start': item.rangeStart.toUtc().toIso8601String(),
          'range_end': item.rangeEnd.toUtc().toIso8601String(),
          'imported_at': item.importedAt.toUtc().toIso8601String(),
          'trend': item.trend,
        })
        .select()
        .single();
    return _externalItem(_map(row));
  });

  @override
  Stream<Either<Failure, List<SocialPost>>> watchPosts(String squadId) async* {
    yield await _loadPosts(squadId);
    yield* Stream<void>.periodic(pollInterval).asyncMap((_) {
      return _loadPosts(squadId);
    });
  }

  Future<Either<Failure, List<SocialPost>>> _loadPosts(String squadId) =>
      _capture(() async {
        await _requireUserId();
        final rows = await _client
            .from('social_posts')
            .select()
            .eq('squad_id', squadId)
            .order('created_at', ascending: false)
            .order('id', ascending: false)
            .limit(50);
        final postRows = (rows as List).map(_map).toList(growable: false);
        if (postRows.isEmpty) return const <SocialPost>[];

        final postIds = postRows.map((row) => row['id'] as String).toList();
        final reactionRows = await _client
            .from('social_post_reactions')
            .select('post_id,user_id')
            .inFilter('post_id', postIds);
        final reactions = <String, List<String>>{};
        for (final rawRow in reactionRows as List) {
          final row = _map(rawRow);
          reactions
              .putIfAbsent(row['post_id'] as String, () => <String>[])
              .add(row['user_id'] as String);
        }
        return postRows
            .map((row) => _socialPost(row, reactions[row['id']] ?? const []))
            .toList(growable: false);
      });

  @override
  Future<Either<Failure, SocialPost>> publishDataPost({
    required String squadId,
    required String dataItemId,
    required String title,
    required String body,
    required String template,
    required String visibility,
    List<String> visibleToUserIds = const [],
  }) => _capture(() async {
    await _requireUserId();
    final result = await _client.rpc(
      'publish_social_post',
      params: {
        'p_squad_id': squadId,
        'p_data_item_id': dataItemId,
        'p_title': title.trim(),
        'p_body': body.trim(),
        'p_template': template,
        'p_visibility': visibility,
        'p_visible_to_user_ids': visibility == 'selected'
            ? visibleToUserIds
            : const <String>[],
      },
    );
    return _socialPost(_map(result), const []);
  });

  @override
  Future<Either<Failure, bool>> togglePostReaction({
    required String postId,
    required String squadId,
  }) => _capture(() async {
    await _requireUserId();
    final result = await _client.rpc(
      'toggle_social_post_reaction',
      params: {'p_post_id': postId, 'p_squad_id': squadId},
    );
    if (result is! bool) throw const FormatException('Invalid reaction reply');
    return result;
  });

  Future<String> _requireUserId() async {
    final id = await _currentUserId();
    if (id == null || id.isEmpty) throw const _Unauthenticated();
    return id;
  }

  Future<Either<Failure, T>> _capture<T>(Future<T> Function() operation) async {
    try {
      return right(await operation());
    } on _Unauthenticated {
      return left(const Failure.unauthorized());
    } on _InvalidMaterial catch (error) {
      return left(Failure.validation(message: error.message));
    } on PostgrestException catch (error) {
      if (error.code == '42501' || error.code == 'PGRST301') {
        return left(const Failure.permissionDenied());
      }
      if (error.code == '23514' || error.code == '22023') {
        return left(const Failure.validation(message: '分享内容不符合要求'));
      }
      if (error.code == '23503') {
        return left(const Failure.validation(message: '小队或成员不存在'));
      }
      if (error.code == 'PGRST116') return left(const Failure.notFound());
      return left(const Failure.server(message: '分享数据操作失败'));
    } on FormatException {
      return left(const Failure.server(message: '分享数据格式无效'));
    } catch (_) {
      return left(const Failure.network(message: '无法连接分享服务'));
    }
  }

  void _validateDataItem(ExternalDataItem item) {
    if (item.source.trim().isEmpty ||
        item.source.length > 80 ||
        item.sourceLabel.trim().isEmpty ||
        item.sourceLabel.length > 120 ||
        item.category.trim().isEmpty ||
        item.category.length > 80 ||
        item.title.trim().isEmpty ||
        item.title.trim().length > 160 ||
        item.value.length > 80 ||
        item.unit.length > 40 ||
        item.rangeEnd.isBefore(item.rangeStart) ||
        item.trend.length > 180) {
      throw const _InvalidMaterial('素材信息不符合要求');
    }
  }
}

ExternalDataItem _externalItem(Map<String, dynamic> row) => ExternalDataItem(
  id: row['id'] as String,
  userId: row['user_id'] as String,
  source: row['source'] as String,
  sourceLabel: row['source_label'] as String,
  category: row['category'] as String,
  title: row['title'] as String,
  summary: row['summary'] as String,
  value: row['metric_value'] as String,
  unit: row['metric_unit'] as String,
  rangeStart: DateTime.parse(row['range_start'] as String),
  rangeEnd: DateTime.parse(row['range_end'] as String),
  importedAt: DateTime.parse(row['imported_at'] as String),
  trend: _doubleList(row['trend']),
);

DataConnection _connection(Map<String, dynamic> row) => DataConnection(
  id: row['id'] as String,
  userId: row['user_id'] as String,
  provider: row['provider'] as String,
  displayName: row['display_name'] as String,
  mode: row['mode'] as String,
  isConnected: row['connected_at'] != null,
  enabledTypes: (row['enabled_types'] as List<dynamic>).cast<String>(),
  lastSyncedAt: _date(row['last_synced_at'] as String?),
);

SocialPost _socialPost(Map<String, dynamic> row, List<String> reactions) =>
    SocialPost(
      id: row['id'] as String,
      squadId: row['squad_id'] as String,
      authorId: row['author_id'] as String,
      authorName: row['author_name'] as String,
      title: row['title'] as String,
      body: row['body'] as String,
      template: row['template'] as String,
      visibility: row['visibility'] as String,
      sourceLabel: row['source_label'] as String,
      metricValue: row['metric_value'] as String,
      metricUnit: row['metric_unit'] as String,
      rangeStart: DateTime.parse(row['range_start'] as String),
      rangeEnd: DateTime.parse(row['range_end'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
      trend: _doubleList(row['trend']),
      visibleToUserIds: (row['visible_to_user_ids'] as List<dynamic>)
          .cast<String>(),
      reactionUserIds: reactions,
    );

List<double> _doubleList(Object? value) => (value as List<dynamic>? ?? const [])
    .map((item) => (item as num).toDouble())
    .toList(growable: false);

DateTime? _date(String? value) => value == null ? null : DateTime.parse(value);
Map<String, dynamic> _map(Object? row) => Map<String, dynamic>.from(row as Map);

final class _Unauthenticated implements Exception {
  const _Unauthenticated();
}

final class _InvalidMaterial implements Exception {
  const _InvalidMaterial(this.message);

  final String message;
}
