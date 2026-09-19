import 'package:flutter/material.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/spacing.dart';
import '../models/case_model.dart';

class StatusChip extends StatelessWidget {
  final CaseStatus status;

  const StatusChip({super.key, required this.status});

  Color get _color {
    switch (status) {
      case CaseStatus.draft:
        return AppColors.textMutedDark;
      case CaseStatus.newCase:
        return AppColors.primary;
      case CaseStatus.inAssessment:
        return AppColors.secondary;
      case CaseStatus.assigned:
        return AppColors.info;
      case CaseStatus.awaitingRequester:
      case CaseStatus.awaitingApproval:
        return AppColors.warning;
      case CaseStatus.resolved:
      case CaseStatus.closed:
        return AppColors.success;
      case CaseStatus.cancelled:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: _color.withOpacity(0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            status.toDisplayString(),
            style: TextStyle(
              color: _color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
