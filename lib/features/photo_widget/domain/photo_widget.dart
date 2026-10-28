import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../conversation/domain/photo_head.dart';
import '../../photos/domain/photo.dart';

part 'photo_widget.freezed.dart';

enum PhotoWidgetDisplay {
  unconfigured,
  signedOut,
  hidden,
  empty,
  unavailable,
  expired,
  photo,
}

@freezed
abstract class PhotoWidgetContext with _$PhotoWidgetContext {
  const factory PhotoWidgetContext({
    required String environmentId,
    required String userId,
    required DateTime expiresAt,
    @Default(0) int revision,
  }) = _PhotoWidgetContext;
}

@freezed
abstract class PhotoWidgetLease with _$PhotoWidgetLease {
  const factory PhotoWidgetLease({
    required String scope,
    required String generation,
    required DateTime expiresAt,
  }) = _PhotoWidgetLease;
}

@freezed
abstract class PhotoWidgetBinding with _$PhotoWidgetBinding {
  const factory PhotoWidgetBinding({
    required String id,
    required String scope,
    required String squadId,
    required String squadName,
    required bool previewEnabled,
  }) = _PhotoWidgetBinding;
}

@freezed
abstract class PhotoWidgetSnapshot with _$PhotoWidgetSnapshot {
  const factory PhotoWidgetSnapshot({
    required PhotoWidgetDisplay display,
    required String scheme,
    PhotoWidgetLease? lease,
    PhotoWidgetBinding? binding,
    String? messageId,
    DateTime? photoExpiresAt,
  }) = _PhotoWidgetSnapshot;
}

@freezed
abstract class PhotoWidgetEntry with _$PhotoWidgetEntry {
  const factory PhotoWidgetEntry({
    required String squadId,
    required String bindingId,
    required String scope,
    String? messageId,
  }) = _PhotoWidgetEntry;
}

Future<String> photoWidgetScope(PhotoWidgetContext context) async =>
    (await Sha256().hash(
      utf8.encode(
        jsonEncode([
          'squadly-photo-widget-v1',
          context.environmentId,
          context.userId,
        ]),
      ),
    )).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

bool widgetUuid(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
).hasMatch(value);
bool widgetScope(String value) => RegExp(r'^[a-f0-9]{64}$').hasMatch(value);

PhotoWidgetEntry? parsePhotoWidgetEntry(
  String raw, {
  String scheme = 'squadly',
}) {
  if (raw.length > 800) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.hasFragment ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort) {
    return null;
  }
  final List<String> parts;
  if (uri.hasScheme) {
    if (uri.scheme != scheme || uri.host != 'photo-widget') return null;
    parts = uri.pathSegments;
  } else {
    if (uri.hasAuthority || !uri.path.startsWith('/photo-widget/')) return null;
    parts = uri.pathSegments.skip(1).toList();
  }
  if (parts.length != 1 ||
      !widgetUuid(parts.single) ||
      uri.path.endsWith('/')) {
    return null;
  }
  final all = uri.queryParametersAll;
  if (all.length < 2 ||
      all.length > 3 ||
      !all.keys.every((k) => {'binding', 'scope', 'message'}.contains(k)) ||
      all.values.any((v) => v.length != 1)) {
    return null;
  }
  final binding = uri.queryParameters['binding'];
  final scope = uri.queryParameters['scope'];
  final message = uri.queryParameters['message'];
  if (binding == null ||
      !widgetUuid(binding) ||
      scope == null ||
      !widgetScope(scope) ||
      (message != null && !widgetUuid(message))) {
    return null;
  }
  return PhotoWidgetEntry(
    squadId: parts.single.toLowerCase(),
    bindingId: binding.toLowerCase(),
    scope: scope,
    messageId: message?.toLowerCase(),
  );
}

String photoWidgetReturnPath(PhotoWidgetEntry entry) => Uri(
  path: '/photo-widget/${entry.squadId}',
  queryParameters: {
    'binding': entry.bindingId,
    'scope': entry.scope,
    if (entry.messageId != null) 'message': entry.messageId!,
  },
).toString();

/// Platform store never accepts or returns cloud credentials.
abstract interface class PhotoWidgetStore {
  Future<bool> isAvailable();
  Future<int> installedCount();
  Future<PhotoWidgetSnapshot> read();
  Future<PhotoWidgetSnapshot> synchronize({
    required String? scope,
    required DateTime? expiresAt,
  });
  Future<PhotoWidgetSnapshot> bind({
    required PhotoWidgetLease lease,
    required String squadId,
    required String squadName,
  });
  Future<PhotoWidgetSnapshot> setPreview({
    required PhotoWidgetSnapshot expected,
    required bool enabled,
  });
  Future<PhotoWidgetSnapshot> setPhoto({
    required PhotoWidgetSnapshot expected,
    required String messageId,
    required DateTime createdAt,
    required PhotoImage image,
  });
  Future<PhotoWidgetSnapshot> applyHead({
    required PhotoWidgetSnapshot expected,
    required PhotoHead head,
    PhotoImage? image,
  });
  Future<PhotoWidgetSnapshot> invalidate({
    required PhotoWidgetSnapshot expected,
    required bool failed,
  });
  Future<void> unbind(PhotoWidgetSnapshot expected);
}
