// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_cache_database.dart';

// ignore_for_file: type=lint
class $CachedTimelineEntriesTable extends CachedTimelineEntries
    with TableInfo<$CachedTimelineEntriesTable, CachedTimelineEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedTimelineEntriesTable(this.attachedDatabase, [this._alias]);
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
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
    messageId,
    createdAtMicros,
    encryptedPayload,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_timeline_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedTimelineEntry> instance, {
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
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
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
  Set<GeneratedColumn> get $primaryKey => {userId, squadId, planId, messageId};
  @override
  CachedTimelineEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedTimelineEntry(
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
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
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
  $CachedTimelineEntriesTable createAlias(String alias) {
    return $CachedTimelineEntriesTable(attachedDatabase, alias);
  }
}

class CachedTimelineEntry extends DataClass
    implements Insertable<CachedTimelineEntry> {
  final String userId;
  final String squadId;
  final String planId;
  final String messageId;
  final int createdAtMicros;
  final String encryptedPayload;
  const CachedTimelineEntry({
    required this.userId,
    required this.squadId,
    required this.planId,
    required this.messageId,
    required this.createdAtMicros,
    required this.encryptedPayload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['squad_id'] = Variable<String>(squadId);
    map['plan_id'] = Variable<String>(planId);
    map['message_id'] = Variable<String>(messageId);
    map['created_at_micros'] = Variable<int>(createdAtMicros);
    map['encrypted_payload'] = Variable<String>(encryptedPayload);
    return map;
  }

  CachedTimelineEntriesCompanion toCompanion(bool nullToAbsent) {
    return CachedTimelineEntriesCompanion(
      userId: Value(userId),
      squadId: Value(squadId),
      planId: Value(planId),
      messageId: Value(messageId),
      createdAtMicros: Value(createdAtMicros),
      encryptedPayload: Value(encryptedPayload),
    );
  }

  factory CachedTimelineEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedTimelineEntry(
      userId: serializer.fromJson<String>(json['userId']),
      squadId: serializer.fromJson<String>(json['squadId']),
      planId: serializer.fromJson<String>(json['planId']),
      messageId: serializer.fromJson<String>(json['messageId']),
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
      'messageId': serializer.toJson<String>(messageId),
      'createdAtMicros': serializer.toJson<int>(createdAtMicros),
      'encryptedPayload': serializer.toJson<String>(encryptedPayload),
    };
  }

  CachedTimelineEntry copyWith({
    String? userId,
    String? squadId,
    String? planId,
    String? messageId,
    int? createdAtMicros,
    String? encryptedPayload,
  }) => CachedTimelineEntry(
    userId: userId ?? this.userId,
    squadId: squadId ?? this.squadId,
    planId: planId ?? this.planId,
    messageId: messageId ?? this.messageId,
    createdAtMicros: createdAtMicros ?? this.createdAtMicros,
    encryptedPayload: encryptedPayload ?? this.encryptedPayload,
  );
  CachedTimelineEntry copyWithCompanion(CachedTimelineEntriesCompanion data) {
    return CachedTimelineEntry(
      userId: data.userId.present ? data.userId.value : this.userId,
      squadId: data.squadId.present ? data.squadId.value : this.squadId,
      planId: data.planId.present ? data.planId.value : this.planId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
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
    return (StringBuffer('CachedTimelineEntry(')
          ..write('userId: $userId, ')
          ..write('squadId: $squadId, ')
          ..write('planId: $planId, ')
          ..write('messageId: $messageId, ')
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
    messageId,
    createdAtMicros,
    encryptedPayload,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedTimelineEntry &&
          other.userId == this.userId &&
          other.squadId == this.squadId &&
          other.planId == this.planId &&
          other.messageId == this.messageId &&
          other.createdAtMicros == this.createdAtMicros &&
          other.encryptedPayload == this.encryptedPayload);
}

class CachedTimelineEntriesCompanion
    extends UpdateCompanion<CachedTimelineEntry> {
  final Value<String> userId;
  final Value<String> squadId;
  final Value<String> planId;
  final Value<String> messageId;
  final Value<int> createdAtMicros;
  final Value<String> encryptedPayload;
  final Value<int> rowid;
  const CachedTimelineEntriesCompanion({
    this.userId = const Value.absent(),
    this.squadId = const Value.absent(),
    this.planId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.createdAtMicros = const Value.absent(),
    this.encryptedPayload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedTimelineEntriesCompanion.insert({
    required String userId,
    required String squadId,
    required String planId,
    required String messageId,
    required int createdAtMicros,
    required String encryptedPayload,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       squadId = Value(squadId),
       planId = Value(planId),
       messageId = Value(messageId),
       createdAtMicros = Value(createdAtMicros),
       encryptedPayload = Value(encryptedPayload);
  static Insertable<CachedTimelineEntry> custom({
    Expression<String>? userId,
    Expression<String>? squadId,
    Expression<String>? planId,
    Expression<String>? messageId,
    Expression<int>? createdAtMicros,
    Expression<String>? encryptedPayload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (squadId != null) 'squad_id': squadId,
      if (planId != null) 'plan_id': planId,
      if (messageId != null) 'message_id': messageId,
      if (createdAtMicros != null) 'created_at_micros': createdAtMicros,
      if (encryptedPayload != null) 'encrypted_payload': encryptedPayload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedTimelineEntriesCompanion copyWith({
    Value<String>? userId,
    Value<String>? squadId,
    Value<String>? planId,
    Value<String>? messageId,
    Value<int>? createdAtMicros,
    Value<String>? encryptedPayload,
    Value<int>? rowid,
  }) {
    return CachedTimelineEntriesCompanion(
      userId: userId ?? this.userId,
      squadId: squadId ?? this.squadId,
      planId: planId ?? this.planId,
      messageId: messageId ?? this.messageId,
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
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
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
    return (StringBuffer('CachedTimelineEntriesCompanion(')
          ..write('userId: $userId, ')
          ..write('squadId: $squadId, ')
          ..write('planId: $planId, ')
          ..write('messageId: $messageId, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('encryptedPayload: $encryptedPayload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedConversationLabelsTable extends CachedConversationLabels
    with TableInfo<$CachedConversationLabelsTable, CachedConversationLabel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedConversationLabelsTable(this.attachedDatabase, [this._alias]);
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
    encryptedPayload,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_conversation_labels';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedConversationLabel> instance, {
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
    } else if (isInserting) {
      context.missing(_planIdMeta);
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
  Set<GeneratedColumn> get $primaryKey => {userId, squadId, planId};
  @override
  CachedConversationLabel map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedConversationLabel(
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
      encryptedPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_payload'],
      )!,
    );
  }

  @override
  $CachedConversationLabelsTable createAlias(String alias) {
    return $CachedConversationLabelsTable(attachedDatabase, alias);
  }
}

class CachedConversationLabel extends DataClass
    implements Insertable<CachedConversationLabel> {
  final String userId;
  final String squadId;
  final String planId;
  final String encryptedPayload;
  const CachedConversationLabel({
    required this.userId,
    required this.squadId,
    required this.planId,
    required this.encryptedPayload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['squad_id'] = Variable<String>(squadId);
    map['plan_id'] = Variable<String>(planId);
    map['encrypted_payload'] = Variable<String>(encryptedPayload);
    return map;
  }

  CachedConversationLabelsCompanion toCompanion(bool nullToAbsent) {
    return CachedConversationLabelsCompanion(
      userId: Value(userId),
      squadId: Value(squadId),
      planId: Value(planId),
      encryptedPayload: Value(encryptedPayload),
    );
  }

  factory CachedConversationLabel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedConversationLabel(
      userId: serializer.fromJson<String>(json['userId']),
      squadId: serializer.fromJson<String>(json['squadId']),
      planId: serializer.fromJson<String>(json['planId']),
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
      'encryptedPayload': serializer.toJson<String>(encryptedPayload),
    };
  }

  CachedConversationLabel copyWith({
    String? userId,
    String? squadId,
    String? planId,
    String? encryptedPayload,
  }) => CachedConversationLabel(
    userId: userId ?? this.userId,
    squadId: squadId ?? this.squadId,
    planId: planId ?? this.planId,
    encryptedPayload: encryptedPayload ?? this.encryptedPayload,
  );
  CachedConversationLabel copyWithCompanion(
    CachedConversationLabelsCompanion data,
  ) {
    return CachedConversationLabel(
      userId: data.userId.present ? data.userId.value : this.userId,
      squadId: data.squadId.present ? data.squadId.value : this.squadId,
      planId: data.planId.present ? data.planId.value : this.planId,
      encryptedPayload: data.encryptedPayload.present
          ? data.encryptedPayload.value
          : this.encryptedPayload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedConversationLabel(')
          ..write('userId: $userId, ')
          ..write('squadId: $squadId, ')
          ..write('planId: $planId, ')
          ..write('encryptedPayload: $encryptedPayload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, squadId, planId, encryptedPayload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedConversationLabel &&
          other.userId == this.userId &&
          other.squadId == this.squadId &&
          other.planId == this.planId &&
          other.encryptedPayload == this.encryptedPayload);
}

class CachedConversationLabelsCompanion
    extends UpdateCompanion<CachedConversationLabel> {
  final Value<String> userId;
  final Value<String> squadId;
  final Value<String> planId;
  final Value<String> encryptedPayload;
  final Value<int> rowid;
  const CachedConversationLabelsCompanion({
    this.userId = const Value.absent(),
    this.squadId = const Value.absent(),
    this.planId = const Value.absent(),
    this.encryptedPayload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedConversationLabelsCompanion.insert({
    required String userId,
    required String squadId,
    required String planId,
    required String encryptedPayload,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       squadId = Value(squadId),
       planId = Value(planId),
       encryptedPayload = Value(encryptedPayload);
  static Insertable<CachedConversationLabel> custom({
    Expression<String>? userId,
    Expression<String>? squadId,
    Expression<String>? planId,
    Expression<String>? encryptedPayload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (squadId != null) 'squad_id': squadId,
      if (planId != null) 'plan_id': planId,
      if (encryptedPayload != null) 'encrypted_payload': encryptedPayload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedConversationLabelsCompanion copyWith({
    Value<String>? userId,
    Value<String>? squadId,
    Value<String>? planId,
    Value<String>? encryptedPayload,
    Value<int>? rowid,
  }) {
    return CachedConversationLabelsCompanion(
      userId: userId ?? this.userId,
      squadId: squadId ?? this.squadId,
      planId: planId ?? this.planId,
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
    return (StringBuffer('CachedConversationLabelsCompanion(')
          ..write('userId: $userId, ')
          ..write('squadId: $squadId, ')
          ..write('planId: $planId, ')
          ..write('encryptedPayload: $encryptedPayload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ConversationCacheDatabase extends GeneratedDatabase {
  _$ConversationCacheDatabase(QueryExecutor e) : super(e);
  $ConversationCacheDatabaseManager get managers =>
      $ConversationCacheDatabaseManager(this);
  late final $CachedTimelineEntriesTable cachedTimelineEntries =
      $CachedTimelineEntriesTable(this);
  late final $CachedConversationLabelsTable cachedConversationLabels =
      $CachedConversationLabelsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedTimelineEntries,
    cachedConversationLabels,
  ];
}

typedef $$CachedTimelineEntriesTableCreateCompanionBuilder =
    CachedTimelineEntriesCompanion Function({
      required String userId,
      required String squadId,
      required String planId,
      required String messageId,
      required int createdAtMicros,
      required String encryptedPayload,
      Value<int> rowid,
    });
typedef $$CachedTimelineEntriesTableUpdateCompanionBuilder =
    CachedTimelineEntriesCompanion Function({
      Value<String> userId,
      Value<String> squadId,
      Value<String> planId,
      Value<String> messageId,
      Value<int> createdAtMicros,
      Value<String> encryptedPayload,
      Value<int> rowid,
    });

class $$CachedTimelineEntriesTableFilterComposer
    extends Composer<_$ConversationCacheDatabase, $CachedTimelineEntriesTable> {
  $$CachedTimelineEntriesTableFilterComposer({
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

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
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

class $$CachedTimelineEntriesTableOrderingComposer
    extends Composer<_$ConversationCacheDatabase, $CachedTimelineEntriesTable> {
  $$CachedTimelineEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
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

class $$CachedTimelineEntriesTableAnnotationComposer
    extends Composer<_$ConversationCacheDatabase, $CachedTimelineEntriesTable> {
  $$CachedTimelineEntriesTableAnnotationComposer({
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

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => column,
  );
}

class $$CachedTimelineEntriesTableTableManager
    extends
        RootTableManager<
          _$ConversationCacheDatabase,
          $CachedTimelineEntriesTable,
          CachedTimelineEntry,
          $$CachedTimelineEntriesTableFilterComposer,
          $$CachedTimelineEntriesTableOrderingComposer,
          $$CachedTimelineEntriesTableAnnotationComposer,
          $$CachedTimelineEntriesTableCreateCompanionBuilder,
          $$CachedTimelineEntriesTableUpdateCompanionBuilder,
          (
            CachedTimelineEntry,
            BaseReferences<
              _$ConversationCacheDatabase,
              $CachedTimelineEntriesTable,
              CachedTimelineEntry
            >,
          ),
          CachedTimelineEntry,
          PrefetchHooks Function()
        > {
  $$CachedTimelineEntriesTableTableManager(
    _$ConversationCacheDatabase db,
    $CachedTimelineEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedTimelineEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CachedTimelineEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CachedTimelineEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> squadId = const Value.absent(),
                Value<String> planId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<int> createdAtMicros = const Value.absent(),
                Value<String> encryptedPayload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedTimelineEntriesCompanion(
                userId: userId,
                squadId: squadId,
                planId: planId,
                messageId: messageId,
                createdAtMicros: createdAtMicros,
                encryptedPayload: encryptedPayload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String squadId,
                required String planId,
                required String messageId,
                required int createdAtMicros,
                required String encryptedPayload,
                Value<int> rowid = const Value.absent(),
              }) => CachedTimelineEntriesCompanion.insert(
                userId: userId,
                squadId: squadId,
                planId: planId,
                messageId: messageId,
                createdAtMicros: createdAtMicros,
                encryptedPayload: encryptedPayload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedTimelineEntriesTable, CachedTimelineEntry>(
                    table,
                  ),
                  BaseReferences<
                    _$ConversationCacheDatabase,
                    $CachedTimelineEntriesTable,
                    CachedTimelineEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedTimelineEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$ConversationCacheDatabase,
      $CachedTimelineEntriesTable,
      CachedTimelineEntry,
      $$CachedTimelineEntriesTableFilterComposer,
      $$CachedTimelineEntriesTableOrderingComposer,
      $$CachedTimelineEntriesTableAnnotationComposer,
      $$CachedTimelineEntriesTableCreateCompanionBuilder,
      $$CachedTimelineEntriesTableUpdateCompanionBuilder,
      (
        CachedTimelineEntry,
        BaseReferences<
          _$ConversationCacheDatabase,
          $CachedTimelineEntriesTable,
          CachedTimelineEntry
        >,
      ),
      CachedTimelineEntry,
      PrefetchHooks Function()
    >;
typedef $$CachedConversationLabelsTableCreateCompanionBuilder =
    CachedConversationLabelsCompanion Function({
      required String userId,
      required String squadId,
      required String planId,
      required String encryptedPayload,
      Value<int> rowid,
    });
typedef $$CachedConversationLabelsTableUpdateCompanionBuilder =
    CachedConversationLabelsCompanion Function({
      Value<String> userId,
      Value<String> squadId,
      Value<String> planId,
      Value<String> encryptedPayload,
      Value<int> rowid,
    });

class $$CachedConversationLabelsTableFilterComposer
    extends
        Composer<_$ConversationCacheDatabase, $CachedConversationLabelsTable> {
  $$CachedConversationLabelsTableFilterComposer({
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

  ColumnFilters<String> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedConversationLabelsTableOrderingComposer
    extends
        Composer<_$ConversationCacheDatabase, $CachedConversationLabelsTable> {
  $$CachedConversationLabelsTableOrderingComposer({
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

  ColumnOrderings<String> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedConversationLabelsTableAnnotationComposer
    extends
        Composer<_$ConversationCacheDatabase, $CachedConversationLabelsTable> {
  $$CachedConversationLabelsTableAnnotationComposer({
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

  GeneratedColumn<String> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => column,
  );
}

class $$CachedConversationLabelsTableTableManager
    extends
        RootTableManager<
          _$ConversationCacheDatabase,
          $CachedConversationLabelsTable,
          CachedConversationLabel,
          $$CachedConversationLabelsTableFilterComposer,
          $$CachedConversationLabelsTableOrderingComposer,
          $$CachedConversationLabelsTableAnnotationComposer,
          $$CachedConversationLabelsTableCreateCompanionBuilder,
          $$CachedConversationLabelsTableUpdateCompanionBuilder,
          (
            CachedConversationLabel,
            BaseReferences<
              _$ConversationCacheDatabase,
              $CachedConversationLabelsTable,
              CachedConversationLabel
            >,
          ),
          CachedConversationLabel,
          PrefetchHooks Function()
        > {
  $$CachedConversationLabelsTableTableManager(
    _$ConversationCacheDatabase db,
    $CachedConversationLabelsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedConversationLabelsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CachedConversationLabelsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CachedConversationLabelsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> squadId = const Value.absent(),
                Value<String> planId = const Value.absent(),
                Value<String> encryptedPayload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedConversationLabelsCompanion(
                userId: userId,
                squadId: squadId,
                planId: planId,
                encryptedPayload: encryptedPayload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String squadId,
                required String planId,
                required String encryptedPayload,
                Value<int> rowid = const Value.absent(),
              }) => CachedConversationLabelsCompanion.insert(
                userId: userId,
                squadId: squadId,
                planId: planId,
                encryptedPayload: encryptedPayload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $CachedConversationLabelsTable,
                    CachedConversationLabel
                  >(table),
                  BaseReferences<
                    _$ConversationCacheDatabase,
                    $CachedConversationLabelsTable,
                    CachedConversationLabel
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedConversationLabelsTableProcessedTableManager =
    ProcessedTableManager<
      _$ConversationCacheDatabase,
      $CachedConversationLabelsTable,
      CachedConversationLabel,
      $$CachedConversationLabelsTableFilterComposer,
      $$CachedConversationLabelsTableOrderingComposer,
      $$CachedConversationLabelsTableAnnotationComposer,
      $$CachedConversationLabelsTableCreateCompanionBuilder,
      $$CachedConversationLabelsTableUpdateCompanionBuilder,
      (
        CachedConversationLabel,
        BaseReferences<
          _$ConversationCacheDatabase,
          $CachedConversationLabelsTable,
          CachedConversationLabel
        >,
      ),
      CachedConversationLabel,
      PrefetchHooks Function()
    >;

class $ConversationCacheDatabaseManager {
  final _$ConversationCacheDatabase _db;
  $ConversationCacheDatabaseManager(this._db);
  $$CachedTimelineEntriesTableTableManager get cachedTimelineEntries =>
      $$CachedTimelineEntriesTableTableManager(_db, _db.cachedTimelineEntries);
  $$CachedConversationLabelsTableTableManager get cachedConversationLabels =>
      $$CachedConversationLabelsTableTableManager(
        _db,
        _db.cachedConversationLabels,
      );
}
