// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_outbox_database.dart';

// ignore_for_file: type=lint
class $OutboxEntriesTable extends OutboxEntries
    with TableInfo<$OutboxEntriesTable, OutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _squadIdMeta = const VerificationMeta(
    'squadId',
  );
  @override
  late final GeneratedColumn<String> squadId = GeneratedColumn<String>(
    'squad_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
    'plan_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _clientNonceMeta = const VerificationMeta(
    'clientNonce',
  );
  @override
  late final GeneratedColumn<String> clientNonce = GeneratedColumn<String>(
    'client_nonce',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMicrosMeta = const VerificationMeta(
    'createdAtMicros',
  );
  @override
  late final GeneratedColumn<int> createdAtMicros = GeneratedColumn<int>(
    'created_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encryptedPayloadMeta = const VerificationMeta(
    'encryptedPayload',
  );
  @override
  late final GeneratedColumn<String> encryptedPayload = GeneratedColumn<String>(
    'encrypted_payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    squadId,
    planId,
    clientNonce,
    createdAtMicros,
    encryptedPayload,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('squad_id')) {
      context.handle(
        _squadIdMeta,
        squadId.isAcceptableOrUnknown(data['squad_id']!, _squadIdMeta),
      );
    } else if (isInserting) {
      context.missing(_squadIdMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    }
    if (data.containsKey('client_nonce')) {
      context.handle(
        _clientNonceMeta,
        clientNonce.isAcceptableOrUnknown(
          data['client_nonce']!,
          _clientNonceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientNonceMeta);
    }
    if (data.containsKey('created_at_micros')) {
      context.handle(
        _createdAtMicrosMeta,
        createdAtMicros.isAcceptableOrUnknown(
          data['created_at_micros']!,
          _createdAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMicrosMeta);
    }
    if (data.containsKey('encrypted_payload')) {
      context.handle(
        _encryptedPayloadMeta,
        encryptedPayload.isAcceptableOrUnknown(
          data['encrypted_payload']!,
          _encryptedPayloadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedPayloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    userId,
    squadId,
    planId,
    clientNonce,
  };
  @override
  OutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxEntry(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      squadId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}squad_id'],
      )!,
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_id'],
      )!,
      clientNonce: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_nonce'],
      )!,
      createdAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_micros'],
      )!,
      encryptedPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_payload'],
      )!,
    );
  }

  @override
  $OutboxEntriesTable createAlias(String alias) {
    return $OutboxEntriesTable(attachedDatabase, alias);
  }
}

class OutboxEntry extends DataClass implements Insertable<OutboxEntry> {
  final String userId;
  final String squadId;
  final String planId;
  final String clientNonce;
  final int createdAtMicros;
  final String encryptedPayload;
  const OutboxEntry({
    required this.userId,
    required this.squadId,
    required this.planId,
    required this.clientNonce,
    required this.createdAtMicros,
    required this.encryptedPayload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['squad_id'] = Variable<String>(squadId);
    map['plan_id'] = Variable<String>(planId);
    map['client_nonce'] = Variable<String>(clientNonce);
    map['created_at_micros'] = Variable<int>(createdAtMicros);
    map['encrypted_payload'] = Variable<String>(encryptedPayload);
    return map;
  }

  OutboxEntriesCompanion toCompanion(bool nullToAbsent) {
    return OutboxEntriesCompanion(
      userId: Value(userId),
      squadId: Value(squadId),
      planId: Value(planId),
      clientNonce: Value(clientNonce),
      createdAtMicros: Value(createdAtMicros),
      encryptedPayload: Value(encryptedPayload),
    );
  }

  factory OutboxEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxEntry(
      userId: serializer.fromJson<String>(json['userId']),
      squadId: serializer.fromJson<String>(json['squadId']),
      planId: serializer.fromJson<String>(json['planId']),
      clientNonce: serializer.fromJson<String>(json['clientNonce']),
      createdAtMicros: serializer.fromJson<int>(json['createdAtMicros']),
      encryptedPayload: serializer.fromJson<String>(json['encryptedPayload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'squadId': serializer.toJson<String>(squadId),
      'planId': serializer.toJson<String>(planId),
      'clientNonce': serializer.toJson<String>(clientNonce),
      'createdAtMicros': serializer.toJson<int>(createdAtMicros),
      'encryptedPayload': serializer.toJson<String>(encryptedPayload),
    };
  }

  OutboxEntry copyWith({
    String? userId,
    String? squadId,
    String? planId,
    String? clientNonce,
    int? createdAtMicros,
    String? encryptedPayload,
  }) => OutboxEntry(
    userId: userId ?? this.userId,
    squadId: squadId ?? this.squadId,
    planId: planId ?? this.planId,
    clientNonce: clientNonce ?? this.clientNonce,
    createdAtMicros: createdAtMicros ?? this.createdAtMicros,
    encryptedPayload: encryptedPayload ?? this.encryptedPayload,
  );
  OutboxEntry copyWithCompanion(OutboxEntriesCompanion data) {
    return OutboxEntry(
      userId: data.userId.present ? data.userId.value : this.userId,
      squadId: data.squadId.present ? data.squadId.value : this.squadId,
      planId: data.planId.present ? data.planId.value : this.planId,
      clientNonce: data.clientNonce.present
          ? data.clientNonce.value
          : this.clientNonce,
      createdAtMicros: data.createdAtMicros.present
          ? data.createdAtMicros.value
          : this.createdAtMicros,
      encryptedPayload: data.encryptedPayload.present
          ? data.encryptedPayload.value
          : this.encryptedPayload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntry(')
          ..write('userId: $userId, ')
          ..write('squadId: $squadId, ')
          ..write('planId: $planId, ')
          ..write('clientNonce: $clientNonce, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('encryptedPayload: $encryptedPayload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userId,
    squadId,
    planId,
    clientNonce,
    createdAtMicros,
    encryptedPayload,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxEntry &&
          other.userId == this.userId &&
          other.squadId == this.squadId &&
          other.planId == this.planId &&
          other.clientNonce == this.clientNonce &&
          other.createdAtMicros == this.createdAtMicros &&
          other.encryptedPayload == this.encryptedPayload);
}

class OutboxEntriesCompanion extends UpdateCompanion<OutboxEntry> {
  final Value<String> userId;
  final Value<String> squadId;
  final Value<String> planId;
  final Value<String> clientNonce;
  final Value<int> createdAtMicros;
  final Value<String> encryptedPayload;
  final Value<int> rowid;
  const OutboxEntriesCompanion({
    this.userId = const Value.absent(),
    this.squadId = const Value.absent(),
    this.planId = const Value.absent(),
    this.clientNonce = const Value.absent(),
    this.createdAtMicros = const Value.absent(),
    this.encryptedPayload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxEntriesCompanion.insert({
    required String userId,
    required String squadId,
    this.planId = const Value.absent(),
    required String clientNonce,
    required int createdAtMicros,
    required String encryptedPayload,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       squadId = Value(squadId),
       clientNonce = Value(clientNonce),
       createdAtMicros = Value(createdAtMicros),
       encryptedPayload = Value(encryptedPayload);
  static Insertable<OutboxEntry> custom({
    Expression<String>? userId,
    Expression<String>? squadId,
    Expression<String>? planId,
    Expression<String>? clientNonce,
    Expression<int>? createdAtMicros,
    Expression<String>? encryptedPayload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (squadId != null) 'squad_id': squadId,
      if (planId != null) 'plan_id': planId,
      if (clientNonce != null) 'client_nonce': clientNonce,
      if (createdAtMicros != null) 'created_at_micros': createdAtMicros,
      if (encryptedPayload != null) 'encrypted_payload': encryptedPayload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxEntriesCompanion copyWith({
    Value<String>? userId,
    Value<String>? squadId,
    Value<String>? planId,
    Value<String>? clientNonce,
    Value<int>? createdAtMicros,
    Value<String>? encryptedPayload,
    Value<int>? rowid,
  }) {
    return OutboxEntriesCompanion(
      userId: userId ?? this.userId,
      squadId: squadId ?? this.squadId,
      planId: planId ?? this.planId,
      clientNonce: clientNonce ?? this.clientNonce,
      createdAtMicros: createdAtMicros ?? this.createdAtMicros,
      encryptedPayload: encryptedPayload ?? this.encryptedPayload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (squadId.present) {
      map['squad_id'] = Variable<String>(squadId.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (clientNonce.present) {
      map['client_nonce'] = Variable<String>(clientNonce.value);
    }
    if (createdAtMicros.present) {
      map['created_at_micros'] = Variable<int>(createdAtMicros.value);
    }
    if (encryptedPayload.present) {
      map['encrypted_payload'] = Variable<String>(encryptedPayload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntriesCompanion(')
          ..write('userId: $userId, ')
          ..write('squadId: $squadId, ')
          ..write('planId: $planId, ')
          ..write('clientNonce: $clientNonce, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('encryptedPayload: $encryptedPayload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ConversationOutboxDatabase extends GeneratedDatabase {
  _$ConversationOutboxDatabase(QueryExecutor e) : super(e);
  $ConversationOutboxDatabaseManager get managers =>
      $ConversationOutboxDatabaseManager(this);
  late final $OutboxEntriesTable outboxEntries = $OutboxEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [outboxEntries];
}

typedef $$OutboxEntriesTableCreateCompanionBuilder =
    OutboxEntriesCompanion Function({
      required String userId,
      required String squadId,
      Value<String> planId,
      required String clientNonce,
      required int createdAtMicros,
      required String encryptedPayload,
      Value<int> rowid,
    });
typedef $$OutboxEntriesTableUpdateCompanionBuilder =
    OutboxEntriesCompanion Function({
      Value<String> userId,
      Value<String> squadId,
      Value<String> planId,
      Value<String> clientNonce,
      Value<int> createdAtMicros,
      Value<String> encryptedPayload,
      Value<int> rowid,
    });

class $$OutboxEntriesTableFilterComposer
    extends Composer<_$ConversationOutboxDatabase, $OutboxEntriesTable> {
  $$OutboxEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get squadId => $composableBuilder(
    column: $table.squadId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get planId => $composableBuilder(
    column: $table.planId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientNonce => $composableBuilder(
    column: $table.clientNonce,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxEntriesTableOrderingComposer
    extends Composer<_$ConversationOutboxDatabase, $OutboxEntriesTable> {
  $$OutboxEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get squadId => $composableBuilder(
    column: $table.squadId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get planId => $composableBuilder(
    column: $table.planId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientNonce => $composableBuilder(
    column: $table.clientNonce,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxEntriesTableAnnotationComposer
    extends Composer<_$ConversationOutboxDatabase, $OutboxEntriesTable> {
  $$OutboxEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get squadId =>
      $composableBuilder(column: $table.squadId, builder: (column) => column);

  GeneratedColumn<String> get planId =>
      $composableBuilder(column: $table.planId, builder: (column) => column);

  GeneratedColumn<String> get clientNonce => $composableBuilder(
    column: $table.clientNonce,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => column,
  );
}

class $$OutboxEntriesTableTableManager
    extends
        RootTableManager<
          _$ConversationOutboxDatabase,
          $OutboxEntriesTable,
          OutboxEntry,
          $$OutboxEntriesTableFilterComposer,
          $$OutboxEntriesTableOrderingComposer,
          $$OutboxEntriesTableAnnotationComposer,
          $$OutboxEntriesTableCreateCompanionBuilder,
          $$OutboxEntriesTableUpdateCompanionBuilder,
          (
            OutboxEntry,
            BaseReferences<
              _$ConversationOutboxDatabase,
              $OutboxEntriesTable,
              OutboxEntry
            >,
          ),
          OutboxEntry,
          PrefetchHooks Function()
        > {
  $$OutboxEntriesTableTableManager(
    _$ConversationOutboxDatabase db,
    $OutboxEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> squadId = const Value.absent(),
                Value<String> planId = const Value.absent(),
                Value<String> clientNonce = const Value.absent(),
                Value<int> createdAtMicros = const Value.absent(),
                Value<String> encryptedPayload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxEntriesCompanion(
                userId: userId,
                squadId: squadId,
                planId: planId,
                clientNonce: clientNonce,
                createdAtMicros: createdAtMicros,
                encryptedPayload: encryptedPayload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String squadId,
                Value<String> planId = const Value.absent(),
                required String clientNonce,
                required int createdAtMicros,
                required String encryptedPayload,
                Value<int> rowid = const Value.absent(),
              }) => OutboxEntriesCompanion.insert(
                userId: userId,
                squadId: squadId,
                planId: planId,
                clientNonce: clientNonce,
                createdAtMicros: createdAtMicros,
                encryptedPayload: encryptedPayload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxEntriesTable, OutboxEntry>(table),
                  BaseReferences<
                    _$ConversationOutboxDatabase,
                    $OutboxEntriesTable,
                    OutboxEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$ConversationOutboxDatabase,
      $OutboxEntriesTable,
      OutboxEntry,
      $$OutboxEntriesTableFilterComposer,
      $$OutboxEntriesTableOrderingComposer,
      $$OutboxEntriesTableAnnotationComposer,
      $$OutboxEntriesTableCreateCompanionBuilder,
      $$OutboxEntriesTableUpdateCompanionBuilder,
      (
        OutboxEntry,
        BaseReferences<
          _$ConversationOutboxDatabase,
          $OutboxEntriesTable,
          OutboxEntry
        >,
      ),
      OutboxEntry,
      PrefetchHooks Function()
    >;

class $ConversationOutboxDatabaseManager {
  final _$ConversationOutboxDatabase _db;
  $ConversationOutboxDatabaseManager(this._db);
  $$OutboxEntriesTableTableManager get outboxEntries =>
      $$OutboxEntriesTableTableManager(_db, _db.outboxEntries);
}
