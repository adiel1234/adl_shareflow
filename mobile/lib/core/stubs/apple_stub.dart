// Web stub for sign_in_with_apple — not supported on web
enum AppleIDAuthorizationScopes { email, fullName }

class AuthorizationCredentialAppleID {
  final String? identityToken;
  final String? givenName;
  final String? familyName;
  const AuthorizationCredentialAppleID({
    this.identityToken,
    this.givenName,
    this.familyName,
  });
}

class SignInWithApple {
  static Future<AuthorizationCredentialAppleID> getAppleIDCredential({
    List<AppleIDAuthorizationScopes> scopes = const [],
  }) async {
    throw UnsupportedError('Apple Sign-In is not supported on web');
  }
}
