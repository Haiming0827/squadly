import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../../cards/domain/card_composer.dart';
import '../../secure_route/domain/route_models.dart';
import '../domain/conversation_outbox.dart';
import '../domain/pending_operation.dart';
import 'conversation_outbox_database.dart';
import 'outbox_key_vault.dart';

final class OutboxKeyUnavailable implements Exception {
  const OutboxKeyUnavailable();
}

final class OutboxPayloadUnavailable implements Exception {
  const OutboxPayloadUnavailable();
}

/// Encrypts confirmed send attempts before writing them to the local SQLite
/// queue. User, squad and nonce are metadata; bodies and snapshots are sealed.
final class DriftConversationOutbox implements ConversationOutbox {
  DriftConversationOutbox({
    required ConversationOutboxDatabase database,
    required OutboxKeyVault vault,
  }) : _database = database,
       _vault = vault;

  final ConversationOutboxDatabase _database;
  final OutboxKeyVault _vault;
  final _aes = AesGcm.with256bits();
  final _keys = <String, Future<SecretKey>>{};

  @override
  Future<void> put(PendingConversationOperation operation) async {
    if (operation.userId.isEmpty ||
        operation.squadId.isEmpty ||
        operation.clientNonce.isEmpty) {
      throw const FormatException('Invalid outbox identity');
    }
    final key = await _keyForUser(operation.userId, create: true);
    final createdAtMicros = operation.createdAt.toUtc().microsecondsSinceEpoch;
    final box = await _aes.encrypt(
      utf8.encode(jsonEncode(_payloadFor(operation))),
      secretKey: key,
      aad: _aad(
        operation.userId,
        operation.squadId,
        operation.clientNonce,
        createdAtMicros,
      ),
    );
    await _database.putEncrypted(
      EncryptedOutboxEntry(
        userId: operation.userId,
        squadId: operation.squadId,
        clientNonce: operation.clientNonce,
        createdAtMicros: createdAtMicros,
        encryptedPayload: jsonEncode({
          'version': 1,
          'nonce': base64Encode(box.nonce),
          'ciphertext': base64Encode(box.cipherText),
          'mac': base64Encode(box.mac.bytes),
        }),
      ),
    );
  }

  @override
  Future<List<PendingConversationOperation>> listFor({
    required String userId,
    required String squadId,
  }) async {
    if (userId.isEmpty || squadId.isEmpty) return const [];
    final rows = await _database.listEncrypted(
      userId: userId,
      squadId: squadId,
    );
    if (rows.isEmpty) return const [];
    final key = await _keyForUser(userId, create: false);
    final operations = <PendingConversationOperation>[];
    for (final row in rows) {
      try {
        final sealed = jsonDecode(row.encryptedPayload);
        if (sealed is! Map ||
            sealed['version'] != 1 ||
            sealed['nonce'] is! String ||
            sealed['ciphertext'] is! String ||
            sealed['mac'] is! String) {
          throw const FormatException('Invalid local outbox envelope');
        }
        final cleartext = await _aes.decrypt(
          SecretBox(
            base64Decode(sealed['ciphertext'] as String),
            nonce: base64Decode(sealed['nonce'] as String),
            mac: Mac(base64Decode(sealed['mac'] as String)),
          ),
          secretKey: key,
          aad: _aad(
            row.userId,
            row.squadId,
            row.clientNonce,
            row.createdAtMicros,
          ),
        );
        operations.add(_operationFrom(row, jsonDecode(utf8.decode(cleartext))));
      } catch (_) {
        throw const OutboxPayloadUnavailable();
      }
    }
    return List.unmodifiable(operations);
  }

  @override
  Future<void> remove({
    required String userId,
    required String squadId,
    required String clientNonce,
  }) => _database.removeEncrypted(
    userId: userId,
    squadId: squadId,
    clientNonce: clientNonce,
  );

  Future<SecretKey> _keyForUser(String userId, {required bool create}) async {
    final existing = _keys[userId];
    if (existing != null) return existing;
    final pending = _loadKey(userId, create: create);
    _keys[userId] = pending;
    try {
      return await pending;
    } catch (_) {
      if (identical(_keys[userId], pending)) _keys.remove(userId);
      rethrow;
    }
  }

  Future<SecretKey> _loadKey(String userId, {required bool create}) async {
    final storageKey =
        'squadly.outbox.v1.${base64Url.encode(utf8.encode(userId))}';
    final encoded = await _vault.read(storageKey);
    if (encoded != null) {
      try {
        final bytes = base64Decode(encoded);
        if (bytes.length == 32) return SecretKey(bytes);
      } catch (_) {
        // A damaged key cannot authenticate any previous row.
      }
      throw const OutboxKeyUnavailable();
    }
    if (!create || await _database.hasRowsForUser(userId)) {
      throw const OutboxKeyUnavailable();
    }
    final key = await _aes.newSecretKey();
    await _vault.write(storageKey, base64Encode(await key.extractBytes()));
    return key;
  }

  static List<int> _aad(
    String userId,
    String squadId,
    String clientNonce,
    int createdAtMicros,
  ) => utf8.encode(
    jsonEncode([
      'squadly-outbox-v1',
      userId,
      squadId,
      clientNonce,
      createdAtMicros,
    ]),
  );

  static Map<String, Object?> _payloadFor(
    PendingConversationOperation operation,
  ) => switch (operation) {
    PendingTextOperation(:final body, :final replyToEntryId) => {
      'type': 'text',
      'body': body,
      'reply_to_entry_id': replyToEntryId,
    },
    PendingCardOperation(
      :final cardId,
      :final snapshot,
      :final encryptedRoute,
    ) =>
      {
        'type': 'card',
        'card_id': cardId,
        'kind': snapshot.kind.name,
        'snapshot': snapshot.payload,
        'template_id': snapshot.templateId,
        'template_version': snapshot.templateVersion,
        'has_encrypted_route': snapshot.hasEncryptedRoute,
        'encrypted_route': encryptedRoute?.toJson(),
      },
  };

  static PendingConversationOperation _operationFrom(
    EncryptedOutboxEntry row,
    Object? value,
  ) {
    if (value is! Map) {
      throw const FormatException('Invalid local outbox payload');
    }
    final createdAt = DateTime.fromMicrosecondsSinceEpoch(
      row.createdAtMicros,
      isUtc: true,
    );
    if (value['type'] == 'text') {
      final body = value['body'];
      final reply = value['reply_to_entry_id'];
      if (body is! String ||
          body.trim().isEmpty ||
          (reply != null && reply is! String)) {
        throw const FormatException('Invalid local text attempt');
      }
      return PendingConversationOperation.text(
        userId: row.userId,
        squadId: row.squadId,
        clientNonce: row.clientNonce,
        createdAt: createdAt,
        body: body,
        replyToEntryId: reply as String?,
      );
    }
    if (value['type'] == 'card') {
      final cardId = value['card_id'];
      final kindName = value['kind'];
      final payload = value['snapshot'];
      final templateId = value['template_id'];
      final templateVersion = value['template_version'];
      final hasRoute = value['has_encrypted_route'];
      final routeData = value['encrypted_route'];
      if (cardId is! String ||
          kindName is! String ||
          payload is! Map ||
          templateId is! String ||
          templateVersion is! int ||
          hasRoute is! bool ||
          (routeData != null && routeData is! Map)) {
        throw const FormatException('Invalid local card attempt');
      }
      final kinds = CardKind.values.where((kind) => kind.name == kindName);
      if (kinds.isEmpty) {
        throw const FormatException('Invalid local card kind');
      }
      final route = routeData == null
          ? null
          : EncryptedRouteBundle.fromJson(Map<String, dynamic>.from(routeData));
      if (hasRoute != (route != null)) {
        throw const FormatException('Invalid local card route flag');
      }
      return PendingConversationOperation.card(
        userId: row.userId,
        squadId: row.squadId,
        clientNonce: row.clientNonce,
        createdAt: createdAt,
        cardId: cardId,
        snapshot: CardSnapshot(
          kind: kinds.single,
          payload: Map<String, Object>.from(payload),
          templateId: templateId,
          templateVersion: templateVersion,
          hasEncryptedRoute: hasRoute,
        ),
        encryptedRoute: route,
      );
    }
    throw const FormatException('Invalid local outbox type');
  }
}
