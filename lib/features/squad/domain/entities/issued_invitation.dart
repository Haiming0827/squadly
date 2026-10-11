/// Plaintext credentials exist only in this issuance response and on the
/// captain's device. The server stores credential hashes.
final class IssuedInvitation {
  const IssuedInvitation({
    required this.id,
    required this.code,
    required this.linkToken,
    required this.expiresAt,
    required this.maxUses,
  });

  final String id;
  final String code;
  final String linkToken;
  final DateTime expiresAt;
  final int maxUses;
}
