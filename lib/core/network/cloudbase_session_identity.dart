import 'dart:convert';

import 'package:cloudbase_flutter/cloudbase_flutter.dart';

/// Conservative SDK snapshot consistency/expiry check, never JWT verification.
({String userId, DateTime expiresAt}) cloudBaseSessionIdentity(
  Session session,
) {
  final token = session.accessToken;
  final userId = session.user?.id;
  if (token == null ||
      token.isEmpty ||
      token.length > 32768 ||
      userId == null ||
      userId.isEmpty) {
    throw const FormatException('Local session unavailable');
  }
  final parts = token.split('.');
  if (parts.length != 3 || parts.any((part) => part.isEmpty)) {
    throw const FormatException('Local session unavailable');
  }
  final claims = jsonDecode(
    utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
  );
  if (claims is! Map ||
      claims['sub'] != userId ||
      claims['exp'] is! int ||
      claims['exp'] <= 0) {
    throw const FormatException('Local session unavailable');
  }
  var expiry = DateTime.fromMillisecondsSinceEpoch(
    (claims['exp'] as int) * 1000,
    isUtc: true,
  );
  final sdkExpiry = session.expiresAt;
  if (sdkExpiry != null) {
    if (sdkExpiry <= 0) {
      throw const FormatException('Local session unavailable');
    }
    // SDK releases may retain API epoch seconds or computed epoch milliseconds.
    final candidate = DateTime.fromMillisecondsSinceEpoch(
      sdkExpiry < 100000000000 ? sdkExpiry * 1000 : sdkExpiry,
      isUtc: true,
    );
    if (candidate.isBefore(expiry)) expiry = candidate;
  }
  return (userId: userId, expiresAt: expiry);
}
