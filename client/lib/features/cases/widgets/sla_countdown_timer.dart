import 'dart:async';
import 'package:flutter/material.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/spacing.dart';
import '../models/case_model.dart';

class SlaCountdownTimer extends StatefulWidget {
  final SlaModel? sla;
  final CaseStatus status;

  const SlaCountdownTimer({
    super.key,
    required this.sla,
    required this.status,
  });

  @override
  State<SlaCountdownTimer> createState() => _SlaCountdownTimerState();
}

class _SlaCountdownTimerState extends State<SlaCountdownTimer> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) {
      final abs = d.abs();
      return '-${abs.inHours.toString().padLeft(2, '0')}:${(abs.inMinutes % 60).toString().padLeft(2, '0')}:${(abs.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final sla = widget.sla;
    if (sla == null) {
      return const SizedBox.shrink();
    }

    // Response SLA
    final hasResponded = sla.firstResponseAt != null;
    final responseDeadline = sla.responseDeadline;
    final isResponseBreached = sla.isResponseBreached ||
        (!hasResponded && responseDeadline != null && _now.isAfter(responseDeadline));

    Duration? remainingResponse;
    if (!hasResponded && responseDeadline != null) {
      remainingResponse = responseDeadline.difference(_now);
    }

    // Resolution SLA
    final isResolved = widget.status == CaseStatus.resolved || widget.status == CaseStatus.closed;
    final resolutionDeadline = sla.resolutionDeadline;
    final isResolutionBreached = sla.isResolutionBreached ||
        (!isResolved && resolutionDeadline != null && _now.isAfter(resolutionDeadline));

    Duration? remainingResolution;
    if (!isResolved && resolutionDeadline != null) {
      remainingResolution = resolutionDeadline.difference(_now);
    }

    return Container(
      padding: AppSpacing.paddingAllMd,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          // 1. Initial Response Block
          Expanded(
            child: Row(
              children: [
                Icon(
                  hasResponded
                      ? Icons.check_circle_outline
                      : (isResponseBreached ? Icons.error_outline : Icons.timer_outlined),
                  size: 20,
                  color: hasResponded
                      ? AppColors.success
                      : (isResponseBreached ? AppColors.error : AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'First Response SLA',
                      style: TextStyle(fontSize: 11, color: AppColors.textMutedDark),
                    ),
                    Text(
                      hasResponded
                          ? 'Responded (Stopped)'
                          : (remainingResponse != null
                              ? _formatDuration(remainingResponse)
                              : 'Pending'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: hasResponded
                            ? AppColors.success
                            : (isResponseBreached ? AppColors.error : AppColors.textPrimaryDark),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 30,
            child: VerticalDivider(width: 24, thickness: 1, color: AppColors.borderDark),
          ),
          // 2. Resolution Block
          Expanded(
            child: Row(
              children: [
                Icon(
                  isResolved
                      ? Icons.verified_outlined
                      : (isResolutionBreached ? Icons.warning_amber_rounded : Icons.hourglass_bottom),
                  size: 20,
                  color: isResolved
                      ? AppColors.success
                      : (isResolutionBreached ? AppColors.error : AppColors.warning),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resolution SLA',
                      style: TextStyle(fontSize: 11, color: AppColors.textMutedDark),
                    ),
                    Text(
                      isResolved
                          ? 'Resolved'
                          : (remainingResolution != null
                              ? _formatDuration(remainingResolution)
                              : 'Pending'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isResolved
                            ? AppColors.success
                            : (isResolutionBreached ? AppColors.error : AppColors.textPrimaryDark),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
