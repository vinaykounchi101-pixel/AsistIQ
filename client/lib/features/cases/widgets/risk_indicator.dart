import 'package:flutter/material.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/spacing.dart';
import '../models/case_model.dart';

class RiskIndicator extends StatelessWidget {
  final RiskLevel riskLevel;

  const RiskIndicator({super.key, required this.riskLevel});

  Color get _color {
    switch (riskLevel) {
      case RiskLevel.critical:
        return AppColors.riskCritical;
      case RiskLevel.high:
        return AppColors.riskHigh;
      case RiskLevel.moderate:
        return AppColors.riskModerate;
      case RiskLevel.low:
        return AppColors.riskLow;
    }
  }

  IconData get _icon {
    switch (riskLevel) {
      case RiskLevel.critical:
        return Icons.warning_amber_rounded;
      case RiskLevel.high:
        return Icons.error_outline;
      case RiskLevel.moderate:
        return Icons.info_outline;
      case RiskLevel.low:
        return Icons.shield_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
        border: Border.all(color: _color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 12, color: _color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Risk: ${riskLevel.toDisplayString()}',
            style: TextStyle(
              color: _color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
