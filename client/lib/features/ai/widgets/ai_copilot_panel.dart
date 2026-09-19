import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/spacing.dart';
import '../../cases/state/case_detail_notifier.dart';
import '../../cases/widgets/priority_badge.dart';
import '../models/ai_model.dart';

class AiCopilotPanel extends ConsumerStatefulWidget {
  final String caseId;
  final double? width;
  final bool showBorder;

  const AiCopilotPanel({
    super.key,
    required this.caseId,
    this.width = 380,
    this.showBorder = true,
  });

  @override
  ConsumerState<AiCopilotPanel> createState() => _AiCopilotPanelState();
}

class _AiCopilotPanelState extends ConsumerState<AiCopilotPanel> {
  final _draftTextController = TextEditingController();
  DraftType _selectedDraftType = DraftType.infoRequest;

  @override
  void dispose() {
    _draftTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(caseDetailNotifierProvider(widget.caseId), (prev, next) {
      if (next.activeDraft != null && next.activeDraft != prev?.activeDraft) {
        _draftTextController.text = next.activeDraft!.draftText;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('AI Draft updated by Gemini!', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: Color(0xFF4F46E5),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
      if (next.caseSummary != null && next.caseSummary != prev?.caseSummary) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Case Summary updated by Gemini!', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
      if (next.aiTriage != null && next.aiTriage != prev?.aiTriage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Intake Triage completed by Gemini!', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(next.errorMessage!)),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    final state = ref.watch(caseDetailNotifierProvider(widget.caseId));
    final notifier = ref.read(caseDetailNotifierProvider(widget.caseId).notifier);
    final triage = state.aiTriage;
    final summary = state.caseSummary;
    final draft = state.activeDraft;

    if (draft != null && _draftTextController.text.isEmpty) {
      _draftTextController.text = draft.draftText;
    }

    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: widget.showBorder ? const Border(left: BorderSide(color: Color(0xFFE2E8F0))) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Color(0xFF4F46E5), size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Finny AI Copilot',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text('Gemini 1.5 Flash • Minglish Aware', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                if (state.isAiLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                  ),
              ],
            ),
          ),

          // Body Scroll
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                // 1. Live Intake Triage Card
                Container(
                  padding: const EdgeInsets.all(16),
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
                            'Intake AI Triage',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                          ),
                          if (state.isAiLoading)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF64748B)),
                              onPressed: () => notifier.fetchAiTriage(),
                              tooltip: 'Re-run Triage',
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (state.isAiLoading && triage == null) ...[
                        const Row(
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF4F46E5)),
                            ),
                            SizedBox(width: 8),
                            Text('Analyzing case with Gemini...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      ] else if (triage != null) ...[
                        Row(
                          children: [
                            Text(
                              'Category: ${triage.category}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: Text(
                                '${(triage.confidenceScore * 100).toInt()}% Confident',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF059669), fontFamily: 'monospace'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Priority: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            PriorityBadge(priority: triage.priority),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            triage.reasoning,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.4),
                          ),
                        ),
                      ] else ...[
                        const Text('No triage analysis yet.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Automated Case Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
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
                            'Case Summary & Timeline',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                          ),
                          if (state.isAiLoading)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF64748B)),
                              onPressed: () => notifier.fetchAiSummary(),
                              tooltip: 'Regenerate Summary',
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (state.isAiLoading && summary == null) ...[
                        const Row(
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF4F46E5)),
                            ),
                            SizedBox(width: 8),
                            Text('Generating summary with Gemini...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      ] else if (summary != null) ...[
                        Text(
                          summary.summary,
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Generated: ${summary.generatedAt.toLocal().toString().substring(11, 16)} UTC',
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
                        ),
                      ] else ...[
                        const Text('Click refresh to generate AI narrative summary.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. AI Draft Reply Assistant
                Container(
                  padding: const EdgeInsets.all(16),
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
                      const Text(
                        'Automated Response Draft',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<DraftType>(
                        value: _selectedDraftType,
                        decoration: InputDecoration(
                          labelText: 'Draft Intent',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: DraftType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.toDisplayString(), style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedDraftType = val);
                            notifier.createAiDraft(val);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _draftTextController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'AI suggested reply draft will appear here...',
                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          contentPadding: const EdgeInsets.all(10),
                        ),
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF475569),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _draftTextController.text));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Draft copied to clipboard')),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 14),
                            label: const Text('Copy Draft', style: TextStyle(fontSize: 11.5)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              elevation: 0,
                            ),
                            onPressed: state.isAiLoading ? null : () => notifier.createAiDraft(_selectedDraftType),
                            icon: state.isAiLoading
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.auto_awesome, size: 14),
                            label: Text(
                              state.isAiLoading ? 'Generating...' : 'Regenerate',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
