import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/spacing.dart';
import '../../auth/state/auth_notifier.dart';
import '../models/case_model.dart';
import '../state/case_list_notifier.dart';
import '../widgets/priority_badge.dart';
import '../widgets/risk_indicator.dart';
import '../widgets/status_chip.dart';

class CasesScreen extends ConsumerStatefulWidget {
  const CasesScreen({super.key});

  @override
  ConsumerState<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends ConsumerState<CasesScreen> {
  String _searchQuery = '';
  String _activeTab = 'all'; // 'all', 'open', 'at_risk', 'breached', 'closed'
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(caseListNotifierProvider.notifier).fetchCases();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(caseListNotifierProvider);
    final notifier = ref.read(caseListNotifierProvider.notifier);
    final user = ref.watch(authNotifierProvider).user;

    var filteredCases = state.cases.where((c) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesRef = c.referenceNumber.toLowerCase().contains(query);
        final matchesTitle = c.title.toLowerCase().contains(query);
        final matchesCategory = c.category.toLowerCase().contains(query);
        if (!matchesRef && !matchesTitle && !matchesCategory) return false;
      }

      if (_selectedCategory != null && _selectedCategory != 'All' && c.category != _selectedCategory) {
        return false;
      }

      switch (_activeTab) {
        case 'open':
          return c.status.isOpen;
        case 'at_risk':
          return c.riskLevel == RiskLevel.high || c.riskLevel == RiskLevel.critical;
        case 'breached':
          return (c.sla?.isResponseBreached ?? false) || (c.sla?.isResolutionBreached ?? false);
        case 'closed':
          return c.status == CaseStatus.closed || c.status == CaseStatus.resolved;
        case 'all':
        default:
          return true;
      }
    }).toList();

    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () => notifier.fetchCases(),
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth < 768 ? AppSpacing.base : 24,
            vertical: 20,
          ),
          children: [
            // Top Header & Actions (Responsive Wrap)
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Text('OPERATIONS', style: TextStyle(color: Color(0xFF0284C7), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                        Text(' / ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                        Text('CASES & WORKSPACES', style: TextStyle(color: Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Incident Workspaces & Directory',
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
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onPressed: () => notifier.fetchCases(),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        elevation: 0,
                      ),
                      onPressed: () => context.go('/cases/new'),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New Incident', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search & Filter Bar (Responsive)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 560;
                  final searchBox = Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: (val) => setState(() => _searchQuery = val),
                            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5),
                            decoration: const InputDecoration(
                              hintText: 'Search by reference #, title, category, or service...',
                              hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );

                  final dropdown = Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory ?? 'All Categories',
                        items: ['All Categories', 'Software', 'Hardware', 'Network', 'Access & Identity', 'Security', 'Database']
                            .map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)))))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedCategory = (val == 'All Categories') ? null : val;
                          });
                        },
                      ),
                    ),
                  );

                  return isNarrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            searchBox,
                            const SizedBox(height: 10),
                            dropdown,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: searchBox),
                            const SizedBox(width: 12),
                            dropdown,
                          ],
                        );
                },
              ),
            ),
            const SizedBox(height: 18),

            // Tab Navigation (Horizontally Scrollable, zero clipping)
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTab('all', 'All Incidents (${state.cases.length})'),
                    _buildTab('open', 'Open Active (${state.cases.where((c) => c.status.isOpen).length})'),
                    _buildTab('at_risk', 'At-Risk SLA (${state.cases.where((c) => c.riskLevel == RiskLevel.high || c.riskLevel == RiskLevel.critical).length})'),
                    _buildTab('breached', 'Breached (${state.cases.where((c) => (c.sla?.isResponseBreached ?? false) || (c.sla?.isResolutionBreached ?? false)).length})'),
                    _buildTab('closed', 'Closed & Resolved (${state.cases.where((c) => c.status == CaseStatus.closed || c.status == CaseStatus.resolved).length})'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Case List Cards
            if (filteredCases.isEmpty)
              Container(
                padding: const EdgeInsets.all(48),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: Color(0xFF94A3B8)),
                      SizedBox(height: 12),
                      Text('No incidents found in this filter view.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      SizedBox(height: 4),
                      Text('Try adjusting your search query or switching tabs.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              )
            else
              ...filteredCases.map((c) => _buildCaseCard(context, c)),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String key, String title) {
    final isSelected = _activeTab == key;
    return InkWell(
      onTap: () => setState(() => _activeTab = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildCaseCard(BuildContext context, CaseModel c) {
    final isBreached = (c.sla?.isResponseBreached ?? false) || (c.sla?.isResolutionBreached ?? false);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isBreached ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
          width: isBreached ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/cases/${c.id}'),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 640;

                final refBadge = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    c.referenceNumber,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                );

                final details = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text('Category: ${c.category}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        Text('Team: ${c.assignedTeamName ?? "Tier 1 Support"}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        Text(
                          'Assignee: ${c.assignedOperatorName ?? "Unassigned"}',
                          style: TextStyle(
                            fontSize: 12,
                            color: c.assignedOperatorName == null ? const Color(0xFFDC2626) : const Color(0xFF059669),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (c.sla?.resolutionDeadline != null)
                          Text('SLA Target: ${c.sla!.resolutionDeadline!.toLocal().toString().substring(11, 16)} UTC', style: const TextStyle(fontSize: 12, color: Color(0xFF4F46E5), fontFamily: 'monospace')),
                      ],
                    ),
                  ],
                );

                return isNarrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              refBadge,
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  StatusChip(status: c.status),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 18),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          details,
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              PriorityBadge(priority: c.priority),
                              RiskIndicator(riskLevel: c.riskLevel),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          refBadge,
                          const SizedBox(width: 14),
                          Expanded(child: details),
                          const SizedBox(width: 14),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RiskIndicator(riskLevel: c.riskLevel),
                              const SizedBox(width: 8),
                              PriorityBadge(priority: c.priority),
                              const SizedBox(width: 8),
                              StatusChip(status: c.status),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 20),
                            ],
                          ),
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
