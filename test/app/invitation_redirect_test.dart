import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/app/router.dart';

void main() {
  test('login resumes an invitation inside the app', () {
    expect(
      invitationReturnPath('/invite/opaque-token-123'),
      '/invite/opaque-token-123',
    );
  });

  test('login never redirects to an arbitrary external URL', () {
    expect(invitationReturnPath('https://evil.test/collect'), '/');
    expect(invitationReturnPath('//evil.test/collect'), '/');
  });
}
