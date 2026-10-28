import 'package:drift/drift.dart';

part 'conversation_outbox_database.g.dart';

class OutboxEntries extends Table {
  TextColumn get userId => text()();
  TextColumn get squadId => text()();
  TextColumn get planId => text().withDefault(const Constant(''))();
  TextColumn get clientNonce => text()();
  IntColumn get createdAtMicros => integer()();
  TextColumn get encryptedPayload => text()();

  @override
  Set<Column> get primaryKey => {userId, squadId, planId, clientNonce};
}

final class EncryptedOutboxEntry {
  const EncryptedOutboxEntry({
    required this.userId,
    required this.squadId,
    required this.planId,
    required this.clientNonce,
    required this.createdAtMicros,
    required this.encryptedPayload,
  });

  final String userId;
  final String squadId;
  final String planId;
  final String clientNonce;
  final int createdAtMicros;
  final String encryptedPayload;
}

@DriftDatabase(tables: [OutboxEntries])
final class ConversationOutboxDatabase extends _$ConversationOutboxDatabase {
  ConversationOutboxDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.alterTable(
          TableMigration(outboxEntries, newColumns: [outboxEntries.planId]),
        );
      }
    },
  );

  Future<void> putEncrypted(EncryptedOutboxEntry entry) async {
    await into(outboxEntries).insert(
      OutboxEntriesCompanion.insert(
        userId: entry.userId,
        squadId: entry.squadId,
        planId: Value(entry.planId),
        clientNonce: entry.clientNonce,
        createdAtMicros: entry.createdAtMicros,
        encryptedPayload: entry.encryptedPayload,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<List<EncryptedOutboxEntry>> listEncrypted({
    required String userId,
    required String squadId,
    required String planId,
  }) async {
    final rows =
        await (select(outboxEntries)
              ..where(
                (table) =>
                    table.userId.equals(userId) &
                    table.squadId.equals(squadId) &
                    table.planId.equals(planId),
              )
              ..orderBy([
                (table) => OrderingTerm.asc(table.createdAtMicros),
                (table) => OrderingTerm.asc(table.clientNonce),
              ]))
            .get();
    return [
      for (final row in rows)
        EncryptedOutboxEntry(
          userId: row.userId,
          squadId: row.squadId,
          planId: row.planId,
          clientNonce: row.clientNonce,
          createdAtMicros: row.createdAtMicros,
          encryptedPayload: row.encryptedPayload,
        ),
    ];
  }

  Future<bool> hasRowsForUser(String userId) async {
    final rows =
        await (select(outboxEntries)
              ..where((table) => table.userId.equals(userId))
              ..limit(1))
            .get();
    return rows.isNotEmpty;
  }

  Future<EncryptedOutboxEntry?> readEncrypted({
    required String userId,
    required String squadId,
    required String clientNonce,
    String planId = '',
  }) async {
    final row =
        await (select(outboxEntries)..where(
              (r) =>
                  r.userId.equals(userId) &
                  r.squadId.equals(squadId) &
                  r.planId.equals(planId) &
                  r.clientNonce.equals(clientNonce),
            ))
            .getSingleOrNull();
    return row == null
        ? null
        : EncryptedOutboxEntry(
            userId: row.userId,
            squadId: row.squadId,
            planId: row.planId,
            clientNonce: row.clientNonce,
            createdAtMicros: row.createdAtMicros,
            encryptedPayload: row.encryptedPayload,
          );
  }

  Future<void> removeEncrypted({
    required String userId,
    required String squadId,
    required String clientNonce,
    required String planId,
  }) async {
    await (delete(outboxEntries)..where(
          (table) =>
              table.userId.equals(userId) &
              table.squadId.equals(squadId) &
              table.planId.equals(planId) &
              table.clientNonce.equals(clientNonce),
        ))
        .go();
  }
}
