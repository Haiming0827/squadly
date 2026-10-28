import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/notifications/domain/push_registration.dart';

final class _Source implements PushTokenSource {
  _Source(this.token);

  String? token;
  bool available = true;
  bool authorized = true;
  int requestCalls = 0;
  int unregisterCalls = 0;

  @override
  String get provider => 'apns';

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> isAuthorized() async => authorized;

  @override
  Future<String?> requestToken() async {
    requestCalls++;
    return token;
  }

  @override
  Future<void> unregister() async => unregisterCalls++;
}

final class _Ids implements PushDeviceIdStore {
  String? value;
  int created = 0;

  @override
  Future<String?> loadExisting() async => value;

  @override
  Future<String> loadOrCreate() async {
    created++;
    return value ??= 'device-a';
  }
}

final class _Repository implements PushTokenRepository {
  final registrations = <String>[];
  final unregistrations = <String>[];

  @override
  Future<void> register({
    required String deviceId,
    required String provider,
    required String token,
  }) async {
    registrations.add('$deviceId/$provider/$token');
  }

  @override
  Future<void> unregister({
    required String deviceId,
    required String provider,
  }) async {
    unregistrations.add('$deviceId/$provider');
  }
}

void main() {
  test('registers a granted token against this install', () async {
    final repository = _Repository();
    final registration = PushRegistration(
      source: _Source('apns-token'),
      deviceIds: _Ids(),
      repository: repository,
    );

    expect(await registration.register(), PushRegistrationResult.registered);
    expect(repository.registrations, ['device-a/apns/apns-token']);
    await registration.unregister();
    expect(repository.unregistrations, ['device-a/apns']);
    expect((registration.source as _Source).unregisterCalls, 1);
  });

  test(
    'permission denial does not create a device ID or write backend',
    () async {
      final repository = _Repository();
      final ids = _Ids();
      final registration = PushRegistration(
        source: _Source(null),
        deviceIds: ids,
        repository: repository,
      );

      expect(await registration.register(), PushRegistrationResult.unavailable);
      await registration.unregister();
      expect(ids.created, 0);
      expect(repository.registrations, isEmpty);
      expect(repository.unregistrations, isEmpty);
      expect((registration.source as _Source).unregisterCalls, 1);
    },
  );

  test(
    'does not prompt for notification permission during silent sync',
    () async {
      final source = _Source(null)..authorized = false;
      final ids = _Ids();
      final repository = _Repository();
      final registration = PushRegistration(
        source: source,
        deviceIds: ids,
        repository: repository,
      );

      expect(
        await registration.register(),
        PushRegistrationResult.permissionRequired,
      );
      expect(source.requestCalls, 0);
      expect(ids.created, 0);
      expect(repository.registrations, isEmpty);
    },
  );

  test('permission is requested only after explicit user action', () async {
    final source = _Source(null)..authorized = false;
    final registration = PushRegistration(
      source: source,
      deviceIds: _Ids(),
      repository: _Repository(),
    );

    expect(
      await registration.register(requestPermission: true),
      PushRegistrationResult.permissionRequired,
    );
    expect(source.requestCalls, 1);
  });

  test(
    'unsupported build does not request permission or create device id',
    () async {
      final source = _Source(null)..available = false;
      final ids = _Ids();
      final repository = _Repository();
      final registration = PushRegistration(
        source: source,
        deviceIds: ids,
        repository: repository,
      );

      expect(
        await registration.register(requestPermission: true),
        PushRegistrationResult.unavailable,
      );
      expect(source.requestCalls, 0);
      expect(ids.created, 0);
      expect(repository.registrations, isEmpty);
    },
  );
}
