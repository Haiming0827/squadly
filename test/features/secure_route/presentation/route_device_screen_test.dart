import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/auth/domain/entities/user.dart';
import 'package:squadly/features/auth/presentation/providers/auth_provider.dart';
import 'package:squadly/features/secure_route/data/route_crypto.dart';
import 'package:squadly/features/secure_route/data/route_device_key_store.dart';
import 'package:squadly/features/secure_route/domain/route_key_directory.dart';
import 'package:squadly/features/secure_route/domain/route_sharing.dart';
import 'package:squadly/features/secure_route/presentation/route_device_screen.dart';
import 'package:squadly/features/secure_route/presentation/route_reader_provider.dart';

final class _SignedIn extends AuthNotifier {
  @override
  AsyncValue<User?> build() => AsyncData(
    User(id: 'alice', nickname: '阿青', createdAt: DateTime.utc(2026, 10, 8)),
  );
}

final class _Vault implements RouteSecretVault {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

final class _Directory implements RouteKeyDirectory {
  RouteRecipient? registered;
  bool fail = false;

  @override
  Future<void> registerDevice(RouteRecipient device) async {
    if (fail) throw const RouteDeviceRegistrationException();
    registered = device;
  }

  @override
  Future<List<RouteRecipient>> listRecipients(String squadId) async => const [];
}

void main() {
  testWidgets('registers only public key and shows fingerprint', (
    tester,
  ) async {
    final vault = _Vault();
    final directory = _Directory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_SignedIn.new),
          routeDeviceKeyStoreProvider.overrideWithValue(
            RouteDeviceKeyStore(vault: vault, crypto: RouteCrypto()),
          ),
          routeKeyDirectoryProvider.overrideWithValue(directory),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const RouteDeviceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(vault.values, isEmpty);
    await tester.tap(find.text('登记此设备以接收路线'));
    await tester.pumpAndSettle();

    expect(directory.registered?.userId, 'alice');
    expect(directory.registered?.publicKeyBase64, isNotEmpty);
    expect(find.text('此设备已登记'), findsOneWidget);
    expect(find.text('本机设备指纹'), findsOneWidget);
    expect(vault.values.values.single, contains('private_key'));
    expect(
      directory.registered!.publicKeyBase64,
      isNot(contains('private_key')),
    );
  });

  testWidgets('registration failure is not shown as success', (tester) async {
    final directory = _Directory()..fail = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_SignedIn.new),
          routeDeviceKeyStoreProvider.overrideWithValue(
            RouteDeviceKeyStore(vault: _Vault(), crypto: RouteCrypto()),
          ),
          routeKeyDirectoryProvider.overrideWithValue(directory),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const RouteDeviceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('登记此设备以接收路线'));
    await tester.pumpAndSettle();
    expect(find.textContaining('设备登记失败'), findsOneWidget);
    expect(find.text('此设备已登记'), findsNothing);
  });
}
