import 'package:flutter/services.dart';

import '../../conversation/domain/photo_head.dart';
import '../../photos/domain/photo.dart';
import '../../photos/domain/prepared_photo_format.dart';
import '../domain/photo_widget.dart';

/// All bridge errors are converted by the service; no native error details or
/// group paths are exposed in product messages or telemetry.
final class NativePhotoWidgetStore implements PhotoWidgetStore {
  const NativePhotoWidgetStore([
    this._channel = const MethodChannel('squadly/photo-widget'),
  ]);
  final MethodChannel _channel;
  @override
  Future<bool> isAvailable() async =>
      await _channel.invokeMethod<bool>('isAvailable') ?? false;
  @override
  Future<int> installedCount() async {
    final count = await _channel.invokeMethod<int>('installedCount');
    if (count == null || count < 0) {
      throw const FormatException('Invalid widget configuration count');
    }
    return count;
  }

  @override
  Future<PhotoWidgetSnapshot> read() => _request('read');
  @override
  Future<PhotoWidgetSnapshot> synchronize({
    required String? scope,
    required DateTime? expiresAt,
  }) => _request('synchronize', {
    'scope': scope,
    'expiresAt': expiresAt?.toUtc().millisecondsSinceEpoch,
  });
  @override
  Future<PhotoWidgetSnapshot> retainExpired({
    required String scope,
    required DateTime expiresAt,
  }) => _request('retainExpired', {
    'scope': scope,
    'expiresAt': expiresAt.toUtc().millisecondsSinceEpoch,
  });
  @override
  Future<PhotoWidgetSnapshot> bind({
    required PhotoWidgetLease lease,
    required String squadId,
    required String squadName,
  }) => _request('bind', {
    'scope': lease.scope,
    'generation': lease.generation,
    'squadId': squadId,
    'squadName': squadName,
  });
  @override
  Future<PhotoWidgetSnapshot> setPreview({
    required PhotoWidgetSnapshot expected,
    required bool enabled,
  }) => _request('setPreview', {..._identity(expected), 'enabled': enabled});
  @override
  Future<PhotoWidgetSnapshot> setPhoto({
    required PhotoWidgetSnapshot expected,
    required String messageId,
    required DateTime createdAt,
    required PhotoImage image,
  }) {
    if (!isPreparedJpeg(image.bytes, image.width, image.height)) {
      throw const FormatException('Invalid widget photo');
    }
    return _request('setPhoto', {
      ..._identity(expected),
      'messageId': messageId,
      'createdAt': createdAt.toUtc().millisecondsSinceEpoch,
      'bytes': image.bytes,
    });
  }

  @override
  Future<PhotoWidgetSnapshot> invalidate({
    required PhotoWidgetSnapshot expected,
    required bool failed,
  }) => _request('invalidate', {..._identity(expected), 'failed': failed});
  @override
  Future<PhotoWidgetSnapshot> applyHead({
    required PhotoWidgetSnapshot expected,
    required PhotoHead head,
    PhotoImage? image,
  }) {
    final photo = head.photo;
    if (!validPhotoHeadRevision(head.revision) ||
        (photo == null) != (image == null) ||
        (image != null &&
            !isPreparedJpeg(image.bytes, image.width, image.height))) {
      throw const FormatException('Invalid widget head');
    }
    return _request('applyHead', {
      ..._identity(expected),
      'revision': head.revision,
      if (photo != null) 'messageId': photo.id,
      if (photo != null)
        'createdAt': photo.createdAt.toUtc().millisecondsSinceEpoch,
      if (image != null) 'bytes': image.bytes,
    });
  }

  @override
  Future<void> unbind(PhotoWidgetSnapshot expected) async {
    await _request('unbind', _identity(expected));
  }

  Map<String, Object> _identity(PhotoWidgetSnapshot value) {
    if (value.binding == null ||
        value.lease == null ||
        value.binding!.scope != value.lease!.scope) {
      throw const FormatException('Unbound widget context');
    }
    return {
      'bindingId': value.binding!.id,
      'generation': value.lease!.generation,
    };
  }

  Future<PhotoWidgetSnapshot> _request(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    final raw = await _channel.invokeMethod<Object?>(method, arguments);
    if (raw is! Map) throw const FormatException('Invalid widget response');
    final map = Map<String, Object?>.from(raw);
    final displays = PhotoWidgetDisplay.values.where(
      (v) => v.name == map['state'],
    );
    final scheme = map['scheme'];
    if (displays.length != 1 ||
        (scheme != 'squadly' && scheme != 'squadly-test')) {
      throw const FormatException('Invalid widget state');
    }
    PhotoWidgetLease? lease;
    if (map['scope'] != null ||
        map['generation'] != null ||
        map['expiresAt'] != null) {
      if (map['scope'] is! String ||
          !widgetScope(map['scope'] as String) ||
          map['generation'] is! String ||
          !widgetUuid(map['generation'] as String) ||
          map['expiresAt'] is! int) {
        throw const FormatException('Invalid widget lease');
      }
      lease = PhotoWidgetLease(
        scope: map['scope'] as String,
        generation: map['generation'] as String,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          map['expiresAt'] as int,
          isUtc: true,
        ),
      );
    }
    PhotoWidgetBinding? binding;
    if (map['bindingId'] != null) {
      if (map['bindingId'] is! String ||
          !widgetUuid(map['bindingId'] as String) ||
          map['bindingScope'] is! String ||
          !widgetScope(map['bindingScope'] as String) ||
          map['squadId'] is! String ||
          !widgetUuid(map['squadId'] as String) ||
          map['squadName'] is! String ||
          (map['squadName'] as String).trim().isEmpty ||
          (map['squadName'] as String).length > 200 ||
          map['previewEnabled'] is! bool) {
        throw const FormatException('Invalid widget binding');
      }
      binding = PhotoWidgetBinding(
        id: map['bindingId'] as String,
        scope: map['bindingScope'] as String,
        squadId: map['squadId'] as String,
        squadName: map['squadName'] as String,
        previewEnabled: map['previewEnabled'] as bool,
      );
    }
    if (map['messageId'] != null &&
        (map['messageId'] is! String ||
            !widgetUuid(map['messageId'] as String))) {
      throw const FormatException('Invalid widget photo identity');
    }
    if (map['photoExpiresAt'] != null && map['photoExpiresAt'] is! int) {
      throw const FormatException('Invalid widget photo expiry');
    }
    return PhotoWidgetSnapshot(
      display: displays.single,
      scheme: scheme as String,
      lease: lease,
      binding: binding,
      messageId: map['messageId'] as String?,
      photoExpiresAt: map['photoExpiresAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              map['photoExpiresAt'] as int,
              isUtc: true,
            ),
    );
  }
}
