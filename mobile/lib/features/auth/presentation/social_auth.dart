import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/auth_service.dart';

/// Shared Google / Apple sign-in used by login + register screens.
class SocialAuth {
  SocialAuth._();

  static final _auth = AuthService();

  /// Web OAuth client from Firebase (type 3) — used as [GoogleSignIn.serverClientId]
  /// so the ID token audience matches the backend `GOOGLE_CLIENT_ID`.
  /// Single shared instance (must not construct a new GoogleSignIn per call).
  static final GoogleSignIn _google = GoogleSignIn(
    scopes: const ['email', 'profile'],
    serverClientId: AppConstants.googleServerClientId,
  );

  /// Quiet prep on login open — clears a sticky Google session if any.
  static Future<void> prepareGoogleSignIn() async {
    await signOutGoogle();
  }

  static Future<Map<String, dynamic>> signInWithGoogle() async {
    // Clear sticky Google session — avoids null idToken after a prior login.
    await signOutGoogle();

    final googleUser = await _google.signIn();
    if (googleUser == null) {
      throw StateError('cancelled');
    }

    var auth = await googleUser.authentication;
    var idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      try {
        await googleUser.clearAuthCache();
      } catch (_) {}
      auth = await googleUser.authentication;
      idToken = auth.idToken;
    }
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Google idToken missing — check CLIENT_ID / serverClientId',
      );
    }

    return _auth.loginWithGoogle(idToken);
  }

  /// Call on app logout / before sign-in so the next Google flow starts fresh.
  static Future<void> signOutGoogle() async {
    try {
      await _google.disconnect();
    } catch (_) {
      try {
        await _google.signOut();
      } catch (_) {}
    }
  }

  static Future<Map<String, dynamic>> signInWithApple() async {
    final cred = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final token = cred.identityToken;
    if (token == null || token.isEmpty) {
      throw StateError('Apple identityToken missing');
    }
    final displayName = [cred.givenName, cred.familyName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');
    return _auth.loginWithApple(
      identityToken: token,
      displayName: displayName.isNotEmpty ? displayName : null,
    );
  }

  static bool get isAppleAvailable => !kIsWeb && Platform.isIOS;
}
