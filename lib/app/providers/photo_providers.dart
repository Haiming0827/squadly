import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../core/error/failures.dart';
import '../../core/network/cloudbase_client_provider.dart';
import '../../features/photos/data/cloudbase_photo_repository.dart';
import '../../features/photos/data/method_channel_photo_source.dart';
import '../../features/photos/domain/photo.dart';
import '../../features/photos/domain/photo_repository.dart';
import '../../features/photos/domain/prepare_squad_photo.dart';
import 'current_user_provider.dart';
import 'domain_repository_providers.dart';
import 'offline_access_provider.dart';

final photoGatewayUrlProvider = Provider<Uri?>((ref) {
  final config = ref.watch(cloudBaseConfigProvider);
  const raw = String.fromEnvironment('CLOUDBASE_PHOTO_GATEWAY_URL');
  if (config.useDemo || raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.port != 443 ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.path != '/photos' ||
      !uri.host.startsWith('${config.environmentId}-') ||
      !uri.host.endsWith('.${config.region}.app.tcloudbase.com')) {
    return null;
  }
  return uri;
});

final photoSessionReadyProvider = Provider<bool>((ref) {
  final id = ref.watch(currentUserProvider).asData?.value?.id;
  if (id == null || id.isEmpty) return false;
  final access = ref.watch(offlineAccessProvider);
  return access.status == OfflineAccessStatus.disabled ||
      (access.session?.userId == id && access.canReadAt(DateTime.now()));
});

final photoSendingAvailableProvider = Provider<bool>(
  (ref) =>
      ref.watch(photoGatewayUrlProvider) != null &&
      ref.watch(photoSessionReadyProvider) &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS,
);

final photoSourceProvider = Provider<PhotoSourceGateway>(
  (ref) => const MethodChannelPhotoSource(),
);

final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  final userId = ref.watch(currentUserProvider).asData?.value?.id ?? '';
  final endpoint = ref.watch(photoGatewayUrlProvider);
  if (userId.isEmpty || endpoint == null) return const _UnavailablePhotos();
  final app = ref.watch(cloudBaseAppProvider);
  final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));
  var active = true;
  ref.onDispose(() {
    active = false;
    dio.close(force: true);
  });
  return CloudBasePhotoRepository(
    userId: userId,
    endpoint: endpoint,
    dio: dio,
    credentials: () async {
      if (!active || !ref.read(photoSessionReadyProvider)) return null;
      final response = await app.auth.getSession();
      final session = response.data?.session;
      if (!active ||
          !response.isSuccess ||
          session?.user?.id != userId ||
          session?.accessToken == null ||
          ref.read(currentUserProvider).asData?.value?.id != userId ||
          !ref.read(photoSessionReadyProvider)) {
        return null;
      }
      return PhotoCredentials(
        userId: userId,
        accessToken: session!.accessToken!,
      );
    },
  );
});

final photoTargetAccessProvider = Provider<PhotoTargetAccess>((ref) {
  final userId = ref.watch(currentUserProvider).asData?.value?.id;
  final repository = ref.watch(squadRepositoryProvider);
  var active = true;
  ref.onDispose(() => active = false);
  bool current() =>
      active &&
      ref.read(photoSessionReadyProvider) &&
      ref.read(currentUserProvider).asData?.value?.id == userId;
  return (target) async {
    if (!current() || target.userId != userId) return false;
    final squads = await repository.getMySquads();
    if (!current()) return false;
    final member = squads.fold(
      (_) => false,
      (list) => list.any((s) => s.id == target.squadId),
    );
    if (!member) return false;
    final members = await repository.getSquadMembers(squadId: target.squadId);
    if (!current()) return false;
    return members.fold(
      (_) => false,
      (list) => list.length >= 2 && list.any((m) => m.userId == userId),
    );
  };
});

final prepareSquadPhotoProvider = Provider<PrepareSquadPhoto>(
  (ref) => PrepareSquadPhoto(
    source: ref.watch(photoSourceProvider),
    canAccess: ref.watch(photoTargetAccessProvider),
    nonce: const Uuid().v4,
    clock: DateTime.now,
  ),
);

final class _UnavailablePhotos implements PhotoRepository {
  const _UnavailablePhotos();
  static const failure = Failure.server(message: '当前版本的照片服务暂不可用');
  @override
  Future<Either<Failure, PublishedPhoto>> publish(PhotoDraft draft) async =>
      left(failure);
  @override
  Future<Either<Failure, PhotoImage>> load({
    required String squadId,
    required String messageId,
  }) async => left(failure);
  @override
  Future<Either<Failure, void>> revoke({
    required String squadId,
    required String messageId,
  }) async => left(failure);
}
