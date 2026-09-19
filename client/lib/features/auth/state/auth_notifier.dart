import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/api/api_client.dart';
import '../../../shared/api/api_exceptions.dart';
import '../../../shared/api/auth_interceptor.dart';
import '../models/user_model.dart';
import 'auth_state.dart';

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(apiClient);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;

  AuthNotifier(this._apiClient) : super(const AuthState()) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final token = await _apiClient.storage.read(key: AuthInterceptor.accessTokenKey);
      if (token == null || token.isEmpty) {
        state = state.copyWith(status: AuthStatus.unauthenticated, user: null);
        return;
      }

      final response = await _apiClient.get('/api/v1/auth/me');
      if (response != null && response is Map<String, dynamic>) {
        final user = UserModel.fromJson(response);
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated, user: null);
      }
    } catch (_) {
      state = state.copyWith(status: AuthStatus.unauthenticated, user: null);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final response = await _apiClient.post(
        '/api/v1/auth/login',
        data: {
          'email': email.trim(),
          'password': password,
        },
      );

      if (response != null && response is Map<String, dynamic>) {
        final tokens = response['tokens'] as Map<String, dynamic>?;
        final accessToken = (tokens?['access_token'] ?? response['access_token']) as String?;
        final refreshToken = (tokens?['refresh_token'] ?? response['refresh_token']) as String?;
        final userData = response['user'] as Map<String, dynamic>?;

        if (accessToken != null) {
          await _apiClient.storage.write(key: AuthInterceptor.accessTokenKey, value: accessToken);
        }
        if (refreshToken != null) {
          await _apiClient.storage.write(key: AuthInterceptor.refreshTokenKey, value: refreshToken);
        }

        UserModel? user;
        if (userData != null) {
          user = UserModel.fromJson(userData);
        } else {
          final meResponse = await _apiClient.get('/api/v1/auth/me');
          if (meResponse is Map<String, dynamic>) {
            user = UserModel.fromJson(meResponse);
          }
        }

        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          errorMessage: null,
        );
        return true;
      }
      throw const ApiException(message: 'Invalid response from server');
    } on ApiException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> loginWithGoogle(String idToken) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final response = await _apiClient.post(
        '/api/v1/auth/google',
        data: {'id_token': idToken},
      );

      if (response != null && response is Map<String, dynamic>) {
        final tokens = response['tokens'] as Map<String, dynamic>?;
        final accessToken = (tokens?['access_token'] ?? response['access_token']) as String?;
        final refreshToken = (tokens?['refresh_token'] ?? response['refresh_token']) as String?;
        final userData = response['user'] as Map<String, dynamic>?;

        if (accessToken != null) {
          await _apiClient.storage.write(key: AuthInterceptor.accessTokenKey, value: accessToken);
        }
        if (refreshToken != null) {
          await _apiClient.storage.write(key: AuthInterceptor.refreshTokenKey, value: refreshToken);
        }

        UserModel? user;
        if (userData != null) {
          user = UserModel.fromJson(userData);
        }

        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          errorMessage: null,
        );
        return true;
      }
      throw const ApiException(message: 'Google login failed');
    } on ApiException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await _apiClient.storage.read(key: AuthInterceptor.refreshTokenKey);
      if (refreshToken != null) {
        await _apiClient.post('/api/v1/auth/logout', data: {'refresh_token': refreshToken});
      }
    } catch (_) {
      // Best-effort backend logout notification
    } finally {
      await _apiClient.storage.delete(key: AuthInterceptor.accessTokenKey);
      await _apiClient.storage.delete(key: AuthInterceptor.refreshTokenKey);
      state = const AuthState(status: AuthStatus.unauthenticated, user: null);
    }
  }
}
