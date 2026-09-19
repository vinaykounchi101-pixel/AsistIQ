import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/spacing.dart';
import '../models/case_model.dart';
import '../services/case_api_service.dart';
import '../state/case_list_notifier.dart';

class CreateCaseScreen extends ConsumerStatefulWidget {
  const CreateCaseScreen({super.key});

  @override
  ConsumerState<CreateCaseScreen> createState() => _CreateCaseScreenState();
}

class _CreateCaseScreenState extends ConsumerState<CreateCaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _affectedServiceController = TextEditingController();
  String _selectedCategory = 'Software';
  CasePriority _selectedPriority = CasePriority.p3Medium;
  bool _isSubmitting = false;
  String? _errorMessage;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Software', 'icon': Icons.apps, 'desc': 'Applications, SaaS, OS issues'},
    {'name': 'Hardware', 'icon': Icons.laptop_mac, 'desc': 'Laptops, docks, monitors, peripherals'},
    {'name': 'Network', 'icon': Icons.wifi, 'desc': 'VPN, WiFi, switches, DNS'},
    {'name': 'Access & Identity', 'icon': Icons.lock_outline, 'desc': 'SSO, MFA, password reset, permissions'},
    {'name': 'Security', 'icon': Icons.security, 'desc': 'Phishing, malware, incident triage'},
    {'name': 'Database', 'icon': Icons.storage, 'desc': 'Postgres, queries, data access'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _affectedServiceController.dispose();
    super.dispose();
  }

  Future<void> _submitCase() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final apiService = ref.read(caseApiServiceProvider);
      final newCase = await apiService.createCase(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        priority: _selectedPriority,
      );

      // Refresh case list provider
      ref.read(caseListNotifierProvider.notifier).fetchCases();

      if (mounted) {
        context.go('/cases/${newCase.id}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => context.go('/cases'),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.add_circle, color: Color(0xFF4F46E5), size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'Submit New Incident / Workspace',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Form Card
                  Container(
                    padding: EdgeInsets.all(MediaQuery.of(context).size.width < 600 ? 16 : 28),
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
                        const Text('1. SELECT INCIDENT CATEGORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontFamily: 'monospace')),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final w = constraints.maxWidth;
                            final int crossAxisCount = w >= 700 ? 3 : (w >= 460 ? 2 : 1);
                            final itemWidth = crossAxisCount == 1
                                ? w
                                : (w - (crossAxisCount - 1) * 12) / crossAxisCount;

                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: _categories.map((cat) {
                                final isSelected = _selectedCategory == cat['name'];
                                return InkWell(
                                  onTap: () => setState(() => _selectedCategory = cat['name'] as String),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: itemWidth,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFEDE9FE) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isSelected ? Colors.white : const Color(0xFFEDE9FE),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(cat['icon'] as IconData, color: const Color(0xFF4F46E5), size: 18),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(cat['name'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF0F172A))),
                                              const SizedBox(height: 2),
                                              Text(cat['desc'] as String, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)), maxLines: 2, overflow: TextOverflow.ellipsis),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        const Divider(color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 18),

                        const Text('2. INCIDENT DETAILS & SUMMARY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontFamily: 'monospace')),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _titleController,
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Incident Subject / Title *',
                            hintText: 'e.g., Cannot connect to VPN gateway after certificate refresh',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Subject is required' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _affectedServiceController,
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Affected Service / Infrastructure (Optional)',
                            hintText: 'e.g., Cisco AnyConnect, Okta SSO, AWS Postgres',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 4,
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Detailed Problem Description *',
                            hintText: 'Provide error codes, steps to reproduce, impact on operations, or urgency details...',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Description is required' : null,
                        ),
                        const SizedBox(height: 24),
                        const Divider(color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 18),

                        const Text('3. SEVERITY & SLA TIER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontFamily: 'monospace')),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final w = constraints.maxWidth;
                            final int crossAxisCount = w >= 640 ? 4 : (w >= 400 ? 2 : 1);
                            final pillWidth = crossAxisCount == 1
                                ? w
                                : (w - (crossAxisCount - 1) * 12) / crossAxisCount;

                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _buildPriorityPill(CasePriority.p1Critical, 'P1 Critical', 'Total outage / <15m SLA', const Color(0xFFDC2626), const Color(0xFFFEF2F2), pillWidth),
                                _buildPriorityPill(CasePriority.p2High, 'P2 High', 'Degraded / <1h SLA', const Color(0xFFC2410C), const Color(0xFFFFF7ED), pillWidth),
                                _buildPriorityPill(CasePriority.p3Medium, 'P3 Medium', 'Standard / <4h SLA', const Color(0xFF0369A1), const Color(0xFFF0F9FF), pillWidth),
                                _buildPriorityPill(CasePriority.p4Low, 'P4 Low', 'Minor / <8h SLA', const Color(0xFF64748B), const Color(0xFFF8FAFC), pillWidth),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Live AI Copilot Triage Preview Card (Clean Nordic Solid Tone)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDDD6FE)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE9FE),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFC7D2FE)),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Color(0xFF4F46E5), size: 18),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Finny AI Real-Time Triage Engine Active', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B))),
                              SizedBox(height: 4),
                              Text('Upon submission, Gemini 1.5 Flash will automatically analyze error patterns, calculate 24/7 SLA milestones, and generate initial troubleshooting drafts for operators.', style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.4)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Action Buttons
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 480;
                      final cancelBtn = OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                        onPressed: () => context.go('/cases'),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                      );

                      final submitBtn = ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          elevation: 0,
                        ),
                        onPressed: _isSubmitting ? null : _submitCase,
                        icon: _isSubmitting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.bolt, size: 18),
                        label: Text(
                          _isSubmitting ? 'Submitting & Triaging...' : 'Submit Incident & Auto-Triage',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      );

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            submitBtn,
                            const SizedBox(height: 10),
                            cancelBtn,
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          cancelBtn,
                          const SizedBox(width: 12),
                          submitBtn,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityPill(CasePriority priority, String label, String subtext, Color color, Color bg, double width) {
    final isSelected = _selectedPriority == priority;
    return InkWell(
      onTap: () => setState(() => _selectedPriority = priority),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? bg : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(subtext, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
