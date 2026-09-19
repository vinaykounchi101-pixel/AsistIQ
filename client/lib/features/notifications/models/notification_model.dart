import 'package:flutter/material.dart';
import '../../../../shared/theme/colors.dart';

enum NotificationType {
  slaWarning,
  slaBreach,
  caseAssigned,
  internalNote,
  aiDraftReady,
  systemAlert,
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final String? caseId;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.caseId,
  });

  IconData get icon {
    switch (type) {
      case NotificationType.slaWarning:
        return Icons.timer_outlined;
      case NotificationType.slaBreach:
        return Icons.timer_off_outlined;
      case NotificationType.caseAssigned:
        return Icons.assignment_ind_outlined;
      case NotificationType.internalNote:
        return Icons.lock_outline;
      case NotificationType.aiDraftReady:
        return Icons.auto_awesome;
      case NotificationType.systemAlert:
        return Icons.warning_amber_rounded;
    }
  }

  Color get color {
    switch (type) {
      case NotificationType.slaWarning:
        return AppColors.warning;
      case NotificationType.slaBreach:
        return AppColors.error;
      case NotificationType.caseAssigned:
        return AppColors.secondary;
      case NotificationType.internalNote:
        return AppColors.accent;
      case NotificationType.aiDraftReady:
        return AppColors.primary;
      case NotificationType.systemAlert:
        return AppColors.warning;
    }
  }
}
