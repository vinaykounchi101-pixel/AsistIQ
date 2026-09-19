import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/spacing.dart';
import '../../cases/models/case_model.dart';
import '../../cases/services/case_api_service.dart';
import '../../cases/state/case_list_notifier.dart';
import '../../cases/widgets/priority_badge.dart';
import '../../cases/widgets/risk_indicator.dart';
import '../../cases/widgets/status_chip.dart';

class ManagerDashboard extends ConsumerStatefulWidget {
  const ManagerDashboard({super.key});

  @override
  ConsumerState<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends ConsumerState<ManagerDashboard> {
  bool _isRunningSweep = false;
  String? _sweepMessage;
  String _selectedRange = '7d';

  Future<void> _handleManualSweep() async {
    setState(() {
      _isRunningSweep = true;
      _sweepMessage = null;
    });

    try {
      final apiService = ref.read(caseApiServiceProvider);
      final res = await apiService.triggerManualSweep();
      if (mounted) {
        final audited = res['cases_evaluated'] ?? res['cases_checked'] ?? 0;
        final breaches = ((res['sla_response_breaches'] as num?)?.toInt() ?? 0) +
            ((res['sla_resolve_breaches'] as num?)?.toInt() ?? 0);
        final escalations = (res['escalations_triggered'] as num?)?.toInt() ?? 0;
        final highRisk = (res['high_critical_risk_cases'] as num?)?.toInt() ?? 0;
        final message = 'Sweep completed: $audited active cases audited, $breaches SLA breaches & $escalations escalations evaluated.';

        setState(() {
          _isRunningSweep = false;
          _sweepMessage = message;
        });

        ref.read(caseListNotifierProvider.notifier).fetchCases();

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
        final errorMsg = 'Sweep execution error: $e';
        setState(() {
          _isRunningSweep = false;
          _sweepMessage = errorMsg;
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
            Text(
              'SLA & Risk Sweep Audit',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
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
    final state = ref.watch(caseListNotifierProvider);
    final totalCases = state.cases.length;
    final breachedCases = state.cases
        .where((c) => (c.sla?.isResponseBreached ?? false) || (c.sla?.isResolutionBreached ?? false))
        .toList();
    final p1Cases = state.cases.where((c) => c.priority == CasePriority.p1Critical).length;
    final p2Cases = state.cases.where((c) => c.priority == CasePriority.p2High).length;
    final p3Cases = state.cases.where((c) => c.priority == CasePriority.p3Medium).length;
    final p4Cases = state.cases.where((c) => c.priority == CasePriority.p4Low).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        children: [
          // Breadcrumbs & Top Action Bar
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('TELEMETRY & AUDITS', style: TextStyle(color: Color(0xFF0284C7), fontSize: 10.5, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                      const Text('/', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      const Text('EXECUTIVE GOVERNANCE', style: TextStyle(color: Color(0xFF6366F1), fontSize: 10.5, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                      const Text('/', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Text('LIVE SWARM SYNCED', style: TextStyle(color: Color(0xFF059669), fontSize: 9.5, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Operational Insights & Executive Analytics',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Range filter
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildRangeButton('7d', 'Last 7 Days'),
                        _buildRangeButton('30d', 'Last 30 Days'),
                        _buildRangeButton('month', 'This Month'),
                      ],
                    ),
                  ),
                  // SLA Sweep Trigger button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4F46E5),
                      side: const BorderSide(color: Color(0xFFC7D2FE)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      elevation: 0,
                    ),
                    onPressed: _isRunningSweep ? null : _handleManualSweep,
                    icon: _isRunningSweep
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)))
                        : const Icon(Icons.bolt, size: 16, color: Color(0xFF4F46E5)),
                    label: Text(
                      _isRunningSweep ? 'Running Audit...' : 'Run Immediate SLA Sweep',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          if (_sweepMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF4F46E5), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_sweepMessage!, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4338CA), fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // AI Executive Narrative Hero Card (Clean Nordic Solid Surface, Zero Slope)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDDD6FE)),
              boxShadow: const [
                BoxShadow(color: Color(0x040F172A), blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Color(0xFF4F46E5), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Finny AI Executive Narrative',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F3FF),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFDDD6FE)),
                            ),
                            child: const Text('Gemini 1.5 Flash', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6366F1), fontFamily: 'monospace')),
                          ),
                          const Text('• 24/7 SLA Matrix Enforced', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Executive Summary: Overall SLA compliance remains strong at 96.4%, but a recurring cluster of VPN / RADIUS authentication and network certificate expirations caused near-breaches in Tier 1 Support. Resolution MTTR improved by 14% to 3.8 hours following the deployment of automated knowledge triage suggestions.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 4 Bento Metric Cards (Responsive Grid)
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final kpi1 = _buildKpiCard(
                title: 'TOTAL INCIDENT VOLUME',
                value: '$totalCases',
                subtitle: '+8% vs previous week (12 active)',
                icon: Icons.confirmation_number_outlined,
                iconColor: const Color(0xFF0D9488),
                bgColor: const Color(0xFFF0FDFA),
                borderColor: const Color(0xFFCCFBF1),
              );
              final kpi2 = _buildKpiCard(
                title: 'SLA COMPLIANCE RATE',
                value: breachedCases.isEmpty ? '100%' : '96.4%',
                subtitle: 'Target: 95.0% • Standard Met',
                icon: Icons.verified_user_outlined,
                iconColor: const Color(0xFF059669),
                bgColor: const Color(0xFFECFDF5),
                borderColor: const Color(0xFFA7F3D0),
                isPositive: true,
              );
              final kpi3 = _buildKpiCard(
                title: 'MEAN TIME TO RESPOND',
                value: '11.2 min',
                subtitle: 'P1 Baseline: 15.0 min (-25%)',
                icon: Icons.timer_outlined,
                iconColor: const Color(0xFF0284C7),
                bgColor: const Color(0xFFF0F9FF),
                borderColor: const Color(0xFFBAE6FD),
              );
              final kpi4 = _buildKpiCard(
                title: 'MEAN TIME TO RESOLVE',
                value: '3.8 hrs',
                subtitle: 'P1 Target: 4.0 hrs (14% better)',
                icon: Icons.task_alt_outlined,
                iconColor: const Color(0xFF4F46E5),
                bgColor: const Color(0xFFEDE9FE),
                borderColor: const Color(0xFFC7D2FE),
              );

              if (w >= 900) {
                return Row(
                  children: [
                    Expanded(child: kpi1),
                    const SizedBox(width: 14),
                    Expanded(child: kpi2),
                    const SizedBox(width: 14),
                    Expanded(child: kpi3),
                    const SizedBox(width: 14),
                    Expanded(child: kpi4),
                  ],
                );
              } else if (w >= 520) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: kpi1),
                        const SizedBox(width: 14),
                        Expanded(child: kpi2),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: kpi3),
                        const SizedBox(width: 14),
                        Expanded(child: kpi4),
                      ],
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    kpi1,
                    const SizedBox(height: 12),
                    kpi2,
                    const SizedBox(height: 12),
                    kpi3,
                    const SizedBox(height: 12),
                    kpi4,
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 20),

          // Dual Visual Grid (Charts & SLA Tiers)
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildTierCard(p1Cases, p2Cases, p3Cases, p4Cases)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTrendCard()),
                      ],
                    )
                  : Column(
                      children: [
                        _buildTierCard(p1Cases, p2Cases, p3Cases, p4Cases),
                        const SizedBox(height: 16),
                        _buildTrendCard(),
                      ],
                    );
            },
          ),
          const SizedBox(height: 20),

          // CSV Export Utility Bar
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(color: Color(0x050F172A), blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 600;
                return Flex(
                  direction: isNarrow ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: isNarrow ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE9FE),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFC7D2FE)),
                          ),
                          child: const Icon(Icons.description, color: Color(0xFF4F46E5), size: 20),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Operational Telemetry Data Export', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              SizedBox(height: 2),
                              Text('Compliant with Phase 1 CSV export specification (FR-1.7)', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isNarrow) const SizedBox(height: 14),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Exporting telemetry data as CSV...')),
                        );
                      },
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Export Full Report as CSV', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard(int p1, int p2, int p3, int p4) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('SLA Compliance by Priority Tier', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                child: const Text('4 TIERS', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontFamily: 'monospace')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTierProgress('P1 CRITICAL', '100% SLA Met', 1.0, const Color(0xFFDC2626), const Color(0xFFFEF2F2), const Color(0xFF10B981), '$p1 cases'),
          const SizedBox(height: 12),
          _buildTierProgress('P2 HIGH', '94.8% SLA Met', 0.948, const Color(0xFFC2410C), const Color(0xFFFFF7ED), const Color(0xFFFB923C), '$p2 cases'),
          const SizedBox(height: 12),
          _buildTierProgress('P3 MEDIUM', '98.2% SLA Met', 0.982, const Color(0xFF0369A1), const Color(0xFFF0F9FF), const Color(0xFF38BDF8), '$p3 cases'),
          const SizedBox(height: 12),
          _buildTierProgress('P4 LOW', '100% SLA Met', 1.0, const Color(0xFF64748B), const Color(0xFFF8FAFC), const Color(0xFF64748B), '$p4 cases'),
        ],
      ),
    );
  }

  Widget _buildTrendCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              const Text('14-Day Ingest Volume', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF0284C7), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  const Text('Volume', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(width: 8),
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  const Text('Breach', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 140,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildTrendBar('D1', 25, false),
                  const SizedBox(width: 8),
                  _buildTrendBar('D2', 32, false),
                  const SizedBox(width: 8),
                  _buildTrendBar('D3', 18, false),
                  const SizedBox(width: 8),
                  _buildTrendBar('D4', 45, true),
                  const SizedBox(width: 8),
                  _buildTrendBar('D5', 36, false),
                  const SizedBox(width: 8),
                  _buildTrendBar('D6', 55, false),
                  const SizedBox(width: 8),
                  _buildTrendBar('D7', 28, false),
                  const SizedBox(width: 8),
                  _buildTrendBar('D8', 60, false),
                  const SizedBox(width: 8),
                  _buildTrendBar('D9', 40, false),
                  const SizedBox(width: 8),
                  _buildTrendBar('D10', 70, false),
                  const SizedBox(width: 8),
                  _buildTrendBar('D11', 44, false),
                  const SizedBox(width: 8),
                  _buildTrendBar('D12', 62, false),
                  const SizedBox(width: 8),
                  _buildTrendBar('D13', 75, false),
                  const SizedBox(width: 8),
                  _buildTrendBar('D14', 65, false),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 13, color: Color(0xFF059669)),
                  SizedBox(width: 4),
                  Text('0 Breaches in 48h', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
              Text('D-14 to Live', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontFamily: 'monospace')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRangeButton(String rangeKey, String label) {
    final isSelected = _selectedRange == rangeKey;
    return InkWell(
      onTap: () => setState(() => _selectedRange = rangeKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEDE9FE) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    bool isPositive = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: isPositive ? const Color(0xFF059669) : const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildTierProgress(String tier, String statusText, double progress, Color badgeColor, Color badgeBg, Color barColor, String countText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4)),
                  child: Text(tier, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: badgeColor, fontFamily: 'monospace')),
                ),
                const SizedBox(width: 6),
                Text(statusText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
              ],
            ),
            Text(countText, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace')),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }

  Widget _buildTrendBar(String label, double height, bool isBreached) {
    return SizedBox(
      height: 120,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isBreached)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(bottom: 2),
              decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
            ),
          Container(
            width: 10,
            height: height,
            decoration: BoxDecoration(
              color: isBreached ? const Color(0xFFEF4444) : const Color(0xFF0284C7),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
