import 'package:flutter_test/flutter_test.dart';
import 'package:asistiq_client/features/cases/models/case_model.dart';
import 'package:asistiq_client/features/ai/models/ai_model.dart';

void main() {
  group('Case & AI Models Serialization & Logic', () {
    test('CaseModel parses backend JSON accurately with 7-day reopen check', () {
      final now = DateTime.now();
      final caseJson = {
        'id': 'c101',
        'reference_number': 'INC-2026-000001',
        'title': 'VPN Authentication Failure',
        'description': 'Cannot connect via Cisco AnyConnect',
        'category': 'Network',
        'priority': 'P1',
        'status': 'closed',
        'risk_level': 'CRITICAL',
        'version': 3,
        'requester_id': 'u1',
        'requester_name': 'Alice Smith',
        'assigned_operator_id': 'u2',
        'assigned_operator_name': 'Bob Agent',
        'created_at': now.subtract(const Duration(days: 2)).toIso8601String(),
        'updated_at': now.subtract(const Duration(hours: 4)).toIso8601String(),
        'closed_at': now.subtract(const Duration(days: 3)).toIso8601String(),
        'sla': {
          'response_deadline': now.add(const Duration(minutes: 15)).toIso8601String(),
          'resolution_deadline': now.add(const Duration(hours: 4)).toIso8601String(),
          'first_responded_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
          'response_breached': false,
          'resolution_breached': false,
        },
      };

      final c = CaseModel.fromJson(caseJson);
      expect(c.id, 'c101');
      expect(c.referenceNumber, 'INC-2026-000001');
      expect(c.priority, CasePriority.p1Critical);
      expect(c.status, CaseStatus.closed);
      expect(c.riskLevel, RiskLevel.critical);
      expect(c.version, 3);
      expect(c.canReopen, true); // Closed 3 days ago <= 7 days
      expect(c.sla?.firstResponseAt != null, true);
    });

    test('CaseModel correctly disallows reopening after 7 days', () {
      final oldDate = DateTime.now().subtract(const Duration(days: 10));
      final caseModel = CaseModel(
        id: 'c102',
        referenceNumber: 'INC-2026-000002',
        title: 'Old ticket',
        description: 'Past window',
        category: 'Hardware',
        priority: CasePriority.p4Low,
        status: CaseStatus.closed,
        riskLevel: RiskLevel.low,
        version: 1,
        requesterId: 'u1',
        createdAt: oldDate,
        updatedAt: oldDate,
        closedAt: oldDate,
      );

      expect(caseModel.canReopen, false);
    });

    test('AITriageModel and CommunicationDraftModel parse correctly', () {
      final triageJson = {
        'category': 'Access & Identity',
        'priority': 'P2',
        'confidence_score': 0.92,
        'reasoning': 'User locked out of ERP system',
        'missing_info': ['Employee ID', 'Office location'],
      };

      final triage = AITriageModel.fromJson(triageJson);
      expect(triage.category, 'Access & Identity');
      expect(triage.priority, CasePriority.p2High);
      expect(triage.confidenceScore, 0.92);
      expect(triage.missingInfo.length, 2);

      final draftJson = {
        'id': 'd1',
        'case_id': 'c101',
        'draft_type': 'info_request',
        'draft_text': 'Please provide your employee badge ID.',
        'is_approved': false,
        'status': 'draft',
      };

      final draft = CommunicationDraftModel.fromJson(draftJson);
      expect(draft.draftType, DraftType.infoRequest);
      expect(draft.isSent, false);
      expect(draft.draftText, 'Please provide your employee badge ID.');
    });
  });
}
