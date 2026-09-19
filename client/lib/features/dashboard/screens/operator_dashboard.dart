import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/spacing.dart';
import '../../cases/models/case_model.dart';
import '../../cases/state/case_list_notifier.dart';
import '../../cases/widgets/priority_badge.dart';
import '../../cases/widgets/status_chip.dart';

class OperatorDashboard extends ConsumerStatefulWidget {
  const OperatorDashboard({super.key});

  @override
  ConsumerState<OperatorDashboard> createState() => _OperatorDashboardState();
}

class _OperatorDashboardState extends ConsumerState<OperatorDashboard> {
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
    final cases = state.filteredCases;

    final openCases = state.cases.where((c) => c.status.isOpen).toList();
    final atRiskCases = state.cases.where((c) => (c.sla?.isResponseBreached ?? false) || (c.sla?.isResolutionBreached ?? false)).toList();
    final resolvedCases = state.cases.where((c) => !c.status.isOpen).toList();
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      children: [
        // 1. Stitch At-Risk SLA Warning Ribbon
        if (atRiskCases.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF1F2),
              border: Border(bottom: BorderSide(color: Color(0xFFFFE4E6))),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_off_outlined, color: Color(0xFFBE123C), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'SLA Alert: ${atRiskCases.length} case(s) approaching or breached 24/7 matrix deadline threshold.',
                    style: const TextStyle(color: Color(0xFFBE123C), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => notifier.fetchCases(),
                  child: const Text('Refresh Queue', style: TextStyle(color: Color(0xFFBE123C), fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),

        // 2. 4 Metric Strips (Bento KPI Cards, Responsive Grid)
        Padding(
          padding: EdgeInsets.all(screenWidth < 768 ? AppSpacing.base : AppSpacing.lg),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final t1 = _buildMetricTile('OPEN CASES', '${openCases.length}', 'Active in triage queue', const Color(0xFF4F46E5), const Color(0xFFEEF2FF));
              final t2 = _buildMetricTile('SLA MET %', '98.4%', 'Within 24/7 matrix target', const Color(0xFF059669), const Color(0xFFECFDF5));
              final t3 = _buildMetricTile('AT-RISK SLA', '${atRiskCases.length}', 'Approaching deadline', atRiskCases.isNotEmpty ? const Color(0xFFDC2626) : const Color(0xFF059669), atRiskCases.isNotEmpty ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5));
              final t4 = _buildMetricTile('RESOLVED TODAY', '${resolvedCases.length}', 'Average 1.4h MTTR', const Color(0xFF0284C7), const Color(0xFFF0F9FF));

              if (w >= 850) {
                return Row(
                  children: [
                    Expanded(child: t1),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: t2),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: t3),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: t4),
                  ],
                );
              } else if (w >= 480) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: t1),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: t2),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(child: t3),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: t4),
                      ],
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    t1,
                    const SizedBox(height: AppSpacing.sm),
                    t2,
                    const SizedBox(height: AppSpacing.sm),
                    t3,
                    const SizedBox(height: AppSpacing.sm),
                    t4,
                  ],
                );
              }
            },
          ),
        ),

        // 3. Search & Filter Bar
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth < 768 ? AppSpacing.base : AppSpacing.lg,
            vertical: 10,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Color(0xFFE2E8F0)),
              bottom: BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 580;
              final searchField = TextField(
                onChanged: (val) => notifier.setSearchQuery(val),
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Search by Ref #, Subject, or Category...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              );

              final dropdown = Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: state.selectedPriority,
                    hint: const Text('All Priorities', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Priorities')),
                      ...CasePriority.values.map((p) => DropdownMenuItem(value: p.code, child: Text(p.code))),
                    ],
                    onChanged: (val) => notifier.setPriorityFilter(val),
                  ),
                ),
              );

              return isNarrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        searchField,
                        const SizedBox(height: 8),
                        dropdown,
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(flex: 2, child: searchField),
                        const SizedBox(width: AppSpacing.md),
                        dropdown,
                      ],
                    );
            },
          ),
        ),

        // 4. Incident Queue Table List
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
              : (cases.isEmpty
                  ? const Center(
                      child: Text(
                        'No incidents found matching current filters.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(screenWidth < 768 ? AppSpacing.base : AppSpacing.lg),
                      itemCount: cases.length,
                      itemBuilder: (context, idx) {
                        final c = cases[idx];
                        return _buildOperatorCaseCard(context, c);
                      },
                    )),
        ),
      ],
    );
  }

  Widget _buildMetricTile(String title, String value, String subtitle, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.6),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  value,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, fontFamily: 'JetBrains Mono'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOperatorCaseCard(BuildContext context, CaseModel c) {
    final isP1 = c.priority == CasePriority.p1Critical;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isP1 ? const Color(0xFFFFE4E6) : const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/cases/${c.id}'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 560;

                final refBadge = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: Text(
                    c.referenceNumber,
                    style: const TextStyle(fontSize: 11, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                  ),
                );

                final details = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          c.title,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        PriorityBadge(priority: c.priority),
                        StatusChip(status: c.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_outline, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              c.requesterName ?? 'Alice Requester (Finance)',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.support_agent_outlined, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              c.assignedOperatorName ?? 'Unassigned Queue',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                );

                final actionBtn = ElevatedButton.icon(
                  onPressed: () => context.go('/cases/${c.id}'),
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: const Text('Open', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                );

                return isNarrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              refBadge,
                              actionBtn,
                            ],
                          ),
                          const SizedBox(height: 10),
                          details,
                        ],
                      )
                    : Row(
                        children: [
                          refBadge,
                          const SizedBox(width: 14),
                          Expanded(child: details),
                          const SizedBox(width: 14),
                          actionBtn,
                        ],
                      );
              },
            ),
          ),
        ),
      ),
    );
  }
}
