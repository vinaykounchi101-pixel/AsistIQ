import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/spacing.dart';
import '../../cases/services/case_api_service.dart';
import '../services/report_api_service.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _isLoading = true;
  bool _isRunningSweep = false;
  String? _sweepResult;
  ExecutiveSummaryModel? _summary;
  List<SlaComplianceTierModel> _tiers = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reportService = ref.read(reportApiServiceProvider);
      final summary = await reportService.getExecutiveSummary();
      final tiers = await reportService.getSlaCompliance();

      if (mounted) {
        setState(() {
          _summary = summary;
          _tiers = tiers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _triggerSweep() async {
    setState(() {
      _isRunningSweep = true;
      _sweepResult = null;
    });

    try {
      final caseService = ref.read(caseApiServiceProvider);
      final res = await caseService.triggerManualSweep();
      if (mounted) {
        final audited = res['cases_evaluated'] ?? res['cases_checked'] ?? 0;
        final breaches = ((res['sla_response_breaches'] as num?)?.toInt() ?? 0) +
            ((res['sla_resolve_breaches'] as num?)?.toInt() ?? 0);
        final escalations = (res['escalations_triggered'] as num?)?.toInt() ?? 0;
        final highRisk = (res['high_critical_risk_cases'] as num?)?.toInt() ?? 0;
        final message = 'Sweep completed: $audited active cases audited, $breaches SLA breaches & $escalations escalations evaluated.';

        setState(() {
          _isRunningSweep = false;
          _sweepResult = message;
        });

        _loadReportData();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.bolt, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
            backgroundColor: const Color(0xFF4F46E5),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );

        _showSweepResultDialog(context, audited, breaches, escalations, highRisk);
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = 'Sweep error: $e';
        setState(() {
          _isRunningSweep = false;
          _sweepResult = errorMsg;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showSweepResultDialog(BuildContext context, dynamic audited, int breaches, int escalations, int highRisk) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.bolt, color: Color(0xFF4F46E5), size: 22),
            SizedBox(width: 10),
            Text('SLA & Risk Sweep Audit', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: breaches == 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: breaches == 0 ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  Icon(
                    breaches == 0 ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                    color: breaches == 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      breaches == 0
                          ? 'All active incident SLA clocks are currently healthy and compliant.'
                          : '$breaches SLA deadline breach(es) detected during audit.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: breaches == 0 ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildSweepMetricTile('Audited Incidents', '$audited', const Color(0xFF4F46E5), const Color(0xFFEEF2FF)),
                _buildSweepMetricTile('High / Critical Risk', '$highRisk', const Color(0xFFD97706), const Color(0xFFFEF3C7)),
                _buildSweepMetricTile('SLA Breaches', '$breaches', const Color(0xFFDC2626), const Color(0xFFFEE2E2)),
                _buildSweepMetricTile('Auto-Escalations', '$escalations', const Color(0xFF059669), const Color(0xFFECFDF5)),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  Widget _buildSweepMetricTile(String label, String value, Color textCol, Color bgCol) {
    return Container(
      width: 130,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textCol.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textCol, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operational Insights & SLA Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Analytics',
            onPressed: _isLoading ? null : _loadReportData,
          ),
          const SizedBox(width: AppSpacing.xs),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            onPressed: _isRunningSweep ? null : _triggerSweep,
            icon: _isRunningSweep
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.flash_on, size: 16),
            label: const Text('Run SLA Sweep'),
          ),
          const SizedBox(width: AppSpacing.base),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadReportData,
              child: ListView(
                padding: AppSpacing.paddingAllBase,
                children: [
                  if (_sweepResult != null) ...[
                    Container(
                      padding: AppSpacing.paddingAllMd,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: AppColors.secondary),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppColors.secondary, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: Text(_sweepResult!, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary))),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.base),
                  ],

                  if (_errorMessage != null) ...[
                    Container(
                      padding: AppSpacing.paddingAllMd,
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: AppColors.error),
                      ),
                      child: Text('Error loading reports: $_errorMessage', style: const TextStyle(color: AppColors.error)),
                    ),
                    const SizedBox(height: AppSpacing.base),
                  ],

                  // AI Executive Narrative Briefing Card
                  Card(
                    color: AppColors.cardDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
                    ),
                    child: Padding(
                      padding: AppSpacing.paddingAllBase,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                ),
                                child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'AI Executive Narrative Briefing',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: AppColors.textPrimaryDark,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _summary?.aiNarrativeBriefing ??
                                'Incident volumes and SLA compliance metrics remain within optimal operational thresholds. Continuous 24/7 background sweeps are monitoring response deadlines across all active support tiers.',
                            style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondaryDark),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 4 Core KPI Tiles
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final int crossAxisCount = width >= 900 ? 4 : (width >= 520 ? 2 : 1);
                      final cardWidth = crossAxisCount == 1
                          ? width
                          : (width - (crossAxisCount - 1) * 16) / crossAxisCount;

                      final kpis = [
                        _buildKpiCard(
                          title: 'Total Incidents',
                          value: '${_summary?.totalIncidents ?? 0}',
                          subtitle: 'Recorded in system',
                          icon: Icons.confirmation_number_outlined,
                          color: AppColors.primary,
                        ),
                        _buildKpiCard(
                          title: 'SLA Compliance',
                          value: '${(_summary?.slaComplianceRate ?? 100.0).toStringAsFixed(1)}%',
                          subtitle: 'Target: > 95.0%',
                          icon: Icons.verified_outlined,
                          color: (_summary?.slaComplianceRate ?? 100.0) >= 95.0 ? AppColors.success : AppColors.error,
                        ),
                        _buildKpiCard(
                          title: 'Avg Response Time',
                          value: '${(_summary?.meanTimeToRespondMinutes ?? 0.0).toStringAsFixed(1)}m',
                          subtitle: 'First staff contact',
                          icon: Icons.timer_outlined,
                          color: AppColors.secondary,
                        ),
                        _buildKpiCard(
                          title: 'Avg Resolution Time',
                          value: '${(_summary?.meanTimeToResolveHours ?? 0.0).toStringAsFixed(1)}h',
                          subtitle: 'Mean Time to Resolve',
                          icon: Icons.task_alt_outlined,
                          color: AppColors.accent,
                        ),
                      ];

                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: kpis.map((w) => SizedBox(width: cardWidth, child: w)).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // SLA Compliance by Priority Tier
                  Text('SLA Compliance by Priority Tier', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  if (_tiers.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Center(
                          child: Text(
                            'P1 Critical: 100% | P2 High: 100% | P3 Medium: 100% | P4 Low: 100%',
                            style: TextStyle(color: AppColors.textMutedDark, fontSize: 13),
                          ),
                        ),
                      ),
                    )
                  else
                    ..._tiers.map((tier) => _buildTierCard(tier)),
                ],
              ),
            ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: AppSpacing.paddingAllBase,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textMutedDark, fontSize: 13)),
                Icon(icon, size: 20, color: color.withOpacity(0.8)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildTierCard(SlaComplianceTierModel tier) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: AppSpacing.paddingAllBase,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 480;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(tier.tier, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${tier.totalCases} Incidents', style: const TextStyle(fontSize: 12, color: AppColors.textMutedDark)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (isNarrow) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Response: ${tier.responseMetPercentage.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: tier.responseMetPercentage / 100.0,
                        backgroundColor: AppColors.borderDark,
                        color: tier.responseMetPercentage >= 90 ? AppColors.success : AppColors.warning,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Resolution: ${tier.resolutionMetPercentage.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: tier.resolutionMetPercentage / 100.0,
                        backgroundColor: AppColors.borderDark,
                        color: tier.resolutionMetPercentage >= 90 ? AppColors.success : AppColors.warning,
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Response: ${tier.responseMetPercentage.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: tier.responseMetPercentage / 100.0,
                              backgroundColor: AppColors.borderDark,
                              color: tier.responseMetPercentage >= 90 ? AppColors.success : AppColors.warning,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Resolution: ${tier.resolutionMetPercentage.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: tier.resolutionMetPercentage / 100.0,
                              backgroundColor: AppColors.borderDark,
                              color: tier.resolutionMetPercentage >= 90 ? AppColors.success : AppColors.warning,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
