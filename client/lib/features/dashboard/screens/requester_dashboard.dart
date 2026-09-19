import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/spacing.dart';
import '../../auth/state/auth_notifier.dart';
import '../../cases/models/case_model.dart';
import '../../cases/state/case_list_notifier.dart';
import '../../cases/widgets/priority_badge.dart';
import '../../cases/widgets/status_chip.dart';

class RequesterDashboard extends ConsumerStatefulWidget {
  const RequesterDashboard({super.key});

  @override
  ConsumerState<RequesterDashboard> createState() => _RequesterDashboardState();
}

class _RequesterDashboardState extends ConsumerState<RequesterDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(caseListNotifierProvider.notifier).fetchCases();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(caseListNotifierProvider);
    final notifier = ref.read(caseListNotifierProvider.notifier);
    final user = ref.watch(authNotifierProvider).user;

    final openCases = state.cases.where((c) => c.status.isOpen).toList();
    final closedCases = state.cases.where((c) => !c.status.isOpen).toList();
    final p1Count = openCases.where((c) => c.priority == CasePriority.p1Critical).length;
    final otherCount = openCases.length - p1Count;

    final screenWidth = MediaQuery.of(context).size.width;

    return RefreshIndicator(
      onRefresh: () => notifier.fetchCases(),
      child: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth < 768 ? AppSpacing.base : AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        children: [
          // 1. Clean Nordic Welcome Hero Banner Card (Solid Accent, Zero Slope)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Color(0xFF4F46E5), width: 5),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 620;
                  return isNarrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeroHeader(user),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => context.go('/cases/new'),
                                icon: const Icon(Icons.bolt, size: 16),
                                label: const Text('+ Report Incident', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: _buildHeroHeader(user)),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: () => context.go('/cases/new'),
                              icon: const Icon(Icons.bolt, size: 16),
                              label: const Text('+ Report Incident', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                            ),
                          ],
                        );
                },
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 2. Stitch Bento Metric Cards (Responsive Grid)
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 580;
              return isWide
                  ? Row(
                      children: [
                        Expanded(child: _buildActiveWorkspacesCard(openCases, p1Count, otherCount)),
                        const SizedBox(width: AppSpacing.base),
                        Expanded(child: _buildResolvedClosedCard(closedCases)),
                      ],
                    )
                  : Column(
                      children: [
                        _buildActiveWorkspacesCard(openCases, p1Count, otherCount),
                        const SizedBox(height: AppSpacing.base),
                        _buildResolvedClosedCard(closedCases),
                      ],
                    );
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // 3. Active Incidents List Section Header
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Your Active Incidents',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${openCases.length}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Sorted by: Urgency Descending', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  SizedBox(width: 4),
                  Icon(Icons.swap_vert, size: 14, color: Color(0xFF64748B)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // 4. Active Incident Cards
          if (openCases.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 44, color: Color(0xFF10B981)),
                    SizedBox(height: AppSpacing.sm),
                    Text('No active incidents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                    SizedBox(height: 4),
                    Text('All systems are functioning normally.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            ...openCases.map((c) => _buildStitchIncidentCard(context, c)),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(dynamic user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: const Text(
                'SELF-SERVICE HUB',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4338CA),
                  letterSpacing: 0.6,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Tier-1 Requester Node',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'JetBrains Mono'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Employee Helpdesk Portal',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            Text(
              'Welcome back, ${user?.fullName ?? "Alice Requester"}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
            ),
            const Text('/', style: TextStyle(color: Color(0xFFCBD5E1))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'Finance Department',
                style: TextStyle(fontSize: 10, fontFamily: 'JetBrains Mono', color: Color(0xFF4338CA), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveWorkspacesCard(List<CaseModel> openCases, int p1Count, int otherCount) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
              const Text(
                'ACTIVE WORKSPACES',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.pending_actions, size: 16, color: Color(0xFF4F46E5)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${openCases.length}',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -1),
              ),
              const SizedBox(width: 8),
              const Text(
                'Under Investigation',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFFE4E6)),
                ),
                child: Text(
                  '$p1Count P1 Critical',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFBE123C), fontFamily: 'JetBrains Mono'),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFEF3C7)),
                ),
                child: Text(
                  '$otherCount Active Normal',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309), fontFamily: 'JetBrains Mono'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResolvedClosedCard(List<CaseModel> closedCases) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
              const Text(
                'RESOLVED / CLOSED',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.verified, size: 16, color: Color(0xFF0F766E)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${closedCases.length}',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -1),
              ),
              const SizedBox(width: 8),
              const Text(
                'Resolved',
                style: TextStyle(fontSize: 12, color: Color(0xFF0F766E), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Text('3.2 hrs', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E), fontFamily: 'JetBrains Mono')),
              Text('avg resolution', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
              Text('100%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E), fontFamily: 'JetBrains Mono')),
              Text('CSAT', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStitchIncidentCard(BuildContext context, CaseModel c) {
    final isP1 = c.priority == CasePriority.p1Critical;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isP1 ? const Color(0xFFFFE4E6) : const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: isP1 ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
              width: 4,
            ),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: Text(
                    c.referenceNumber,
                    style: const TextStyle(fontSize: 11, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                  ),
                ),
                PriorityBadge(priority: c.priority),
                StatusChip(status: c.status),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      'SLA Target: ${isP1 ? "15m / 4h" : "4h / 72h"}',
                      style: const TextStyle(fontSize: 11, fontFamily: 'JetBrains Mono', color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            Text(
              c.title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            Text(
              c.description,
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFC7D2FE)),
                        ),
                        child: const Icon(Icons.support_agent, size: 14, color: Color(0xFF4338CA)),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LATEST OPERATIONAL SIGNAL',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.6),
                          ),
                          Text(
                            'Assigned to ${c.assignedOperatorName ?? "Tier 1 Support Queue"} • Telemetry healthy',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => context.go('/cases/${c.id}'),
                    icon: const Icon(Icons.arrow_forward, size: 12, color: Color(0xFF4F46E5)),
                    label: const Text('View Case', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
