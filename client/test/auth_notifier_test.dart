import 'package:flutter_test/flutter_test.dart';
import 'package:asistiq_client/features/auth/models/user_model.dart';
import 'package:asistiq_client/features/auth/state/auth_state.dart';

void main() {
  group('AuthState and Transitions', () {
    test('Initial state is unauthenticated without user', () {
      const state = AuthState();
      expect(state.status, AuthStatus.initial);
      expect(state.isAuthenticated, false);
      expect(state.user, null);
    });

    test('Authenticated state reflects active user profile', () {
      const user = UserModel(
        id: '123',
        email: 'test@paradox.com',
        fullName: 'Test Agent',
        role: UserRole.operator,
      );

      final state = const AuthState().copyWith(
        status: AuthStatus.authenticated,
        user: user,
      );

      expect(state.isAuthenticated, true);
      expect(state.user?.fullName, 'Test Agent');
      expect(state.user?.role, UserRole.operator);
    });
  });
}
