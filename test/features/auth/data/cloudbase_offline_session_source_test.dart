import 'dart:convert';

import 'package:cloudbase_flutter/cloudbase_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:squadly/features/auth/data/datasources/cloudbase_offline_session_source.dart';

void main() {
  final expiry = DateTime.utc(2027, 1, 1);
  test(
    'uses absolute JWT expiry; expiresIn cannot extend a restored session',
    () {
      final parsed = offlineSessionFromSdk(_session(expiry));
      expect(parsed.userId, 'a');
      expect(parsed.expiresAt, expiry);
      expect(parsed.isValidAt(expiry), isFalse);
      expect(
        parsed.isValidAt(expiry.subtract(const Duration(microseconds: 1))),
        isTrue,
      );
    },
  );
  test('chooses earlier SDK expiry in seconds or milliseconds', () {
    final earlier = expiry.subtract(const Duration(minutes: 1));
    for (final timestamp in [
      earlier.millisecondsSinceEpoch,
      earlier.millisecondsSinceEpoch ~/ 1000,
    ]) {
      expect(
        offlineSessionFromSdk(_session(expiry, sdkExpiry: timestamp)).expiresAt,
        earlier,
      );
    }
    expect(
      offlineSessionFromSdk(
        _session(
          expiry,
          sdkExpiry: expiry.add(const Duration(days: 1)).millisecondsSinceEpoch,
        ),
      ).expiresAt,
      expiry,
    );
  });
  test(
    'rejects missing/noninteger expiry, subject mismatch and malformed tokens',
    () {
      for (final claims in <Map<String, Object?>>[
        {'sub': 'a'},
        {'sub': 'a', 'exp': '1798761600'},
        {'sub': 'b', 'exp': 1798761600},
        {'sub': 'a', 'exp': 0},
      ]) {
        expect(
          () => offlineSessionFromSdk(_session(expiry, token: _jwt(claims))),
          throwsFormatException,
        );
      }
      for (final token in [
        '',
        'not-a-token',
        'x.%%%?.signature',
        '.e30.signature',
        'x.e30.',
      ]) {
        expect(
          () => offlineSessionFromSdk(_session(expiry, token: token)),
          throwsA(isA<Exception>()),
        );
      }
      expect(
        () => offlineSessionFromSdk(_session(expiry, sdkExpiry: 0)),
        throwsFormatException,
      );
    },
  );
  test(
    'expired identity is preserved for retention/account-switch handling',
    () {
      final old = offlineSessionFromSdk(_session(DateTime.utc(2020)));
      expect(old.userId, 'a');
      expect(old.isValidAt(DateTime.utc(2026)), isFalse);
    },
  );
  test(
    'SDK event subscription needs no session refresh or profile HTTP',
    () async {
      final auth = _Auth();
      late OnAuthStateChangeCallback callback;
      var cancelled = false;
      registerFallbackValue(
        (AuthStateChangeEvent e, Session? s, AuthStateChangeInfo? i) {},
      );
      when(() => auth.onAuthStateChange(any())).thenAnswer((call) {
        callback = call.positionalArguments.single as OnAuthStateChangeCallback;
        return CloudBaseResponse(
          data: OnAuthStateChangeResultData(
            subscription: Subscription(
              id: 'local',
              callback: callback,
              unsubscribe: () => cancelled = true,
            ),
          ),
        );
      });
      final events = <Object?>[];
      final subscription = CloudBaseOfflineSessionSource(auth)
          .watch()
          .listen(events.add, onError: events.add);
      callback(AuthStateChangeEvent.initialSession, _session(expiry), null);
      callback(AuthStateChangeEvent.signedOut, null, null);
      callback(
        AuthStateChangeEvent.signedIn,
        _session(expiry, token: 'bad'),
        null,
      );
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(3));
      expect(events[1], isNull);
      expect(events[2], isA<FormatException>());
      verifyNever(() => auth.getSession());
      verifyNever(() => auth.getUser());
      verifyNever(() => auth.refreshSession());
      await subscription.cancel();
      expect(cancelled, isTrue);
    },
  );
}

Session _session(DateTime expiry, {int? sdkExpiry, String? token}) => Session(
  accessToken:
      token ?? _jwt({'sub': 'a', 'exp': expiry.millisecondsSinceEpoch ~/ 1000}),
  user: User(id: 'a', createdAt: '2026-01-01T00:00:00Z'),
  expiresAt: sdkExpiry,
  expiresIn: 999999999,
);
String _jwt(Map<String, Object?> claims) =>
    'e30.${base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '')}.signature';

class _Auth extends Mock implements CloudBaseAuth {}
