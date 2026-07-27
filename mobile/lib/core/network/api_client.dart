import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../storage/secure_storage.dart';

/// Callbacks registered by the app layer to react to auth/error events.
typedef VoidCallback = void Function();
typedef MessageCallback = void Function(String message);

enum RefreshResult { success, invalid, networkError }

class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;

  /// Called when a 401 occurs and token refresh has failed (session expired).
  static VoidCallback? onSessionExpired;

  /// Called for unhandled server errors (5xx) with a human-readable message.
  static MessageCallback? onServerError;

  ApiClient._() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConstants.connectionTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(_AuthInterceptor(_dio));
    _dio.interceptors.add(LogInterceptor(
      request: AppConfig.isDev,
      responseBody: AppConfig.isDev,
      error: true,
    ));
  }

  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }

  Dio get dio => _dio;

  Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _dio.get(path, queryParameters: params);

  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  Future<Response> put(String path, {dynamic data}) =>
      _dio.put(path, data: data);

  Future<Response> delete(String path, {dynamic data}) =>
      _dio.delete(path, data: data);

  Future<Response> postFormData(String path, FormData formData) =>
      _dio.post(path, data: formData);

  /// Attempts to refresh the access token. Used by auth init and interceptor.
  static Future<RefreshResult> tryRefreshToken() async {
    final refreshToken =
        await AppSecureStorage.read(AppConstants.refreshTokenKey);
    if (refreshToken == null) return RefreshResult.invalid;

    try {
      final plainDio = Dio(BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConstants.connectionTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {'Content-Type': 'application/json'},
      ));
      final response = await plainDio.post('/auth/refresh', data: {
        'refresh_token': refreshToken,
      });
      final newToken = response.data['data']['access_token'] as String?;
      if (newToken == null || newToken.isEmpty) return RefreshResult.invalid;
      await AppSecureStorage.write(AppConstants.accessTokenKey, newToken);
      return RefreshResult.success;
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 401 || status == 403) {
        await AppSecureStorage.clearSessionTokens();
        return RefreshResult.invalid;
      }
      return RefreshResult.networkError;
    } catch (_) {
      return RefreshResult.networkError;
    }
  }
}

class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  bool _refreshing = false;

  _AuthInterceptor(this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await AppSecureStorage.read(AppConstants.accessTokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final path = err.requestOptions.path;
    final isRefreshCall = path.contains('/auth/refresh');
    final statusCode = err.response?.statusCode ?? 0;

    final isAuthCall = path.contains('/auth/');
    if (statusCode == 401 && !isRefreshCall && !isAuthCall) {
      final hadAuth = err.requestOptions.headers['Authorization'] != null;
      final refreshToken =
          await AppSecureStorage.read(AppConstants.refreshTokenKey);
      final hadSession = hadAuth || refreshToken != null;

      if (hadSession && !_refreshing) {
        _refreshing = true;
        final result = await ApiClient.tryRefreshToken();
        _refreshing = false;

        if (result == RefreshResult.success) {
          final token =
              await AppSecureStorage.read(AppConstants.accessTokenKey);
          err.requestOptions.headers['Authorization'] = 'Bearer $token';
          try {
            final response = await _dio.fetch(err.requestOptions);
            handler.resolve(response);
            return;
          } catch (_) {}
        } else if (result == RefreshResult.invalid) {
          // Only hard-logout when the refresh token itself is rejected.
          ApiClient.onSessionExpired?.call();
        }
        // networkError → do not logout; let the original error bubble up.
      } else if (hadSession && refreshToken == null) {
        ApiClient.onSessionExpired?.call();
      }
    } else if (statusCode >= 500) {
      final msg = (err.response?.data?['message'] as String?)
          ?? 'אירעה שגיאת שרת. נסה שוב מאוחר יותר.';
      ApiClient.onServerError?.call(msg);
    }

    handler.next(err);
  }
}
