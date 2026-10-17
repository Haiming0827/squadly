import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../../core/error/exceptions.dart';

/// Native Apple authorization stays separate from the CloudBase token exchange.
abstract interface class AppleIdentityGateway {
  Future<String?> requestIdToken({required String hashedNonce});
}

final class NativeAppleIdentityGateway implements AppleIdentityGateway {
  const NativeAppleIdentityGateway();

  @override
  Future<String?> requestIdToken({required String hashedNonce}) async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      return credential.identityToken;
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const ServerException(message: '已取消 Apple 登录');
      }
      throw const ServerException(message: 'Apple 授权失败，请重试');
    } on SignInWithAppleException {
      throw const ServerException(message: '此设备暂不支持 Apple 登录');
    }
  }
}
