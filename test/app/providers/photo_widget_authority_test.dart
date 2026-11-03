import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/app/providers/current_user_provider.dart';
import 'package:squadly/app/providers/offline_access_provider.dart';
import 'package:squadly/app/providers/photo_widget_providers.dart';
import 'package:squadly/core/config/cloudbase_config.dart';
import 'package:squadly/core/network/cloudbase_client_provider.dart';
import 'package:squadly/features/auth/domain/entities/user.dart';
import 'package:squadly/features/auth/domain/offline_session.dart';
import 'package:squadly/features/photo_widget/domain/photo_widget_lifecycle.dart';

final _user = StateProvider<AsyncValue<User?>>((ref) => const AsyncData(null));

final class _Source implements OfflineSessionSource {
  final events = StreamController<OfflineSession?>.broadcast(sync: true);
  @override
  Stream<OfflineSession?> watch() => events.stream;
}

User user(String id) =>
    User(id: id, nickname: '合成账号', createdAt: DateTime.utc(2026));
void main() {
  late _Source source;
  late ProviderContainer container;
  setUp(() {
    source = _Source();
    container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) => ref.watch(_user)),
        offlineSessionSourceProvider.overrideWithValue(source),
        cloudBaseConfigProvider.overrideWithValue(
          CloudBaseConfig.fromValues(
            useDemo: 'false',
            environmentId: 'fixture-env',
            region: 'ap-shanghai',
            publishableKey: 'fixture-publishable-key-00000',
          ),
        ),
      ],
    );
    container.listen(photoWidgetAuthorityProvider, (_, _) {});
  });
  tearDown(() async {
    container.dispose();
    await source.events.close();
  });
  void sdk(String id, {bool expired = false}) => source.events.add(
    OfflineSession(
      userId: id,
      expiresAt: DateTime.now().add(Duration(hours: expired ? -1 : 1)),
    ),
  );
  test('initial SDK then profile recovery are distinct from logout', () {
    expect(
      container.read(photoWidgetAuthorityProvider).mode,
      PhotoWidgetAccessMode.restoring,
    );
    expect(container.read(photoWidgetAuthorityProvider).context, isNull);
    sdk('a');
    expect(
      container.read(photoWidgetAuthorityProvider).mode,
      PhotoWidgetAccessMode.restoring,
    );
    expect(container.read(photoWidgetAuthorityProvider).context?.userId, 'a');
    container.read(_user.notifier).state = AsyncData(user('a'));
    expect(
      container.read(photoWidgetAuthorityProvider).mode,
      PhotoWidgetAccessMode.ready,
    );
  });
  test('different SDK account is available for scope validation before profile exists', () {
    sdk('b');
    expect(container.read(photoWidgetAuthorityProvider).context?.userId, 'b');
    container.read(_user.notifier).state = AsyncData(user('a'));
    expect(
      container.read(photoWidgetAuthorityProvider).mode,
      PhotoWidgetAccessMode.blocked,
    );
  });
  test(
    'explicit authentication pause/loading/error and signout are blocked',
    () {
      container.read(offlineAccessProvider.notifier).pauseForAuthentication();
      expect(
        container.read(photoWidgetAuthorityProvider).mode,
        PhotoWidgetAccessMode.blocked,
      );
      container.read(_user.notifier).state = const AsyncLoading();
      expect(
        container.read(photoWidgetAuthorityProvider).mode,
        PhotoWidgetAccessMode.blocked,
      );
      container.read(_user.notifier).state = AsyncError(
        StateError('controlled'),
        StackTrace.empty,
      );
      expect(
        container.read(photoWidgetAuthorityProvider).mode,
        PhotoWidgetAccessMode.blocked,
      );
      source.events.add(null);
      container.read(_user.notifier).state = const AsyncData(null);
      expect(
        container.read(photoWidgetAuthorityProvider).mode,
        PhotoWidgetAccessMode.blocked,
      );
    },
  );
  test(
    'expired SDK permits only an inert reference; unavailable SDK is blocked',
    () {
      sdk('a', expired: true);
      expect(
        container.read(photoWidgetAuthorityProvider).mode,
        PhotoWidgetAccessMode.expired,
      );
      source.events.addError(StateError('controlled'));
      expect(
        container.read(photoWidgetAuthorityProvider).mode,
        PhotoWidgetAccessMode.blocked,
      );
    },
  );
}
