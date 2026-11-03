import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/error/failures.dart';
import '../../core/network/cloudbase_auth_gate.dart';
import '../../core/network/cloudbase_client_provider.dart';
import '../../core/network/cloudbase_session_identity.dart';
import '../../features/conversation/domain/conversation_photo_repository.dart';
import '../../features/photo_widget/data/native_photo_widget_store.dart';
import '../../features/photo_widget/data/photo_background_credentials.dart';
import '../../features/photo_widget/data/photo_background_renewal.dart';
import '../../features/photo_widget/domain/photo_widget.dart';
import '../../features/photo_widget/domain/photo_widget_lifecycle.dart';
import '../../features/photo_widget/domain/photo_widget_service.dart';
import 'current_user_provider.dart';
import 'domain_repository_providers.dart';
import 'offline_access_provider.dart';
import 'photo_providers.dart';

class _WidgetContext extends Notifier<PhotoWidgetContext?> {
  int _revision = 0;
  @override
  PhotoWidgetContext? build() {
    final userId = ref.watch(
      currentUserProvider.select((v) => v.asData?.value?.id),
    );
    final access = ref.watch(
      offlineAccessProvider.select(
        (v) => (v.status, v.session?.userId, v.session?.expiresAt),
      ),
    );
    final config = ref.watch(cloudBaseConfigProvider);
    _revision++;
    if (config.useDemo ||
        userId == null ||
        access.$1 != OfflineAccessStatus.available ||
        access.$2 != userId ||
        access.$3 == null ||
        !DateTime.now().isBefore(access.$3!)) {
      return null;
    }
    return PhotoWidgetContext(
      environmentId: config.environmentId,
      userId: userId,
      expiresAt: access.$3!,
      revision: _revision,
    );
  }
}

final _photoWidgetContextEpochProvider =
    NotifierProvider<_WidgetContext, PhotoWidgetContext?>(_WidgetContext.new);
final photoWidgetContextProvider = Provider<PhotoWidgetContext?>(
  (ref) => ref.watch(_photoWidgetContextEpochProvider),
);
final photoWidgetStoreProvider = Provider<PhotoWidgetStore>(
  (ref) => const NativePhotoWidgetStore(),
);
final photoBackgroundCredentialControllerProvider =
    Provider<PhotoBackgroundCredentialController>((ref) {
      var active = true;
      final controller = PhotoBackgroundCredentialController(
        bridge: const NativePhotoBackgroundCredentialBridge(),
        read: () async {
          final config = ref.read(cloudBaseConfigProvider);
          final owner = ref.read(photoWidgetContextProvider);
          final gateway = ref.read(photoGatewayUrlProvider);
          if (!active ||
              config.useDemo ||
              owner == null ||
              gateway == null ||
              kIsWeb ||
              defaultTargetPlatform != TargetPlatform.iOS) {
            return null;
          }
          final response = await CloudBaseAuthGate.forAuth(
            ref.read(cloudBaseAppProvider).auth,
          ).session();
          if (!active || ref.read(photoWidgetContextProvider) != owner) {
            return null;
          }
          final session = response.data?.session;
          if (!response.isSuccess ||
              session?.user?.id != owner.userId ||
              session?.accessToken == null) {
            return null;
          }
          return PhotoBackgroundCredentialMaterial(
            environmentId: config.environmentId,
            region: config.region,
            userId: owner.userId,
            gateway: gateway,
            accessToken: session!.accessToken!,
            expiresAt: owner.expiresAt,
          );
        },
      );
      ref.onDispose(() {
        active = false;
        unawaited(controller.dispose());
      });
      return controller;
    });
final photoWidgetServiceProvider = Provider<PhotoWidgetService>((ref) {
  var active = true;
  ref.onDispose(() => active = false);
  bool matches(PhotoWidgetContext owner) =>
      active && ref.read(photoWidgetContextProvider) == owner;
  final service = PhotoWidgetService(
    store: ref.watch(photoWidgetStoreProvider),
    context: () => active ? ref.read(photoWidgetContextProvider) : null,
    onSnapshot: (snapshot) {
      if (!active ||
          kIsWeb ||
          defaultTargetPlatform != TargetPlatform.iOS ||
          ref.read(cloudBaseConfigProvider).useDemo) {
        return;
      }
      unawaited(
        ref.read(photoBackgroundCredentialControllerProvider).accept(snapshot),
      );
    },
    squad: (owner, squadId) async {
      if (!matches(owner)) return left(const Failure.unauthorized());
      final repo = ref.read(squadRepositoryProvider);
      final squads = await repo.getMySquads();
      if (!matches(owner)) return left(const Failure.unauthorized());
      final target = squads
          .getRight()
          .toNullable()
          ?.where((s) => s.id == squadId)
          .firstOrNull;
      if (target == null) {
        return left(
          squads.getLeft().getOrElse(
            () => const Failure.permissionDenied(message: '你已无法查看这个小队'),
          ),
        );
      }
      final members = await repo.getSquadMembers(squadId: squadId);
      if (!matches(owner)) return left(const Failure.unauthorized());
      final list = members.getRight().toNullable();
      if (list == null) {
        return left(members.getLeft().getOrElse(() => const Failure.network()));
      }
      if (list.length < 2 || !list.any((m) => m.userId == owner.userId)) {
        return left(const Failure.permissionDenied(message: '邀请队友后再绑定小队组件'));
      }
      return right(target);
    },
    latest: (owner, squadId) async {
      if (!matches(owner)) return left(const Failure.unauthorized());
      final repo = ref.read(conversationRepositoryProvider);
      if (repo is! ConversationPhotoRepository) {
        return left(const Failure.server(message: '当前版本暂不支持照片查询'));
      }
      return (repo as ConversationPhotoRepository).photoHead(squadId);
    },
    find: (owner, squadId, messageId) async {
      if (!matches(owner)) return left(const Failure.unauthorized());
      final repo = ref.read(conversationRepositoryProvider);
      if (repo is! ConversationPhotoRepository) {
        return left(const Failure.server(message: '当前版本暂不支持照片查询'));
      }
      return (repo as ConversationPhotoRepository).findPhoto(
        squadId: squadId,
        messageId: messageId,
      );
    },
    load: (owner, squadId, messageId) async {
      if (!matches(owner)) return left(const Failure.unauthorized());
      return ref
          .read(photoRepositoryProvider)
          .load(squadId: squadId, messageId: messageId);
    },
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Initial SDK restoration has no logout verdict. Known SDK identity can
/// validate the persisted scope without issuing new private credentials.
final photoWidgetAuthorityProvider = Provider<PhotoWidgetAuthority>((ref) {
  final config = ref.watch(cloudBaseConfigProvider);
  final user = ref.watch(currentUserProvider);
  final access = ref.watch(offlineAccessProvider);
  const blocked = (mode: PhotoWidgetAccessMode.blocked, context: null);
  if (config.useDemo || user.isLoading || user.hasError) return blocked;
  if (access.initialRestoration &&
      access.status == OfflineAccessStatus.checking &&
      user.asData?.value == null) {
    return (mode: PhotoWidgetAccessMode.restoring, context: null);
  }
  final sdk = access.session;
  if (access.status == OfflineAccessStatus.expired && sdk != null) {
    final userId = user.asData?.value?.id;
    if (userId != null && userId != sdk.userId) return blocked;
    return (
      mode: PhotoWidgetAccessMode.expired,
      context: PhotoWidgetContext(
        environmentId: config.environmentId,
        userId: sdk.userId,
        expiresAt: sdk.expiresAt,
      ),
    );
  }
  if (access.status != OfflineAccessStatus.available ||
      sdk == null ||
      !access.canReadAt(DateTime.now())) {
    return blocked;
  }
  final owner = PhotoWidgetContext(
    environmentId: config.environmentId,
    userId: sdk.userId,
    expiresAt: sdk.expiresAt,
  );
  final userId = user.asData?.value?.id;
  if (userId == null) {
    return (mode: PhotoWidgetAccessMode.restoring, context: owner);
  }
  if (userId != sdk.userId) return blocked;
  final confirmed = ref.watch(photoWidgetContextProvider);
  return confirmed == null
      ? blocked
      : (mode: PhotoWidgetAccessMode.ready, context: confirmed);
});

final photoWidgetLifecycleProvider = Provider<void>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
  final service = ref.watch(photoWidgetServiceProvider);
  final lifecycle = PhotoWidgetLifecycle(
    service: service,
    store: ref.read(photoWidgetStoreProvider),
    clearCredentials: () =>
        ref.read(photoBackgroundCredentialControllerProvider).reset(),
    expireCredentials: () async {
      await const MethodChannel('squadly/photo-background')
          .invokeMethod<bool>('status');
    },
  );
  final renewal = PhotoBackgroundRenewalController(
    hold: (scope) => lifecycle.beginRecovery(scope: scope),
    release: lifecycle.endRecovery,
    read: (request, isCurrent) async {
      bool allowed() =>
          isCurrent() &&
          ref.read(photoWidgetAuthorityProvider).mode !=
              PhotoWidgetAccessMode.blocked;
      if (!allowed()) return null;
      final config = ref.read(cloudBaseConfigProvider);
      final gateway = ref.read(photoGatewayUrlProvider);
      if (config.useDemo || gateway == null) return null;
      final response = await CloudBaseAuthGate.forAuth(
        ref.read(cloudBaseAppProvider).auth,
      ).session(isCurrent: allowed);
      if (!allowed() || !response.isSuccess) return null;
      final session = response.data?.session;
      if (session == null) return null;
      final identity = cloudBaseSessionIdentity(session);
      final owner = PhotoWidgetContext(
        environmentId: config.environmentId,
        userId: identity.userId,
        expiresAt: identity.expiresAt,
      );
      if (await photoWidgetScope(owner) != request.scope || !allowed()) {
        return null;
      }
      final userId = ref.read(currentUserProvider).asData?.value?.id;
      if (userId != null && userId != identity.userId) return null;
      return PhotoBackgroundCredentialMaterial(
        environmentId: config.environmentId,
        region: config.region,
        userId: identity.userId,
        gateway: gateway,
        accessToken: session.accessToken!,
        expiresAt: identity.expiresAt,
      );
    },
  );
  bool foreground() =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  ref.listen(photoWidgetAuthorityProvider, (previous, next) {
    if (next.mode == PhotoWidgetAccessMode.blocked) renewal.invalidate();
    unawaited(lifecycle.accept(next, foreground: foreground()));
  });
  final observer = _WidgetObserver(
    (state) => unawaited(
      lifecycle.accept(
        ref.read(photoWidgetAuthorityProvider),
        foreground: state == AppLifecycleState.resumed,
        force: state == AppLifecycleState.resumed,
      ),
    ),
  );
  WidgetsBinding.instance.addObserver(observer);
  unawaited(
    lifecycle.accept(
      ref.read(photoWidgetAuthorityProvider),
      foreground: foreground(),
    ),
  );
  if (!ref.read(cloudBaseConfigProvider).useDemo) unawaited(renewal.start());
  ref.onDispose(() {
    unawaited(renewal.dispose());
    lifecycle.dispose();
    WidgetsBinding.instance.removeObserver(observer);
  });
});

class _WidgetObserver extends WidgetsBindingObserver {
  _WidgetObserver(this.changed);
  final ValueChanged<AppLifecycleState> changed;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => changed(state);
}
