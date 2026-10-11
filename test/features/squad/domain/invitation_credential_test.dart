import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/squad/domain/invitation_credential.dart';

void main() {
  test('a short code remains the redemption credential', () {
    expect(InvitationCredential.parse('  ab12cd3456  '), 'AB12CD3456');
  });

  test('an invitation link exposes only its token to redemption', () {
    const token =
        'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
    expect(
      InvitationCredential.parse('https://links.example.test/invite/$token'),
      token,
    );
  });

  test('a deep-link route passes its high-entropy token unchanged', () {
    const token =
        'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
    expect(InvitationCredential.parse(token), token);
  });

  test('other links cannot be used as invitation credentials', () {
    expect(
      () => InvitationCredential.parse(
        'https://links.example.test/profile/abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
      ),
      throwsFormatException,
    );
  });

  test('invitation link is composed from the configured base URL', () {
    const token =
        'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
    expect(
      InvitationCredential.linkFor(
        baseUrl: 'https://links.example.test/',
        token: token,
      ).toString(),
      'https://links.example.test/invite/$token',
    );
  });

  test('invalid token length is rejected before contacting the server', () {
    expect(
      () => InvitationCredential.parse('OpaqueToken_12345678901234567890'),
      throwsFormatException,
    );
  });
}
