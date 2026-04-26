import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../services/fcm_service.dart';

const _kPreferredCurrency = 'preferred_currency';

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
}

class AuthNotifier extends StateNotifier<AuthState> {
  final _storage = const FlutterSecureStorage();

  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final token = await _storage.read(key: AppConstants.accessTokenKey);
    final currency =
        await _storage.read(key: _kPreferredCurrency) ?? 'ILS';

    if (token == null) {
      state = AuthState(
          isLoggedIn: false, isLoading: false, preferredCurrency: currency);
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
    } catch (_) {
      await _storage.deleteAll();
      state = AuthState(
          isLoggedIn: false, isLoading: false, preferredCurrency: currency);
    }
  }

  void setUser(Map<String, dynamic> user) {
    state = state.copyWith(isLoggedIn: true, user: user, isLoading: false);
    FcmService.instance.registerToken();
  }

  Future<void> setPreferredCurrency(String currency) async {
    await _storage.write(key: _kPreferredCurrency, value: currency);
    state = state.copyWith(preferredCurrency: currency);
  }

  Future<void> logout() async {
    await FcmService.instance.unregisterToken();
    await _storage.deleteAll();
    state = const AuthState(isLoggedIn: false, isLoading: false);
  }

  Future<void> refresh() => _init();
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
