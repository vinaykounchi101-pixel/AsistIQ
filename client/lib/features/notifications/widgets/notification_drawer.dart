import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/spacing.dart';
import '../models/notification_model.dart';

class NotificationDrawer extends StatefulWidget {
  const NotificationDrawer({super.key});

  @override
  State<NotificationDrawer> createState() => _NotificationDrawerState();
}

class _NotificationDrawerState extends State<NotificationDrawer> {
  final List<AppNotification> _notifications = [
    AppNotification(
      id: 'n-1',
      title: 'SLA Breach Warning',
      body: 'Case INC-2026-000002 response deadline approaching in 14 minutes.',
      type: NotificationType.slaWarning,
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      caseId: 'bd0ef4af-aced-45f3-98ab-cda83ade9589',
    ),
    AppNotification(
      id: 'n-2',
      title: 'New Incident Assigned',
      body: 'You have been assigned to Case INC-2026-000001 (Database Connection Pool Depletion).',
      type: NotificationType.caseAssigned,
      createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
      caseId: '76ce7339-a991-4cf4-9e7f-bbf7f0980ff6',
    ),
    AppNotification(
      id: 'n-3',
      title: 'AI Draft Ready for Review',
      body: 'Finny AI Copilot generated a resolution draft for Case INC-2026-000003.',
      type: NotificationType.aiDraftReady,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      caseId: 'c125d0ef-4567-4890-bcde-123456789abc',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surfaceDark,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_outlined, color: AppColors.primary, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Notifications',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All notifications marked as read.')),
                      );
                    },
                    child: const Text('Mark all read', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderDark),
            Expanded(
              child: _notifications.isEmpty
                  ? const Center(
                      child: Text('No unread notifications.', style: TextStyle(color: AppColors.textMutedDark)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.base),
                      itemCount: _notifications.length,
                      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final n = _notifications[index];
                        return Card(
                          margin: EdgeInsets.zero,
                          color: AppColors.cardDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            side: BorderSide(color: n.color.withValues(alpha: 0.3)),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            onTap: () {
                              Navigator.pop(context);
                              if (n.caseId != null) {
                                context.go('/cases/${n.caseId}');
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(n.icon, color: n.color, size: 16),
                                      const SizedBox(width: AppSpacing.xs),
                                      Expanded(
                                        child: Text(
                                          n.title,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: n.color),
                                        ),
                                      ),
                                      Text(
                                        DateFormat.jm().format(n.createdAt),
                                        style: const TextStyle(fontSize: 11, color: AppColors.textMutedDark),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    n.body,
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
