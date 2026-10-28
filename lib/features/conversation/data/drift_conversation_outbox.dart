import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../../cards/domain/card_composer.dart';
import '../../photos/domain/photo.dart';
import '../../photos/domain/photo_submission.dart';
import '../../photos/domain/prepared_photo_format.dart';
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
  DriftConversationOutbox({required this._database, required this._vault});

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
    if (operation case PendingPhotoOperation()) await _validatePhoto(operation);
    final key = await _keyForUser(operation.userId, create: true);
    final createdAtMicros = operation.createdAt.toUtc().microsecondsSinceEpoch;
    final planId = operation.planId ?? '';
    final version = operation is PendingPhotoOperation
        ? 3
        : (planId.isEmpty ? 1 : 2);
    final box = await _aes.encrypt(
      utf8.encode(jsonEncode(_payloadFor(operation))),
      secretKey: key,
      aad: _aad(
        operation.userId,
        operation.squadId,
        planId,
        operation.clientNonce,
        createdAtMicros,
        version: version,
      ),
    );
    await _database.putEncrypted(
      EncryptedOutboxEntry(
        userId: operation.userId,
        squadId: operation.squadId,
        planId: planId,
        clientNonce: operation.clientNonce,
        createdAtMicros: createdAtMicros,
        encryptedPayload: jsonEncode({
          'version': version,
          'nonce': base64Encode(box.nonce),
          'ciphertext': base64Encode(box.cipherText),
          'mac': base64Encode(box.mac.bytes),
        }),
      ),
    );
    if (operation is PendingPhotoOperation) {
      final stored = await _database.readEncrypted(
        userId: operation.userId,
        squadId: operation.squadId,
        clientNonce: operation.clientNonce,
      );
      if (stored == null) throw const OutboxPayloadUnavailable();
      final recovered = await _decodeRow(stored, key);
      if (recovered is! PendingPhotoOperation ||
          !sameConfirmedPhoto(recovered.draft, operation.draft)) {
        throw const FormatException('Conflicting confirmed photo identity');
      }
    }
  }

  @override
  Future<List<PendingConversationOperation>> listFor({
    required String userId,
    required String squadId,
    String? planId,
  }) async {
    if (userId.isEmpty || squadId.isEmpty) return const [];
    final scopedPlanId = planId ?? '';
    final rows = await _database.listEncrypted(
      userId: userId,
      squadId: squadId,
      planId: scopedPlanId,
    );
    if (rows.isEmpty) return const [];
    final key = await _keyForUser(userId, create: false);
    final operations = <PendingConversationOperation>[];
    for (final row in rows) {
      operations.add(await _decodeRow(row, key));
    }
    return List.unmodifiable(operations);
  }

  Future<PendingConversationOperation> _decodeRow(
    EncryptedOutboxEntry row,
    SecretKey key,
  ) async {
    try {
      final sealed = jsonDecode(row.encryptedPayload);
      if (sealed is! Map ||
          (sealed['version'] != (row.planId.isEmpty ? 1 : 2) &&
              !(sealed['version'] == 3 && row.planId.isEmpty)) ||
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
          row.planId,
          row.clientNonce,
          row.createdAtMicros,
          version: sealed['version'] as int,
        ),
      );
      return await _operationFrom(
        row,
        jsonDecode(utf8.decode(cleartext)),
        version: sealed['version'] as int,
      );
    } catch (_) {
      throw const OutboxPayloadUnavailable();
    }
  }

  @override
  Future<void> remove({
    required String userId,
    required String squadId,
    required String clientNonce,
    String? planId,
  }) => _database.removeEncrypted(
    userId: userId,
    squadId: squadId,
    clientNonce: clientNonce,
    planId: planId ?? '',
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
    String planId,
    String clientNonce,
    int createdAtMicros, {
    int? version,
  }) => utf8.encode(
    jsonEncode([
      version == 3
          ? 'squadly-outbox-v3-photo'
          : (planId.isEmpty ? 'squadly-outbox-v1' : 'squadly-outbox-v2'),
      userId,
      squadId,
      if (version == 3 || planId.isNotEmpty) planId,
      clientNonce,
      createdAtMicros,
    ]),
  );

  static Map<String, Object?> _payloadFor(
    PendingConversationOperation operation,
  ) => switch (operation) {
    PendingPhotoOperation(
      :final image,
      :final squadName,
      :final replyToEntryId,
    ) =>
      {
        'type': 'photo',
        'squad_name': squadName,
        'reply_to_entry_id': replyToEntryId,
        'width': image.width,
        'height': image.height,
        'sha256': image.sha256,
        'bytes': base64Encode(image.bytes),
      },
    PendingTextOperation(:final body, :final replyToEntryId) => {
      'type': 'text',
      'body': body,
      'reply_to_entry_id': replyToEntryId,
      'plan_id': operation.planId,
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
        'plan_id': operation.planId,
      },
  };

  static Future<PendingConversationOperation> _operationFrom(
    EncryptedOutboxEntry row,
    Object? value, {
    required int version,
  }) async {
    if (value is! Map) {
      throw const FormatException('Invalid local outbox payload');
    }
    final payloadPlanId = value['plan_id'];
    if (payloadPlanId != null && payloadPlanId != row.planId) {
      throw const FormatException('Outbox plan scope mismatch');
    }
    final createdAt = DateTime.fromMicrosecondsSinceEpoch(
      row.createdAtMicros,
      isUtc: true,
    );
    if (value['type'] == 'photo') {
      const keys = {
        'type',
        'squad_name',
        'reply_to_entry_id',
        'width',
        'height',
        'sha256',
        'bytes',
      };
      if (version != 3 ||
          row.planId.isNotEmpty ||
          value.length != keys.length ||
          !keys.containsAll(value.keys) ||
          value['squad_name'] is! String ||
          value['width'] is! int ||
          value['height'] is! int ||
          value['sha256'] is! String ||
          value['bytes'] is! String ||
          (value['bytes'] as String).length >
              ((PhotoImage.maxBytes + 2) ~/ 3) * 4 ||
          (value['reply_to_entry_id'] != null &&
              value['reply_to_entry_id'] is! String)) {
        throw const FormatException('Invalid local photo attempt');
      }
      final operation = PendingPhotoOperation(
        userId: row.userId,
        squadId: row.squadId,
        squadName: value['squad_name'] as String,
        clientNonce: row.clientNonce,
        createdAt: createdAt,
        replyToEntryId: value['reply_to_entry_id'] as String?,
        image: PhotoImage(
          bytes: base64Decode(value['bytes'] as String),
          width: value['width'] as int,
          height: value['height'] as int,
          sha256: value['sha256'] as String,
        ),
      );
      await _validatePhoto(operation);
      return operation;
    }
    if (version == 3) {
      throw const FormatException('Unexpected photo envelope payload');
    }
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
        planId: row.planId.isEmpty ? null : row.planId,
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
        planId: row.planId.isEmpty ? null : row.planId,
        encryptedRoute: route,
      );
    }
    throw const FormatException('Invalid local outbox type');
  }

  static Future<void> _validatePhoto(PendingPhotoOperation operation) async {
    bool uuid(String value) => RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
    final image = operation.image;
    if (operation.userId.trim().isEmpty ||
        operation.userId.length > 64 ||
        !uuid(operation.squadId) ||
        !uuid(operation.clientNonce) ||
        operation.squadName.trim().isEmpty ||
        operation.squadName.length > 200 ||
        (operation.replyToEntryId != null &&
            !uuid(operation.replyToEntryId!)) ||
        !isPreparedJpeg(image.bytes, image.width, image.height)) {
      throw const FormatException('Invalid confirmed photo');
    }
    final digest = (await Sha256().hash(image.bytes)).bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    if (digest != image.sha256) {
      throw const FormatException('Photo content changed');
    }
  }
}
