import 'package:flutter/material.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/spacing.dart';
import '../models/case_model.dart';

class PriorityBadge extends StatelessWidget {
  final CasePriority priority;

  const PriorityBadge({super.key, required this.priority});

  Color get _color {
    switch (priority) {
      case CasePriority.p1Critical:
        return AppColors.p1Critical;
      case CasePriority.p2High:
        return AppColors.p2High;
      case CasePriority.p3Medium:
        return AppColors.p3Medium;
      case CasePriority.p4Low:
        return AppColors.p4Low;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
        border: Border.all(color: _color.withOpacity(0.4), width: 1),
      ),
      child: Text(
        priority.code,
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
