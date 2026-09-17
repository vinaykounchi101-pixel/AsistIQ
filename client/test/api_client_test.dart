import 'package:flutter_test/flutter_test.dart';
import 'package:asistiq_client/shared/api/api_exceptions.dart';
import 'package:asistiq_client/features/auth/models/user_model.dart';

void main() {
  group('API Exception Envelope Mapping', () {
    test('ApiException subclasses map status codes accurately', () {
      const unauth = UnauthorizedException(message: 'Session expired');
      expect(unauth.statusCode, 401);
      expect(unauth.errorCode, 'UNAUTHORIZED');

      const forbidden = ForbiddenException(message: 'Access denied');
      expect(forbidden.statusCode, 403);
      expect(forbidden.errorCode, 'FORBIDDEN');

      const notFound = NotFoundException(message: 'Case not found');
      expect(notFound.statusCode, 404);
      expect(notFound.errorCode, 'NOT_FOUND');

      const conflict = ConflictException(message: 'Optimistic lock mismatch');
      expect(conflict.statusCode, 409);
      expect(conflict.errorCode, 'CONFLICT');

      const validation = ValidationException(message: 'Invalid payload');
      expect(validation.statusCode, 422);
      expect(validation.errorCode, 'VALIDATION_ERROR');
    });

    test('UserModel and UserRole permissions serialization', () {
      final user = UserModel.fromJson({
        'id': 'u1',
        'email': 'admin@paradox.com',
        'full_name': 'System Admin',
        'role': 'system_admin',
        'department': 'IT Support',
        'is_active': true,
      });

      expect(user.role, UserRole.admin);
      expect(user.role.isAdmin, true);
      expect(user.role.isStaff, true);
      expect(user.role.toDisplayString(), 'System Admin');

      final operatorUser = UserModel.fromJson({
        'id': 'u2',
        'email': 'op@paradox.com',
        'full_name': 'Tier 1 Operator',
        'role': 'operator',
      });

      expect(operatorUser.role, UserRole.operator);
      expect(operatorUser.role.isAdmin, false);
      expect(operatorUser.role.isStaff, true);
      expect(operatorUser.role.toDisplayString(), 'Operator');
    });
  });
}
