import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/spacing.dart';
import '../../ai/widgets/ai_copilot_panel.dart';
import '../../auth/state/auth_notifier.dart';
import '../models/case_model.dart';
import '../state/case_detail_notifier.dart';
import '../widgets/priority_badge.dart';
import '../widgets/risk_indicator.dart';
import '../widgets/sla_countdown_timer.dart';
import '../widgets/status_chip.dart';

class CaseDetailScreen extends ConsumerStatefulWidget {
  final String caseId;

  const CaseDetailScreen({super.key, required this.caseId});

  @override
  ConsumerState<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends ConsumerState<CaseDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _messageController = TextEditingController();
  bool _isInternalNote = false;
  bool _isPostingMessage = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handlePostMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPostingMessage = true);
    final notifier = ref.read(caseDetailNotifierProvider(widget.caseId).notifier);
    final isInternal = _isInternalNote;
    final success = await notifier.postMessage(
      content: text,
      isInternal: isInternal,
    );

    if (mounted) {
      setState(() => _isPostingMessage = false);
      if (success) {
        _messageController.clear();
        // Switch tab to the relevant view so user immediately sees their message
        _tabController.animateTo(isInternal ? 1 : 0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  isInternal
                      ? 'Internal staff note posted successfully!'
                      : 'Public reply sent to requester!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: isInternal ? const Color(0xFFD97706) : const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Failed to post message. Please check backend connection.'),
              ],
            ),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showResolveDialog(BuildContext context, CaseModel caseModel) {
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Resolve Incident', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Document the resolution root cause and actions taken before resolving this ticket.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 3,
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5),
              decoration: InputDecoration(
                labelText: 'Resolution Summary *',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final notifier = ref.read(caseDetailNotifierProvider(widget.caseId).notifier);
              final ok = await notifier.transitionStatus(CaseStatus.resolved, resolutionNotes: notesController.text.trim());
              if (ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ticket resolved successfully!'),
                    backgroundColor: Color(0xFF059669),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
  }

  List<CaseStatus> _getAllowedTransitions(CaseStatus current) {
    switch (current) {
      case CaseStatus.draft:
        return [CaseStatus.newCase];
      case CaseStatus.newCase:
        return [CaseStatus.inAssessment, CaseStatus.cancelled];
      case CaseStatus.inAssessment:
        return [CaseStatus.assigned];
      case CaseStatus.assigned:
        return [CaseStatus.awaitingRequester, CaseStatus.awaitingApproval, CaseStatus.resolved, CaseStatus.cancelled];
      case CaseStatus.awaitingRequester:
      case CaseStatus.awaitingApproval:
        return [CaseStatus.assigned];
      case CaseStatus.resolved:
        return [CaseStatus.closed, CaseStatus.assigned];
      case CaseStatus.closed:
      case CaseStatus.cancelled:
        return [];
    }
  }

  Widget _buildStatusActionButton(BuildContext context, CaseModel caseModel, CaseDetailNotifier notifier) {
    final allowed = _getAllowedTransitions(caseModel.status);

    if (caseModel.status == CaseStatus.closed && caseModel.canReopen) {
      return OutlinedButton.icon(
        icon: const Icon(Icons.replay, size: 14, color: Color(0xFF4F46E5)),
        label: const Text('Reopen', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          side: const BorderSide(color: Color(0xFFC7D2FE)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: () => _showReopenDialog(context, caseModel),
      );
    }

    if (allowed.isEmpty) return const SizedBox.shrink();

    String primaryLabel;
    IconData primaryIcon;
    CaseStatus primaryTarget = allowed.first;
    Color primaryColor = const Color(0xFF4F46E5);

    switch (caseModel.status) {
      case CaseStatus.newCase:
        primaryLabel = 'Start Assessment';
        primaryIcon = Icons.assignment_outlined;
        primaryTarget = CaseStatus.inAssessment;
        primaryColor = const Color(0xFF2563EB);
        break;
      case CaseStatus.inAssessment:
        primaryLabel = 'Assign / Work';
        primaryIcon = Icons.play_arrow_rounded;
        primaryTarget = CaseStatus.assigned;
        primaryColor = const Color(0xFF4F46E5);
        break;
      case CaseStatus.assigned:
        primaryLabel = 'Resolve';
        primaryIcon = Icons.check_circle_outline;
        primaryTarget = CaseStatus.resolved;
        primaryColor = const Color(0xFF059669);
        break;
      case CaseStatus.awaitingRequester:
      case CaseStatus.awaitingApproval:
        primaryLabel = 'Resume Working';
        primaryIcon = Icons.play_arrow_rounded;
        primaryTarget = CaseStatus.assigned;
        primaryColor = const Color(0xFF4F46E5);
        break;
      case CaseStatus.resolved:
        primaryLabel = 'Close Ticket';
        primaryIcon = Icons.lock_outline;
        primaryTarget = CaseStatus.closed;
        primaryColor = const Color(0xFF475569);
        break;
      default:
        primaryLabel = 'Update Status';
        primaryIcon = Icons.arrow_forward;
        primaryColor = const Color(0xFF4F46E5);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          icon: Icon(primaryIcon, size: 14),
          label: Text(primaryLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            elevation: 0,
          ),
          onPressed: () async {
            if (primaryTarget == CaseStatus.resolved) {
              _showResolveDialog(context, caseModel);
            } else {
              final ok = await notifier.transitionStatus(primaryTarget);
              if (ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Status updated to ${primaryTarget.toDisplayString()}!'),
                    backgroundColor: const Color(0xFF059669),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          },
        ),
        if (allowed.length > 1) ...[
          const SizedBox(width: 4),
          PopupMenuButton<CaseStatus>(
            icon: const Icon(Icons.more_vert, size: 16, color: Color(0xFF64748B)),
            tooltip: 'More status transitions',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onSelected: (target) async {
              if (target == CaseStatus.resolved) {
                _showResolveDialog(context, caseModel);
              } else {
                final ok = await notifier.transitionStatus(target);
                if (ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Status transitioned to ${target.toDisplayString()}!'),
                      backgroundColor: const Color(0xFF059669),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            itemBuilder: (ctx) => allowed.map((status) {
              return PopupMenuItem<CaseStatus>(
                value: status,
                child: Row(
                  children: [
                    const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 8),
                    Text('Move to ${status.toDisplayString()}', style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  void _showReopenDialog(BuildContext context, CaseModel caseModel) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reopen Incident (7-Day Policy)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This ticket was closed within the last 7 days. Providing a reason will reset status to Assigned and restart the 24/7 SLA resolution clock.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5),
              decoration: InputDecoration(
                labelText: 'Reason for Reopening *',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                final notifier = ref.read(caseDetailNotifierProvider(widget.caseId).notifier);
                await notifier.reopen(reasonController.text.trim());
              }
            },
            child: const Text('Confirm Reopen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(caseDetailNotifierProvider(widget.caseId));
    final notifier = ref.read(caseDetailNotifierProvider(widget.caseId).notifier);
    final authUser = ref.watch(authNotifierProvider).user;
    final isStaff = authUser?.role.isStaff ?? false;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1150;
    final isCompact = screenWidth < 768;

    if (state.isLoading && state.activeCase == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
      );
    }

    final caseModel = state.activeCase;
    if (caseModel == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)), onPressed: () => context.go('/cases')),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
              const SizedBox(height: 16),
              Text(state.errorMessage ?? 'Incident not found', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () => notifier.loadCaseData(), child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => context.go('/cases'),
        ),
        title: isCompact
            ? Text(
                caseModel.referenceNumber,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      caseModel.referenceNumber,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      caseModel.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ),
                ],
              ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isCompact) ...[
                  RiskIndicator(riskLevel: caseModel.riskLevel),
                  const SizedBox(width: 6),
                  PriorityBadge(priority: caseModel.priority),
                  const SizedBox(width: 6),
                ],
                StatusChip(status: caseModel.status),
                if (!isCompact && isStaff) ...[
                  const SizedBox(width: 8),
                  _buildStatusActionButton(context, caseModel, notifier),
                ],
                if (!isDesktop && isStaff) ...[
                  const SizedBox(width: 6),
                  Builder(
                    builder: (ctx) => Tooltip(
                      message: 'Open Finny AI Copilot',
                      child: IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE9FE),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFC7D2FE)),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Color(0xFF4F46E5), size: 16),
                        ),
                        onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      endDrawer: (!isDesktop && isStaff)
          ? Drawer(
              width: screenWidth < 450 ? screenWidth * 0.92 : 380,
              child: SafeArea(
                child: AiCopilotPanel(
                  caseId: widget.caseId,
                  width: null,
                  showBorder: false,
                ),
              ),
            )
          : null,
      body: Row(
        children: [
          // Main Incident Timeline Area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Optimistic Stale Version Conflict Banner
                if (state.isConflictStale)
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: const Color(0xFFFEF2F2),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Conflict: Another operator updated this ticket. Please refresh to load the latest changes.',
                            style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: () => notifier.loadCaseData(),
                          child: const Text('Reload Case'),
                        ),
                      ],
                    ),
                  ),

                // Top SLA & Metadata Header Banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  caseModel.title,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    Text('Category: ${caseModel.category}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                    Text('Team: ${caseModel.assignedTeamName ?? "Tier 1 Support"}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                    Text('Requester: ${caseModel.requesterName ?? "Requester"}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                    Text('Created: ${DateFormat.yMMMd().format(caseModel.createdAt)}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                  ],
                                ),
                                if (isCompact) ...[
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      RiskIndicator(riskLevel: caseModel.riskLevel),
                                      PriorityBadge(priority: caseModel.priority),
                                      if (isStaff)
                                        _buildStatusActionButton(context, caseModel, notifier),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (caseModel.canReopen)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD97706),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              onPressed: () => _showReopenDialog(context, caseModel),
                              icon: const Icon(Icons.replay, size: 16),
                              label: const Text('Reopen Ticket', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      if (caseModel.description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'INCIDENT DESCRIPTION',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                caseModel.description,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // SLA Countdown Timer Bar
                      SlaCountdownTimer(sla: caseModel.sla, status: caseModel.status),
                    ],
                  ),
                ),

                // Tab Bar (Public Messages vs Internal Notes)
                if (isStaff)
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF4F46E5),
                      unselectedLabelColor: const Color(0xFF64748B),
                      indicatorColor: const Color(0xFF4F46E5),
                      tabs: const [
                        Tab(text: 'Public Communication'),
                        Tab(text: 'Staff Internal Notes'),
                      ],
                    ),
                  ),

                // Messages Timeline List
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMessageList(state.publicMessages),
                      if (isStaff)
                        _buildMessageList(state.internalNotes)
                      else
                        const Center(child: Text('Internal notes restricted to support staff')),
                    ],
                  ),
                ),

                // Bottom Message Compose Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Column(
                    children: [
                      if (isStaff)
                        Row(
                          children: [
                            Checkbox(
                              value: _isInternalNote,
                              onChanged: (val) => setState(() => _isInternalNote = val ?? false),
                              activeColor: const Color(0xFF4F46E5),
                            ),
                            const Text(
                              'Internal Staff Note (Hidden from requester)',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              maxLines: null,
                              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5),
                              decoration: InputDecoration(
                                hintText: _isInternalNote
                                    ? 'Write an internal investigation note...'
                                    : 'Reply to requester...',
                                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              elevation: 0,
                            ),
                            onPressed: _isPostingMessage ? null : _handlePostMessage,
                            icon: _isPostingMessage
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.send, size: 16),
                            label: const Text('Send', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Right AI Copilot Panel (Desktop View for Staff only)
          if (isDesktop && isStaff)
            AiCopilotPanel(caseId: widget.caseId),
        ],
      ),
    );
  }

  Widget _buildMessageList(List<CaseMessageModel> messages) {
    if (messages.isEmpty) {
      return const Center(
        child: Text('No messages in this stream yet.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: messages.length,
      itemBuilder: (context, idx) {
        final msg = messages[idx];
        final isInternal = msg.isInternal;
        final senderName = msg.senderName;
        final content = msg.body;
        final timeStr = DateFormat.jm().format(msg.createdAt);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isInternal ? const Color(0xFFFFFBEB) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isInternal ? const Color(0xFFFEF3C7) : const Color(0xFFE2E8F0),
            ),
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
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isInternal ? const Color(0xFFFEF3C7) : const Color(0xFFEDE9FE),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            senderName.isNotEmpty ? senderName[0].toUpperCase() : 'U',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isInternal ? const Color(0xFFB45309) : const Color(0xFF4F46E5)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(senderName, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      if (isInternal) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('INTERNAL NOTE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309), fontFamily: 'monospace')),
                        ),
                      ],
                    ],
                  ),
                  Text(timeStr, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                ],
              ),
              const SizedBox(height: 10),
              Text(content, style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.4)),
            ],
          ),
        );
      },
    );
  }
}
