import 'package:drift/drift.dart';

import '../domain/timeline_entry.dart';

part 'conversation_cache_database.g.dart';

class CachedTimelineEntries extends Table {
  TextColumn get userId => text()();
  TextColumn get squadId => text()();
  TextColumn get planId => text()();
  TextColumn get messageId => text()();
  IntColumn get createdAtMicros => integer()();
  TextColumn get encryptedPayload => text()();
  @override
  Set<Column> get primaryKey => {userId, squadId, planId, messageId};
}

class CachedConversationLabels extends Table {
  TextColumn get userId => text()();
  TextColumn get squadId => text()();
  TextColumn get planId => text()();
  TextColumn get encryptedPayload => text()();
  @override
  Set<Column> get primaryKey => {userId, squadId, planId};
}

@DriftDatabase(tables: [CachedTimelineEntries, CachedConversationLabels])
final class ConversationCacheDatabase extends _$ConversationCacheDatabase {
  ConversationCacheDatabase(super.executor);
  @override
  int get schemaVersion => 2;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) await migrator.createTable(cachedConversationLabels);
    },
  );

  Future<void> saveRow(CachedTimelineEntriesCompanion row) =>
      into(cachedTimelineEntries).insertOnConflictUpdate(row);

  Future<List<CachedTimelineEntry>> pageRows({
    required String userId,
    required String squadId,
    required String planId,
    TimelineCursor? before,
    TimelineCursor? after,
    int limit = 50,
  }) async {
    final table = cachedTimelineEntries;
    final query = select(table)
      ..where(
        (row) =>
            row.userId.equals(userId) &
            row.squadId.equals(squadId) &
            row.planId.equals(planId),
      );
    if (before != null) {
      final time = before.createdAt.toUtc().microsecondsSinceEpoch;
      query.where(
        (row) =>
            row.createdAtMicros.isSmallerThanValue(time) |
            (row.createdAtMicros.equals(time) &
                row.messageId.isSmallerThanValue(before.id)),
      );
    }
    if (after != null) {
      final time = after.createdAt.toUtc().microsecondsSinceEpoch;
      query.where(
        (row) =>
            row.createdAtMicros.isBiggerThanValue(time) |
            (row.createdAtMicros.equals(time) &
                row.messageId.isBiggerThanValue(after.id)),
      );
    }
    query
      ..orderBy([
        (row) => OrderingTerm(
          expression: row.createdAtMicros,
          mode: after == null ? OrderingMode.desc : OrderingMode.asc,
        ),
        (row) => OrderingTerm(
          expression: row.messageId,
          mode: after == null ? OrderingMode.desc : OrderingMode.asc,
        ),
      ])
      ..limit(limit.clamp(1, 50));
    final rows = await query.get();
    return after == null ? rows.reversed.toList() : rows;
  }

  Future<void> clearUser(String userId) async {
    await transaction(() async {
      await (delete(
        cachedTimelineEntries,
      )..where((row) => row.userId.equals(userId))).go();
      await (delete(
        cachedConversationLabels,
      )..where((row) => row.userId.equals(userId))).go();
    });
  }

  Future<List<({String squadId, String planId})>> threadScopes(
    String userId,
  ) async {
    final rows = await customSelect(
      'SELECT squad_id, plan_id FROM cached_timeline_entries WHERE user_id = ? '
      'GROUP BY squad_id, plan_id ORDER BY MAX(created_at_micros) DESC, squad_id, plan_id',
      variables: [Variable(userId)],
      readsFrom: {cachedTimelineEntries},
    ).get();
    return [
      for (final row in rows)
        (
          squadId: row.read<String>('squad_id'),
          planId: row.read<String>('plan_id'),
        ),
    ];
  }

  Future<void> saveLabel(CachedConversationLabelsCompanion row) =>
      into(cachedConversationLabels).insertOnConflictUpdate(row);

  Future<List<String>> cachedUserIds() async {
    final rows = await customSelect(
      'SELECT user_id FROM cached_timeline_entries '
      'UNION SELECT user_id FROM cached_conversation_labels',
      readsFrom: {cachedTimelineEntries, cachedConversationLabels},
    ).get();
    return [for (final row in rows) row.read<String>('user_id')];
  }

  Future<CachedConversationLabel?> labelFor(
    String userId,
    String squadId,
    String planId,
  ) =>
      (select(cachedConversationLabels)..where(
            (row) =>
                row.userId.equals(userId) &
                row.squadId.equals(squadId) &
                row.planId.equals(planId),
          ))
          .getSingleOrNull();
}
