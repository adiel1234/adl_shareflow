import '../core/network/api_client.dart';
import '../core/constants/app_constants.dart';
import '../core/storage/secure_storage.dart';

class AuthService {
  final _api = ApiClient.instance;

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _api.post('/auth/register', data: {
      'email': email,
      'password': password,
      'display_name': displayName,
    });
    await _saveTokens(response.data['data']);
    return response.data['data']['user'];
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    final response = await _api.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    await _saveTokens(response.data['data']);
    await saveRememberedCredentials(
      email: email,
      password: password,
      rememberMe: rememberMe,
    );
    return response.data['data']['user'];
  }

  /// Persist login hints that survive logout (userfill with user consent).
  Future<void> saveRememberedCredentials({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    if (rememberMe) {
      await AppSecureStorage.write(AppConstants.rememberMeKey, 'true');
      await AppSecureStorage.write(
          AppConstants.rememberedEmailKey, email.trim());
      await AppSecureStorage.write(
          AppConstants.rememberedPasswordKey, password);
    } else {
      await AppSecureStorage.delete(AppConstants.rememberMeKey);
      await AppSecureStorage.delete(AppConstants.rememberedEmailKey);
      await AppSecureStorage.delete(AppConstants.rememberedPasswordKey);
    }
  }

  Future<({String? email, String? password, bool rememberMe})>
      loadRememberedCredentials() async {
    final remember =
        await AppSecureStorage.read(AppConstants.rememberMeKey) == 'true';
    if (!remember) {
      return (email: null, password: null, rememberMe: false);
    }
    final email =
        await AppSecureStorage.read(AppConstants.rememberedEmailKey);
    final password =
        await AppSecureStorage.read(AppConstants.rememberedPasswordKey);
    return (email: email, password: password, rememberMe: true);
  }

  Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    final response = await _api.post('/auth/google', data: {'id_token': idToken});
    await _saveTokens(response.data['data']);
    return response.data['data']['user'];
  }

  Future<Map<String, dynamic>> loginWithApple({
    required String identityToken,
    String? displayName,
  }) async {
    final response = await _api.post('/auth/apple', data: {
      'identity_token': identityToken,
      'display_name': displayName,
    });
    await _saveTokens(response.data['data']);
    return response.data['data']['user'];
  }

  Future<void> logout() async {
    final refreshToken =
        await AppSecureStorage.read(AppConstants.refreshTokenKey);
    try {
      await _api.post('/auth/logout', data: {'refresh_token': refreshToken});
    } catch (_) {}
    await AppSecureStorage.clearSessionTokens();
  }

  Future<bool> isLoggedIn() async {
    final token = await AppSecureStorage.read(AppConstants.accessTokenKey);
    return token != null;
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    await AppSecureStorage.write(
      AppConstants.accessTokenKey,
      data['access_token'] as String,
    );
    await AppSecureStorage.write(
      AppConstants.refreshTokenKey,
      data['refresh_token'] as String,
    );
  }
}
