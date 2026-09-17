import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:asistiq_client/features/auth/models/user_model.dart';
import 'package:asistiq_client/features/auth/state/auth_notifier.dart';
import 'package:asistiq_client/features/auth/state/auth_state.dart';
import 'package:asistiq_client/features/cases/models/case_model.dart';
import 'package:asistiq_client/features/cases/services/case_api_service.dart';
import 'package:asistiq_client/features/dashboard/screens/admin_dashboard.dart';
import 'package:asistiq_client/features/dashboard/screens/lead_dashboard.dart';
import 'package:asistiq_client/features/dashboard/screens/manager_dashboard.dart';
import 'package:asistiq_client/features/dashboard/screens/operator_dashboard.dart';
import 'package:asistiq_client/features/dashboard/screens/requester_dashboard.dart';
import 'package:asistiq_client/features/dashboard/screens/role_dashboard_router.dart';
import 'package:asistiq_client/shared/api/api_client.dart';

class MockAuthNotifier extends AuthNotifier {
  MockAuthNotifier(UserRole role) : super(ApiClient()) {
    state = AuthState(
      status: AuthStatus.authenticated,
      user: UserModel(
        id: 'u-test',
        email: 'test@paradox.com',
        fullName: 'Test User',
        role: role,
      ),
    );
  }

  @override
  Future<void> checkAuth() async {}
}

class FakeCaseApiService extends CaseApiService {
  FakeCaseApiService() : super(ApiClient());

  @override
  Future<List<CaseModel>> listCases({
    String? status,
    String? priority,
    String? assignedTo,
    int skip = 0,
    int limit = 50,
  }) async {
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Role-Based Dynamic Dashboard Routing', () {
    testWidgets('Requester session renders RequesterDashboard', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) => MockAuthNotifier(UserRole.requester)),
            caseApiServiceProvider.overrideWithValue(FakeCaseApiService()),
          ],
          child: const MaterialApp(home: RoleDashboardRouter()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RequesterDashboard), findsOneWidget);
    });

    testWidgets('Operator session renders OperatorDashboard', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) => MockAuthNotifier(UserRole.operator)),
            caseApiServiceProvider.overrideWithValue(FakeCaseApiService()),
          ],
          child: const MaterialApp(home: RoleDashboardRouter()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OperatorDashboard), findsOneWidget);
    });

    testWidgets('Team Lead session renders LeadDashboard', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) => MockAuthNotifier(UserRole.lead)),
            caseApiServiceProvider.overrideWithValue(FakeCaseApiService()),
          ],
          child: const MaterialApp(home: RoleDashboardRouter()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LeadDashboard), findsOneWidget);
    });

    testWidgets('Manager session renders ManagerDashboard', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) => MockAuthNotifier(UserRole.manager)),
            caseApiServiceProvider.overrideWithValue(FakeCaseApiService()),
          ],
          child: const MaterialApp(home: RoleDashboardRouter()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ManagerDashboard), findsOneWidget);
    });

    testWidgets('Admin session renders AdminDashboard', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) => MockAuthNotifier(UserRole.admin)),
            caseApiServiceProvider.overrideWithValue(FakeCaseApiService()),
          ],
          child: const MaterialApp(home: RoleDashboardRouter()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminDashboard), findsOneWidget);
    });
  });
}
