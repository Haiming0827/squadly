import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../domain/cached_conversation_thread.dart';
import '../domain/conversation_cache.dart';
import '../domain/conversation_target.dart';
import '../domain/timeline_entry.dart';
import 'conversation_cache_database.dart';
import 'outbox_key_vault.dart';
import 'timeline_entry_mapper.dart';

/// Independent keys/database: clearing sent records never touches the outbox.
final class DriftConversationCache
    implements ConversationCache, ConversationCacheAccountCleanup {
  DriftConversationCache({required this.database, required this.vault});
  final ConversationCacheDatabase database;
  final OutboxKeyVault vault;
  final _aes = AesGcm.with256bits();
  final _generations = <String, int>{};
  final _suspended = <String>{};
  Future<void> _tail = Future.value();
  bool _closed = false;
  Future<void>? _closing;
  int _accountCleanupGeneration = 0;

  @override
  Future<void> clearOtherUsers(String activeUserId) async {
    if (_closed || activeUserId.isEmpty) return;
    final generation = ++_accountCleanupGeneration;
    final users = await _serial(
      () => _closed ? Future.value(<String>[]) : database.cachedUserIds(),
    );
    for (final userId in users) {
      if (_closed || generation != _accountCleanupGeneration) return;
      if (userId != activeUserId) await clearUser(userId, suspend: true);
    }
  }

  Future<void> close() {
    _closed = true;
    return _closing ??= _tail.then((_) => database.close());
  }

  @override
  ConversationCacheLease? lease(String userId) =>
      _closed || userId.isEmpty || _suspended.contains(userId)
      ? null
      : ConversationCacheLease(userId, _generations[userId] ?? 0);
  @override
  bool isValid(ConversationCacheLease lease) =>
      !_closed &&
      !_suspended.contains(lease.userId) &&
      lease.generation == (_generations[lease.userId] ?? 0);
  @override
  void resumeUser(String userId) => _suspended.remove(userId);

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  String _keyName(String userId) =>
      'squadly.timeline-cache.v1.${base64Url.encode(utf8.encode(userId))}';
  Future<SecretKey> _key(String userId, {required bool create}) async {
    final encoded = await vault.read(_keyName(userId));
    if (encoded != null) {
      final bytes = base64Decode(encoded);
      if (bytes.length != 32) throw StateError('Local cache key unavailable');
      return SecretKey(bytes);
    }
    if (!create) throw StateError('Local cache key unavailable');
    final key = await _aes.newSecretKey();
    await vault.write(_keyName(userId), base64Encode(await key.extractBytes()));
    return key;
  }

  @override
  Future<void> clearUser(String userId, {bool suspend = false}) {
    if (_closed) return Future.value();
    _generations[userId] = (_generations[userId] ?? 0) + 1;
    if (suspend) _suspended.add(userId);
    return _serial(() async {
      // Destroy the previous decryption capability before deleting SQLite rows.
      final key = await _aes.newSecretKey();
      await vault.write(
        _keyName(userId),
        base64Encode(await key.extractBytes()),
      );
      await database.clearUser(userId);
    });
  }

  @override
  Future<void> save(
    ConversationCacheLease lease,
    String squadId,
    List<TimelineEntry> entries, {
    String? planId,
  }) => _serial(() async {
    if (!isValid(lease) || entries.isEmpty) return;
    if (entries.any(
      (entry) => entry.squadId != squadId || entry.planId != planId,
    )) {
      throw const FormatException('Cache scope mismatch');
    }
    final key = await _key(lease.userId, create: true);
    for (final entry in entries) {
      if (!isValid(lease)) return;
      final time = entry.createdAt.toUtc().microsecondsSinceEpoch;
      final box = await _aes.encrypt(
        utf8.encode(jsonEncode(_encode(entry))),
        secretKey: key,
        aad: _aad(lease.userId, squadId, planId ?? '', entry.id, time),
      );
      if (!isValid(lease)) return;
      await database.saveRow(
        CachedTimelineEntriesCompanion.insert(
          userId: lease.userId,
          squadId: squadId,
          planId: planId ?? '',
          messageId: entry.id,
          createdAtMicros: time,
          encryptedPayload: jsonEncode({
            'v': 1,
            'nonce': base64Encode(box.nonce),
            'ciphertext': base64Encode(box.cipherText),
            'mac': base64Encode(box.mac.bytes),
          }),
        ),
      );
    }
  });

  @override
  Future<List<TimelineEntry>> page(
    ConversationCacheLease lease,
    String squadId, {
    String? planId,
    TimelineCursor? before,
    TimelineCursor? after,
  }) => _serial(() async {
    if (!isValid(lease)) return const [];
    final rows = await database.pageRows(
      userId: lease.userId,
      squadId: squadId,
      planId: planId ?? '',
      before: before,
      after: after,
    );
    if (rows.isEmpty) return const [];
    final key = await _key(lease.userId, create: false);
    final entries = <TimelineEntry>[];
    for (final row in rows) {
      entries.add(await _decodeEntry(row, key));
    }
    return isValid(lease) ? List.unmodifiable(entries) : const [];
  });

  Future<TimelineEntry> _decodeEntry(
    CachedTimelineEntry row,
    SecretKey key,
  ) async {
    final sealed = jsonDecode(row.encryptedPayload) as Map<String, dynamic>;
    if (sealed['v'] != 1) {
      throw const FormatException('Unknown cache version');
    }
    final bytes = await _aes.decrypt(
      SecretBox(
        base64Decode(sealed['ciphertext'] as String),
        nonce: base64Decode(sealed['nonce'] as String),
        mac: Mac(base64Decode(sealed['mac'] as String)),
      ),
      secretKey: key,
      aad: _aad(
        row.userId,
        row.squadId,
        row.planId,
        row.messageId,
        row.createdAtMicros,
      ),
    );
    final entry = timelineEntryFromJson(
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
    );
    if (entry.id != row.messageId ||
        entry.squadId != row.squadId ||
        (entry.planId ?? '') != row.planId ||
        entry.createdAt.microsecondsSinceEpoch != row.createdAtMicros) {
      throw const FormatException('Cache payload scope mismatch');
    }
    return entry;
  }

  List<int> _labelAad(String userId, String squadId, String planId) =>
      utf8.encode(
        jsonEncode(['squadly-timeline-label-v1', userId, squadId, planId]),
      );

  @override
  Future<void> rememberThread(
    ConversationCacheLease lease,
    String squadId,
    String squadName, {
    String? planId,
    String? planTitle,
  }) => _serial(() async {
    if (!isValid(lease)) return;
    if (squadId.isEmpty || squadName.trim().isEmpty) {
      throw const FormatException('Invalid thread label');
    }
    final key = await _key(lease.userId, create: true);
    final box = await _aes.encrypt(
      utf8.encode(
        jsonEncode({'squad_name': squadName, 'plan_title': planTitle}),
      ),
      secretKey: key,
      aad: _labelAad(lease.userId, squadId, planId ?? ''),
    );
    if (!isValid(lease)) return;
    await database.saveLabel(
      CachedConversationLabelsCompanion.insert(
        userId: lease.userId,
        squadId: squadId,
        planId: planId ?? '',
        encryptedPayload: jsonEncode({
          'v': 1,
          'nonce': base64Encode(box.nonce),
          'ciphertext': base64Encode(box.cipherText),
          'mac': base64Encode(box.mac.bytes),
        }),
      ),
    );
  });

  @override
  Future<List<CachedConversationThread>> threads(
    ConversationCacheLease lease,
  ) => _serial(() async {
    if (!isValid(lease)) return const [];
    final scopes = await database.threadScopes(lease.userId);
    if (scopes.isEmpty) return const [];
    final key = await _key(lease.userId, create: false);
    final threads = <CachedConversationThread>[];
    for (final scope in scopes) {
      if (!isValid(lease)) return const [];
      final rows = await database.pageRows(
        userId: lease.userId,
        squadId: scope.squadId,
        planId: scope.planId,
        limit: 1,
      );
      if (rows.isEmpty) continue;
      var squadName = '小队会话';
      String? planTitle;
      final label = await database.labelFor(
        lease.userId,
        scope.squadId,
        scope.planId,
      );
      if (label != null) {
        final envelope =
            jsonDecode(label.encryptedPayload) as Map<String, dynamic>;
        if (envelope['v'] != 1) {
          throw const FormatException('Unknown thread label version');
        }
        final bytes = await _aes.decrypt(
          SecretBox(
            base64Decode(envelope['ciphertext'] as String),
            nonce: base64Decode(envelope['nonce'] as String),
            mac: Mac(base64Decode(envelope['mac'] as String)),
          ),
          secretKey: key,
          aad: _labelAad(lease.userId, scope.squadId, scope.planId),
        );
        final names = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        squadName = names['squad_name'] as String;
        planTitle = names['plan_title'] as String?;
      }
      threads.add(
        CachedConversationThread(
          target: ConversationTarget(
            squadId: scope.squadId,
            planId: scope.planId.isEmpty ? null : scope.planId,
          ),
          squadName: squadName,
          planTitle: planTitle,
          latestEntry: (await _decodeEntry(rows.single, key)).asLocalCopy(),
        ),
      );
    }
    return isValid(lease) ? List.unmodifiable(threads) : const [];
  });

  static List<int> _aad(
    String userId,
    String squadId,
    String planId,
    String id,
    int time,
  ) => utf8.encode(
    jsonEncode([
      'squadly-timeline-cache-v1',
      userId,
      squadId,
      planId,
      id,
      time,
    ]),
  );

  static Map<String, Object?> _encode(TimelineEntry entry) => {
    'id': entry.id,
    'squad_id': entry.squadId,
    'plan_id': entry.planId,
    'sender_id': entry.authorId,
    'author': {'nickname': entry.authorName},
    'kind': entry.kind.name,
    'body': entry.text,
    'card_id': entry.cardId,
    'photo_id': entry.photo?.mediaId,
    'photo': entry.photo == null
        ? null
        : {
            'id': entry.photo!.mediaId,
            'width': entry.photo!.width,
            'height': entry.photo!.height,
            'byte_length': entry.photo!.byteLength,
            'revoked': entry.photo!.isRevoked,
          },
    'reply_to_message_id': entry.replyToEntryId,
    'client_nonce': entry.clientNonce,
    'created_at': entry.createdAt.toUtc().toIso8601String(),
    'card_snapshot': entry.cardSnapshot == null
        ? null
        : {
            'id': entry.cardId,
            'kind': entry.cardSnapshot!.kind.name,
            'snapshot': entry.cardSnapshot!.payload,
            'template_id': entry.cardSnapshot!.templateId,
            'template_version': entry.cardSnapshot!.templateVersion,
            'has_encrypted_route': entry.cardSnapshot!.hasEncryptedRoute,
          },
  };
}
