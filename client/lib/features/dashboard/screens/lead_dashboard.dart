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

class LeadDashboard extends ConsumerStatefulWidget {
  const LeadDashboard({super.key});

  @override
  ConsumerState<LeadDashboard> createState() => _LeadDashboardState();
}

class _LeadDashboardState extends ConsumerState<LeadDashboard> {
  String _activeTab = 'critical'; // 'critical', 'unassigned', 'pods'

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(caseListNotifierProvider);
    final notifier = ref.read(caseListNotifierProvider.notifier);

    final unassignedCases = state.cases.where((c) => c.assignedOperatorId == null && c.status.isOpen).toList();
    final criticalCases = state.cases.where((c) => c.riskLevel == RiskLevel.critical || c.priority == CasePriority.p1Critical).toList();
    final atRiskCases = state.cases.where((c) => c.riskLevel == RiskLevel.high || c.riskLevel == RiskLevel.critical).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () => notifier.fetchCases(),
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width < 768 ? AppSpacing.base : 24,
            vertical: 20,
          ),
          children: [
            // Top Breadcrumb & Title Bar
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
                        const Text('OPERATIONS', style: TextStyle(color: Color(0xFF0284C7), fontSize: 10.5, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                        const Text('/', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                        const Text('COMMAND CENTER', style: TextStyle(color: Color(0xFF6366F1), fontSize: 10.5, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                        const Text('/', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: const Text('LIVE SWARM ACTIVE', style: TextStyle(color: Color(0xFF059669), fontSize: 9.5, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Incident Command & Team Swarm',
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
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onPressed: () => notifier.fetchCases(),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Sync Queue', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () => context.go('/cases/new'),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Initiate Swarm Incident', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Bento Metric Cards (Nordic Calm Pastel, Responsive Grid)
            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final bento1 = _buildBentoMetric(
                  label: 'CRITICAL / P1 ESCALATIONS',
                  value: '${criticalCases.length}',
                  subtext: 'Immediate commander triage required',
                  icon: Icons.warning_amber_rounded,
                  accentColor: const Color(0xFFDC2626),
                  bgColor: const Color(0xFFFEF2F2),
                  borderColor: const Color(0xFFFECACA),
                );
                final bento2 = _buildBentoMetric(
                  label: 'UNASSIGNED TRIAGE POOL',
                  value: '${unassignedCases.length}',
                  subtext: 'Awaiting operator dispatch',
                  icon: Icons.inbox,
                  accentColor: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFFFBEB),
                  borderColor: const Color(0xFFFEF3C7),
                );
                final bento3 = _buildBentoMetric(
                  label: 'AT-RISK SLA TIMERS',
                  value: '${atRiskCases.length}',
                  subtext: '<30 mins to response breach',
                  icon: Icons.timer,
                  accentColor: const Color(0xFF4F46E5),
                  bgColor: const Color(0xFFF5F3FF),
                  borderColor: const Color(0xFFDDD6FE),
                );
                final bento4 = _buildBentoMetric(
                  label: 'ACTIVE POD READINESS',
                  value: '4/4',
                  subtext: 'Tier 1, Infra, SecOps, DBA online',
                  icon: Icons.groups,
                  accentColor: const Color(0xFF0D9488),
                  bgColor: const Color(0xFFF0FDFA),
                  borderColor: const Color(0xFFCCFBF1),
                );

                if (w >= 900) {
                  return Row(
                    children: [
                      Expanded(child: bento1),
                      const SizedBox(width: 14),
                      Expanded(child: bento2),
                      const SizedBox(width: 14),
                      Expanded(child: bento3),
                      const SizedBox(width: 14),
                      Expanded(child: bento4),
                    ],
                  );
                } else if (w >= 520) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: bento1),
                          const SizedBox(width: 14),
                          Expanded(child: bento2),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: bento3),
                          const SizedBox(width: 14),
                          Expanded(child: bento4),
                        ],
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      bento1,
                      const SizedBox(height: 12),
                      bento2,
                      const SizedBox(height: 12),
                      bento3,
                      const SizedBox(height: 12),
                      bento4,
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 28),

            // Filter Tabs Bar
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabButton('critical', 'Critical Escalation Watch (${criticalCases.length})', Icons.bolt),
                    _buildTabButton('unassigned', 'Unassigned Triage Queue (${unassignedCases.length})', Icons.assignment_ind),
                    _buildTabButton('pods', 'Team Swarm & Pod Workloads', Icons.schema_outlined),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Tab Content
            if (_activeTab == 'critical') ...[
              if (criticalCases.isEmpty)
                _buildEmptyCard('No critical escalations pending. All P1/P2 incidents are under control.')
              else
                ...criticalCases.map((c) => _buildCommandCaseCard(context, c, isCritical: true)),
            ] else if (_activeTab == 'unassigned') ...[
              if (unassignedCases.isEmpty)
                _buildEmptyCard('All active cases are assigned to support engineers.')
              else
                ...unassignedCases.map((c) => _buildCommandCaseCard(context, c, isCritical: false)),
            ] else ...[
              _buildPodWorkloadTable(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBentoMetric({
    required String label,
    required String value,
    required String subtext,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: accentColor,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtext, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildTabButton(String tabKey, String title, IconData icon) {
    final isSelected = _activeTab == tabKey;
    return InkWell(
      onTap: () => setState(() => _activeTab = tabKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandCaseCard(BuildContext context, CaseModel c, {required bool isCritical}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCritical ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
          width: isCritical ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x050F172A), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 650;

          final refAndTitle = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  c.referenceNumber,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text('Category: ${c.category}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        Text('Team: ${c.assignedTeamName ?? "Tier 1 Support"}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        Text('Assignee: ${c.assignedOperatorName ?? "Unassigned"}', style: TextStyle(fontSize: 12, color: c.assignedOperatorName == null ? const Color(0xFFDC2626) : const Color(0xFF059669), fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

          final badgesAndAction = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              RiskIndicator(riskLevel: c.riskLevel),
              PriorityBadge(priority: c.priority),
              StatusChip(status: c.status),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCritical ? const Color(0xFFDC2626) : const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  elevation: 0,
                ),
                onPressed: () => context.go('/cases/${c.id}'),
                child: const Text('Open Command', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              ),
            ],
          );

          return isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    refAndTitle,
                    const SizedBox(height: 12),
                    badgesAndAction,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: refAndTitle),
                    const SizedBox(width: 16),
                    badgesAndAction,
                  ],
                );
        },
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.check_circle_outline, size: 48, color: Color(0xFF10B981)),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _buildPodWorkloadTable() {
    return Container(
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
                    Text('Support Team & Swarm Workload Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    SizedBox(height: 2),
                    Text('Real-time throughput, resolution velocities, and SLA containment status', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Text('4 ACTIVE PODS', style: TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          _buildPodRow('Tier 1 Support', 'L1 Triage & Provisioning', '8 active', '54 resolved', '96.2%', '2.6h', 'Low Risk', const Color(0xFF059669), Icons.headset_mic),
          _buildPodRow('Network & Infrastructure', 'Core Transit & Edge VPN', '4 active', '28 resolved', '92.8%', '4.1h', 'Moderate Risk', const Color(0xFFD97706), Icons.router),
          _buildPodRow('Security Operations', 'SOC & Zero Trust Auditing', '3 active', '22 resolved', '100%', '1.8h', 'Low Risk', const Color(0xFF059669), Icons.security),
          _buildPodRow('Database Admin', 'Postgres Cluster & Redis Cache', '2 active', '18 resolved', '98.0%', '3.2h', 'Low Risk', const Color(0xFF059669), Icons.storage),
        ],
      ),
    );
  }

  Widget _buildPodRow(String title, String subtitle, String active, String resolved, String compliance, String mttr, String risk, Color riskColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 680;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Icon(icon, color: const Color(0xFF4F46E5), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: riskColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: riskColor.withOpacity(0.3)),
                      ),
                      child: Text(risk, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: riskColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Active: $active', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                    Text('Resolved: $resolved', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text('SLA: $compliance', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                    Text('MTTR: $mttr', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Icon(icon, color: const Color(0xFF4F46E5), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(active, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
              ),
              Expanded(
                flex: 2,
                child: Text(resolved, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              ),
              Expanded(
                flex: 2,
                child: Text(compliance, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
              ),
              Expanded(
                flex: 2,
                child: Text(mttr, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: riskColor.withOpacity(0.3)),
                ),
                child: Text(risk, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: riskColor)),
              ),
            ],
          );
        },
      ),
    );
  }
}
