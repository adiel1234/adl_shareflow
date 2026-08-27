import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../core/storage/secure_storage.dart';
import '../core/network/api_client.dart';
import '../services/app_badge_service.dart';
import '../services/fcm_service.dart';
import '../features/auth/presentation/social_auth.dart';

// Current user state
class AuthState {
  final bool isLoggedIn;
  final Map<String, dynamic>? user;
  final bool isLoading;
  final String preferredCurrency;

  const AuthState({
    this.isLoggedIn = false,
    this.user,
    this.isLoading = true,
    this.preferredCurrency = 'ILS',
  });

  AuthState copyWith({
    bool? isLoggedIn,
    Map<String, dynamic>? user,
    bool? isLoading,
    String? preferredCurrency,
  }) =>
      AuthState(
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        preferredCurrency: preferredCurrency ?? this.preferredCurrency,
      );

  String get userId => user?['id'] as String? ?? '';
  String get displayName => user?['display_name'] as String? ?? '';
  String get email => user?['email'] as String? ?? '';
  String get plan => user?['plan'] as String? ?? 'free';
  bool get isPro => plan == 'pro';
  String? get avatarUrl => user?['avatar_url'] as String?;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final currency =
        await AppSecureStorage.read(AppConstants.preferredCurrencyKey) ??
            'ILS';
    var token = await AppSecureStorage.read(AppConstants.accessTokenKey);
    final refresh =
        await AppSecureStorage.read(AppConstants.refreshTokenKey);

    // Access missing but refresh still present — try silent refresh first.
    if (token == null && refresh != null) {
      final result = await ApiClient.tryRefreshToken();
      if (result == RefreshResult.success) {
        token = await AppSecureStorage.read(AppConstants.accessTokenKey);
      } else if (result == RefreshResult.networkError) {
        // Stay "logged in" optimistically so UI can retry later.
        state = AuthState(
          isLoggedIn: true,
          isLoading: false,
          preferredCurrency: currency,
        );
        return;
      } else {
        state = AuthState(
          isLoggedIn: false,
          isLoading: false,
          preferredCurrency: currency,
        );
        return;
      }
    }

    if (token == null) {
      state = AuthState(
        isLoggedIn: false,
        isLoading: false,
        preferredCurrency: currency,
      );
      return;
    }

    try {
      final response = await ApiClient.instance.get('/users/me');
      state = AuthState(
        isLoggedIn: true,
        user: response.data['data'] as Map<String, dynamic>,
        isLoading: false,
        preferredCurrency: currency,
      );
      FcmService.instance.registerToken();
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      // Only hard-logout when the access token is rejected after refresh
      // already failed. 403 (e.g. pilot / plan gate) must keep the session.
      if (status == 401) {
        final refresh =
            await AppSecureStorage.read(AppConstants.refreshTokenKey);
        if (refresh != null) {
          final result = await ApiClient.tryRefreshToken();
          if (result == RefreshResult.success) {
            try {
              final retry = await ApiClient.instance.get('/users/me');
              state = AuthState(
                isLoggedIn: true,
                user: retry.data['data'] as Map<String, dynamic>,
                isLoading: false,
                preferredCurrency: currency,
              );
              FcmService.instance.registerToken();
              return;
            } catch (_) {}
          } else if (result == RefreshResult.networkError) {
            state = AuthState(
              isLoggedIn: true,
              isLoading: false,
              preferredCurrency: currency,
            );
            return;
          }
        }
        await AppSecureStorage.clearSessionTokens();
        state = AuthState(
          isLoggedIn: false,
          isLoading: false,
          preferredCurrency: currency,
        );
      } else {
        // Network / 403 / 5xx — keep session; user data may load later.
        state = AuthState(
          isLoggedIn: true,
          isLoading: false,
          preferredCurrency: currency,
        );
      }
    } catch (_) {
      state = AuthState(
        isLoggedIn: true,
        isLoading: false,
        preferredCurrency: currency,
      );
    }
  }

  void setUser(Map<String, dynamic> user) {
    state = state.copyWith(isLoggedIn: true, user: user, isLoading: false);
    FcmService.instance.registerToken();
  }

  Future<void> setPreferredCurrency(String currency) async {
    await AppSecureStorage.write(AppConstants.preferredCurrencyKey, currency);
    state = state.copyWith(preferredCurrency: currency);
  }

  Future<void> logout() async {
    // Clear session only — keep remembered login credentials if user opted in.
    try {
      await SocialAuth.signOutGoogle();
    } catch (_) {}
    try {
      await AppSecureStorage.clearSessionTokens();
    } catch (_) {}
    try {
      await AppBadgeService.clear();
    } catch (_) {}
    final currency =
        await AppSecureStorage.read(AppConstants.preferredCurrencyKey) ??
            'ILS';
    state = AuthState(
      isLoggedIn: false,
      isLoading: false,
      preferredCurrency: currency,
    );
    try {
      await FcmService.instance
          .unregisterToken()
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<void> refresh() => _init();

  /// Upload a profile photo. Returns the new avatar_url on success.
  Future<String?> uploadAvatar(File imageFile) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imageFile.path,
        filename: 'avatar.jpg',
      ),
    });
    final response = await ApiClient.instance.post(
      '/users/me/avatar',
      data: formData,
    );
    final url = response.data['data']['avatar_url'] as String?;
    if (url != null && state.user != null) {
      final updated = Map<String, dynamic>.from(state.user!);
      updated['avatar_url'] = url;
      state = state.copyWith(user: updated);
    }
    return url;
  }

  /// Remove the profile photo.
  Future<void> deleteAvatar() async {
    await ApiClient.instance.delete('/users/me/avatar');
    if (state.user != null) {
      final updated = Map<String, dynamic>.from(state.user!);
      updated['avatar_url'] = null;
      state = state.copyWith(user: updated);
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
