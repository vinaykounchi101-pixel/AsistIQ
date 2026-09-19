import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/admin/screens/admin_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/state/auth_notifier.dart';
import '../features/auth/state/auth_state.dart';
import '../features/cases/screens/case_detail_screen.dart';
import '../features/cases/screens/cases_screen.dart';
import '../features/cases/screens/create_case_screen.dart';
import '../features/dashboard/screens/role_dashboard_router.dart';
import '../features/reports/screens/reports_screen.dart';
import 'shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authNotifierProvider,
      (_, __) => notifyListeners(),
    );
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: notifier,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final isAuth = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';

      if (authState.status == AuthStatus.loading || authState.status == AuthStatus.initial) {
        return null;
      }

      if (!isAuth && !isLoggingIn) {
        return '/login';
      }

      if (isAuth && (isLoggingIn || state.matchedLocation == '/')) {
        return '/dashboard';
      }

      // Role permission guards
      if (isAuth && state.matchedLocation.startsWith('/admin')) {
        if (!(authState.user?.role.isAdmin ?? false)) {
          return '/dashboard';
        }
      }

      if (isAuth && state.matchedLocation.startsWith('/reports')) {
        if (!(authState.user?.role.isManagement ?? false)) {
          return '/dashboard';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          return AppShell(
            location: state.matchedLocation,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const RoleDashboardRouter(),
          ),
          GoRoute(
            path: '/cases',
            builder: (context, state) => const CasesScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const CreateCaseScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final caseId = state.pathParameters['id'] ?? '';
                  return CaseDetailScreen(caseId: caseId);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminScreen(),
          ),
        ],
      ),
    ],
  );
});
