import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthInterceptor extends QueuedInterceptor {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  static const String accessTokenKey = 'asistiq_access_token';
  static const String refreshTokenKey = 'asistiq_refresh_token';

  AuthInterceptor(this._dio, {FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Skip attaching auth token for public auth endpoints
    if (options.path.contains('/auth/login') ||
        options.path.contains('/auth/register') ||
        options.path.contains('/auth/refresh') ||
        options.path.contains('/auth/google')) {
      return handler.next(options);
    }

    try {
      final token = await _storage.read(key: accessTokenKey);
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // Storage access failure fallback
    }

    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !err.requestOptions.path.contains('/auth/refresh')) {
      final refreshToken = await _storage.read(key: refreshTokenKey);
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          // Attempt token refresh with dedicated dio instance to avoid interceptor loop
          final refreshDio = Dio(BaseOptions(baseUrl: _dio.options.baseUrl));
          final response = await refreshDio.post(
            '/api/v1/auth/refresh',
            data: {'refresh_token': refreshToken},
          );

          if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
            final data = response.data as Map<String, dynamic>;
            final tokens = data['tokens'] as Map<String, dynamic>?;
            final newAccessToken = (tokens?['access_token'] ?? data['access_token']) as String?;
            final newRefreshToken = (tokens?['refresh_token'] ?? data['refresh_token']) as String?;

            if (newAccessToken != null) {
              await _storage.write(key: accessTokenKey, value: newAccessToken);
              if (newRefreshToken != null) {
                await _storage.write(key: refreshTokenKey, value: newRefreshToken);
              }

              // Retry original request with new token
              final originalOptions = err.requestOptions;
              originalOptions.headers['Authorization'] = 'Bearer $newAccessToken';
              final retryResponse = await _dio.fetch(originalOptions);
              return handler.resolve(retryResponse);
            }
          }
        } catch (_) {
          // Refresh failed: wipe invalid tokens
          await _storage.delete(key: accessTokenKey);
          await _storage.delete(key: refreshTokenKey);
        }
      }
    }

    return handler.next(err);
  }
}
