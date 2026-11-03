import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../core/error/failures.dart';
import '../domain/photo.dart';
import '../domain/photo_repository.dart';
import '../domain/photo_safety_repository.dart';
import '../domain/prepared_photo_format.dart';

/// One atomic session snapshot prevents reading a token for a different user.
final class PhotoCredentials {
  const PhotoCredentials({required this.userId, required this.accessToken});
  final String userId;
  final String accessToken;
}

typedef PhotoCredentialsReader = Future<PhotoCredentials?> Function();

/// Authenticated media worker adapter. The worker returns bytes, never URLs.
final class CloudBasePhotoRepository
    implements PhotoRepository, PhotoSafetyRepository {
  CloudBasePhotoRepository({
    required this._userId,
    required this._endpoint,
    required this._credentials,
    Dio? dio,
  }) : _dio =
           dio ??
           Dio(BaseOptions(connectTimeout: const Duration(seconds: 15))) {
    if (_userId.isEmpty ||
        _endpoint.scheme != 'https' ||
        !RegExp(
          r'^(?:[a-zA-Z0-9-]+\.api\.(?:intl\.)?tcloudbasegateway\.com|[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)?\.app\.tcloudbase\.com)$',
        ).hasMatch(_endpoint.host) ||
        _endpoint.userInfo.isNotEmpty ||
        _endpoint.hasQuery ||
        _endpoint.hasFragment ||
        _endpoint.port != 443) {
      throw ArgumentError('Invalid photo gateway configuration');
    }
  }

  final String _userId;
  final Uri _endpoint;
  final PhotoCredentialsReader _credentials;
  final Dio _dio;

  @override
  Future<Either<Failure, PublishedPhoto>> publish(PhotoDraft draft) async {
    if (draft.target.userId != _userId ||
        !_uuid(draft.target.squadId) ||
        !_uuid(draft.clientNonce) ||
        (draft.target.replyToMessageId != null &&
            !_uuid(draft.target.replyToMessageId!))) {
      return left(const Failure.validation(message: '请确认原账号与要发送的小队'));
    }
    try {
      if (!isPreparedJpeg(
        draft.image.bytes,
        draft.image.width,
        draft.image.height,
      )) {
        return left(const Failure.validation(message: '照片准备无效，请重新选择'));
      }
      final sha = (await Sha256().hash(draft.image.bytes)).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      if (sha != draft.image.sha256) {
        return left(const Failure.validation(message: '照片内容已变化，请重新选择'));
      }
      final json = await _request({
        'action': 'publish',
        'squad_id': draft.target.squadId,
        'client_nonce': draft.clientNonce,
        'source_sha256': draft.image.sha256,
        'reply_to_message_id': draft.target.replyToMessageId,
        'bytes': base64Encode(draft.image.bytes),
      });
      if (json['squad_id'] != draft.target.squadId ||
          json['author_id'] != _userId ||
          json['client_nonce'] != draft.clientNonce ||
          json['reply_to_message_id'] != draft.target.replyToMessageId ||
          !_uuid(json['message_id']) ||
          !_uuid(json['media_id']) ||
          json['published_at'] is! String) {
        throw const FormatException('Mismatched photo publication');
      }
      return right(
        PublishedPhoto(
          messageId: json['message_id'] as String,
          mediaId: json['media_id'] as String,
          squadId: draft.target.squadId,
          authorId: _userId,
          clientNonce: draft.clientNonce,
          publishedAt: DateTime.parse(json['published_at'] as String).toUtc(),
          replyToMessageId: draft.target.replyToMessageId,
        ),
      );
    } catch (error) {
      return left(_failure(error));
    }
  }

  @override
  Future<Either<Failure, PhotoImage>> load({
    required String squadId,
    required String messageId,
  }) async {
    if (!_uuid(squadId) || !_uuid(messageId)) {
      return left(const Failure.validation(message: '照片身份无效'));
    }
    try {
      final json = await _request({
        'action': 'load',
        'squad_id': squadId,
        'message_id': messageId,
      });
      if (json.length != 4 ||
          json['bytes'] is! String ||
          (json['bytes'] as String).length >
              4 * ((PhotoImage.maxBytes + 2) ~/ 3) ||
          json['width'] is! int ||
          json['height'] is! int ||
          json['sha256'] is! String) {
        throw const FormatException('Invalid photo response');
      }
      final bytes = base64Decode(json['bytes'] as String);
      final width = json['width'] as int;
      final height = json['height'] as int;
      if (bytes.length > PhotoImage.maxBytes ||
          !isPreparedJpeg(bytes, width, height)) {
        throw const FormatException('Invalid prepared photo');
      }
      final sha = (await Sha256().hash(bytes)).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      if (sha != json['sha256']) {
        throw const FormatException('Photo digest mismatch');
      }
      // Hashing is asynchronous; recheck again before exposing image bytes.
      await _session();
      return right(
        PhotoImage(
          bytes: Uint8List.fromList(bytes),
          width: width,
          height: height,
          sha256: sha,
        ),
      );
    } catch (error) {
      return left(_failure(error));
    }
  }

  @override
  Future<Either<Failure, void>> revoke({
    required String squadId,
    required String messageId,
  }) async {
    if (!_uuid(squadId) || !_uuid(messageId)) {
      return left(const Failure.validation(message: '照片身份无效'));
    }
    try {
      final json = await _request({
        'action': 'revoke',
        'squad_id': squadId,
        'message_id': messageId,
      });
      if (json['revoked'] != true) {
        throw const FormatException('Invalid revoke response');
      }
      return right(null);
    } catch (error) {
      return left(_failure(error));
    }
  }

  @override
  Future<Either<Failure, void>> hide({
    required String squadId,
    required String messageId,
  }) => _safety(squadId, messageId, null);

  @override
  Future<Either<Failure, void>> report({
    required String squadId,
    required String messageId,
    required PhotoReportReason reason,
  }) => _safety(squadId, messageId, reason);

  Future<Either<Failure, void>> _safety(
    String squadId,
    String messageId,
    PhotoReportReason? reason,
  ) async {
    if (!_uuid(squadId) || !_uuid(messageId)) {
      return left(const Failure.validation(message: '照片身份无效'));
    }
    try {
      final response = await _request({
        'action': reason == null ? 'hide' : 'report',
        'squad_id': squadId,
        'message_id': messageId,
        if (reason != null) 'reason': reason.name,
      });
      if (response.length != (reason == null ? 1 : 2) ||
          response['hidden'] != true ||
          (reason != null && response['reported'] != true)) {
        throw const FormatException('Unconfirmed photo safety action');
      }
      return right(null);
    } catch (error) {
      return left(_failure(error));
    }
  }

  Future<PhotoCredentials> _session() async {
    final session = await _credentials();
    if (session == null ||
        session.userId != _userId ||
        session.accessToken.trim().isEmpty) {
      throw const _AccountChanged();
    }
    return session;
  }

  Future<Map<String, dynamic>> _request(Map<String, Object?> body) async {
    final session = await _session();
    // CloudBase's HTTP gateway caps text bodies at 100KB. A confirmed JPEG
    // remains inside the same bounded JSON envelope, carried as binary UTF-8
    // so the gateway forwards it as a base64 event to the existing worker.
    final binaryUpload = body['action'] == 'publish';
    final response = await _dio.postUri<Object?>(
      _endpoint,
      data: binaryUpload
          ? Uint8List.fromList(utf8.encode(jsonEncode(body)))
          : body,
      options: Options(
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Cache-Control': 'no-store',
        },
        contentType: binaryUpload
            ? 'application/octet-stream'
            : 'application/json',
        followRedirects: false,
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 45),
      ),
    );
    await _session();
    if (response.data is! Map) {
      throw const FormatException('Invalid media response');
    }
    final json = Map<String, dynamic>.from(response.data! as Map);
    if (json['error'] != null) throw _MediaError(json['error'].toString());
    return json;
  }

  static bool _uuid(Object? value) =>
      value is String &&
      RegExp(
        r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$',
      ).hasMatch(value);

  static Failure _failure(Object error) {
    if (error is _AccountChanged) {
      return const Failure.unauthorized(message: '账号已变化，请返回原账号');
    }
    String? code;
    if (error is _MediaError) code = error.code;
    if (error is DioException) {
      if (error.response?.statusCode == 413) {
        return const Failure.validation(message: '照片上传请求过大，请更新应用后重试');
      }
      final data = error.response?.data;
      if (data is Map && data['error'] is String) {
        code = data['error'] as String;
      }
      if (code == null && {401, 403}.contains(error.response?.statusCode)) {
        return const Failure.permissionDenied(message: '请登录并确认小队权限');
      }
      if (code == null && error.response == null) {
        return const Failure.network(message: '网络暂不可用，请稍后重试');
      }
    }
    return switch (code) {
      'unauthorized' ||
      'unauthenticated' => const Failure.unauthorized(message: '请重新登录'),
      'not_member' || 'squad_inactive' => const Failure.permissionDenied(
        message: '当前无法向这个小队发送照片',
      ),
      'not_found' ||
      'revoked' => const Failure.notFound(message: '照片已撤回或当前无法查看'),
      'nonce_conflict' => const Failure.validation(message: '待发内容已变化，请重新确认发送'),
      'upload_busy' ||
      'upload_expired' => const Failure.server(message: '照片仍在处理中，请稍后重试'),
      'rate_limited' => const Failure.server(message: '发送较频繁，请稍后重试'),
      'invalid_reply' => const Failure.validation(message: '原照片已失效，请返回查看'),
      'invalid_report' => const Failure.validation(message: '请选择举报原因'),
      'invalid_photo' => const Failure.validation(message: '这张照片无法使用，请换一张'),
      _ => const Failure.server(message: '照片服务暂不可用，请稍后重试'),
    };
  }
}

final class _AccountChanged implements Exception {
  const _AccountChanged();
}

final class _MediaError implements Exception {
  const _MediaError(this.code);
  final String code;
}
