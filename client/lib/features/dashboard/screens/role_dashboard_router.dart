import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/models/user_model.dart';
import '../../auth/state/auth_notifier.dart';
import 'admin_dashboard.dart';
import 'lead_dashboard.dart';
import 'manager_dashboard.dart';
import 'operator_dashboard.dart';
import 'requester_dashboard.dart';

class RoleDashboardRouter extends ConsumerWidget {
  const RoleDashboardRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;
    final role = user?.role ?? UserRole.requester;

    Widget dashboard;
    switch (role) {
      case UserRole.requester:
        dashboard = const RequesterDashboard();
        break;
      case UserRole.operator:
        dashboard = const OperatorDashboard();
        break;
      case UserRole.lead:
        dashboard = const LeadDashboard();
        break;
      case UserRole.manager:
        dashboard = const ManagerDashboard();
        break;
      case UserRole.admin:
        dashboard = const AdminDashboard();
        break;
    }

    return Material(
      color: const Color(0xFFF8FAFC),
      child: dashboard,
    );
  }
}
