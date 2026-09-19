import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_exceptions.dart';
import 'auth_interceptor.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage;

  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  ApiClient({
    String baseUrl = defaultBaseUrl,
    FlutterSecureStorage? storage,
    Dio? customDio,
  }) : _storage = storage ?? const FlutterSecureStorage() {
    _dio = customDio ??
        Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 60),
            receiveTimeout: const Duration(seconds: 60),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

    _dio.interceptors.add(AuthInterceptor(_dio, storage: _storage));
  }

  Dio get dio => _dio;
  FlutterSecureStorage get storage => _storage;

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _sendRequest(() => _dio.get(path, queryParameters: queryParameters, options: options));
  }

  Future<dynamic> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _sendRequest(() => _dio.post(path, data: data, queryParameters: queryParameters, options: options));
  }

  Future<dynamic> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _sendRequest(() => _dio.put(path, data: data, queryParameters: queryParameters, options: options));
  }

  Future<dynamic> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _sendRequest(() => _dio.patch(path, data: data, queryParameters: queryParameters, options: options));
  }

  Future<dynamic> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _sendRequest(() => _dio.delete(path, data: data, queryParameters: queryParameters, options: options));
  }

  Future<dynamic> _sendRequest(Future<Response> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: e.toString());
    }
  }

  ApiException _handleDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError) {
      return const NetworkException();
    }

    final response = error.response;
    if (response == null) {
      return ApiException(message: error.message ?? 'Unknown connection error');
    }

    final statusCode = response.statusCode;
    String message = 'An error occurred';
    String? errorCode;
    dynamic details;

    if (response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      message = data['message'] as String? ?? data['detail'] as String? ?? message;
      errorCode = data['error_code'] as String?;
      details = data['details'];
    } else if (response.data is String) {
      message = response.data as String;
    }

    switch (statusCode) {
      case 401:
        return UnauthorizedException(message: message, details: details);
      case 403:
        return ForbiddenException(message: message, details: details);
      case 404:
        return NotFoundException(message: message, details: details);
      case 409:
        return ConflictException(message: message, details: details);
      case 422:
        return ValidationException(message: message, details: details);
      default:
        return ApiException(
          message: message,
          statusCode: statusCode,
          errorCode: errorCode,
          details: details,
        );
    }
  }
}
