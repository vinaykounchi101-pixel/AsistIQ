import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/spacing.dart';
import '../../cases/services/case_api_service.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  bool _isRunningSweep = false;
  String? _sweepMessage;

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
        final message = 'Manual sweep successful: $audited incidents audited, $breaches SLA breaches & $escalations escalations evaluated.';

        setState(() {
          _isRunningSweep = false;
          _sweepMessage = message;
        });

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
      backgroundColor: const Color(0xFFF8FAFC),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        children: [
          // Breadcrumbs & Top Action Bar
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('GOVERNANCE', style: TextStyle(color: Color(0xFF0284C7), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                      const Text('/', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      const Text('SYSTEM HEALTH & SWEEPS', style: TextStyle(color: Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                      const Text('/', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Text('ALL SERVICES NOMINAL', style: TextStyle(color: Color(0xFF059669), fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'System Governance & Infrastructure Diagnostics',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF4F46E5),
                  side: const BorderSide(color: Color(0xFFC7D2FE)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  elevation: 0,
                ),
                onPressed: _isRunningSweep ? null : _handleManualSweep,
                icon: _isRunningSweep
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)))
                    : const Icon(Icons.bolt, size: 18, color: Color(0xFF4F46E5)),
                label: Text(
                  _isRunningSweep ? 'Auditing Incidents...' : 'Run SLA Sweep',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

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

          // Service Health Bento Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final int crossAxisCount = width >= 1000 ? 4 : (width >= 560 ? 2 : 1);
              final cardWidth = crossAxisCount == 1
                  ? width
                  : (width - (crossAxisCount - 1) * 16) / crossAxisCount;

              final bentos = [
                _buildHealthBento(
                  serviceName: 'PostgreSQL Database',
                  status: 'CONNECTED',
                  details: 'v16.0 | Connection Pool Healthy',
                  icon: Icons.storage_outlined,
                  isHealthy: true,
                ),
                _buildHealthBento(
                  serviceName: 'APScheduler Engine',
                  status: 'ACTIVE',
                  details: '24/7 SLA Sweep Job (5-min interval)',
                  icon: Icons.schedule_outlined,
                  isHealthy: true,
                ),
                _buildHealthBento(
                  serviceName: 'Finny AI Copilot',
                  status: 'READY',
                  details: 'Gemini 1.5 Flash • Minglish Context Enabled',
                  icon: Icons.auto_awesome,
                  isHealthy: true,
                ),
                _buildHealthBento(
                  serviceName: 'Security & RBAC',
                  status: 'ENFORCED',
                  details: '5 Roles • Optimistic Locking Active',
                  icon: Icons.security_outlined,
                  isHealthy: true,
                ),
              ];

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: bentos.map((b) => SizedBox(width: cardWidth, child: b)).toList(),
              );
            },
          ),
          const SizedBox(height: 24),

          // 24/7 SLA Matrix Configuration
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(color: Color(0x050F172A), blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('24/7 SLA Matrix (SRS §4.2 Rule Set)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          SizedBox(height: 2),
                          Text('Wall-clock continuous SLA thresholds across all incident severities', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Text('STRICT ENFORCEMENT', style: TextStyle(color: Color(0xFF334155), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _buildSlaRow('P1 Critical', '15 Minutes', '4 Hours', 'Auto-Escalate to Tier 2 Lead', const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
                _buildSlaRow('P2 High', '1 Hour', '8 Hours', 'Reassign to Next Available L2', const Color(0xFFC2410C), const Color(0xFFFFF7ED)),
                _buildSlaRow('P3 Medium', '4 Hours', '72 Hours', 'Alert Manager at 80% Window', const Color(0xFF0369A1), const Color(0xFFF0F9FF)),
                _buildSlaRow('P4 Low', '24 Hours', '120 Hours', 'Standard Queue Ingest', const Color(0xFF64748B), const Color(0xFFF8FAFC)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Security Policies & Audit Trail
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(color: Color(0x050F172A), blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.policy_outlined, color: Color(0xFF4F46E5), size: 20),
                    SizedBox(width: 8),
                    Text('Enterprise Governance & Security Protocols', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('• 5-Role Granular RBAC (Requester, Operator, TeamLead, Manager, SystemAdmin) enforced at API gateway.', style: TextStyle(fontSize: 13, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                const Text('• Optimistic Concurrency Control (OCC) with version locking prevents lost updates during concurrent operator triage.', style: TextStyle(fontSize: 13, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                const Text('• Complete immutable audit trail logging for all status transitions, reassignments, and manual overrides.', style: TextStyle(fontSize: 13, color: Color(0xFF334155))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthBento({
    required String serviceName,
    required String status,
    required String details,
    required IconData icon,
    required bool isHealthy,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x050F172A), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isHealthy ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isHealthy ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                ),
                child: Icon(icon, color: isHealthy ? const Color(0xFF059669) : const Color(0xFFDC2626), size: 18),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isHealthy ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isHealthy ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: isHealthy ? const Color(0xFF10B981) : const Color(0xFFEF4444), shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isHealthy ? const Color(0xFF059669) : const Color(0xFFDC2626), fontFamily: 'monospace')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(serviceName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(details, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildSlaRow(String priority, String response, String resolution, String escalation, Color badgeColor, Color badgeBg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 560;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4)),
                      child: Text(priority, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor, fontFamily: 'monospace')),
                    ),
                    Text('Resp: $response', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Resolution: $resolution', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 4),
                Text(escalation, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
              ],
            );
          }
          return Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4)),
                child: Text(priority, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor, fontFamily: 'monospace')),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Text('Response: $response', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
              ),
              Expanded(
                flex: 2,
                child: Text('Resolution: $resolution', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
              ),
              Expanded(
                flex: 3,
                child: Text(escalation, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
              ),
            ],
          );
        },
      ),
    );
  }
}
