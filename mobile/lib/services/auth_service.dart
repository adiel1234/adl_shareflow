import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/network/api_client.dart';
import '../core/constants/app_constants.dart';

class AuthService {
  final _storage = const FlutterSecureStorage();
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
  }) async {
    final response = await _api.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    await _saveTokens(response.data['data']);
    return response.data['data']['user'];
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
    final refreshToken = await _storage.read(key: AppConstants.refreshTokenKey);
    try {
      await _api.post('/auth/logout', data: {'refresh_token': refreshToken});
    } catch (_) {}
    await _storage.deleteAll();
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: AppConstants.accessTokenKey);
    return token != null;
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    await _storage.write(
      key: AppConstants.accessTokenKey,
      value: data['access_token'],
    );
    await _storage.write(
      key: AppConstants.refreshTokenKey,
      value: data['refresh_token'],
    );
  }
}
