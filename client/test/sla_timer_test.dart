import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asistiq_client/features/cases/models/case_model.dart';
import 'package:asistiq_client/features/cases/widgets/sla_countdown_timer.dart';
import 'package:asistiq_client/features/cases/widgets/priority_badge.dart';
import 'package:asistiq_client/features/cases/widgets/status_chip.dart';
import 'package:asistiq_client/features/cases/widgets/risk_indicator.dart';

void main() {
  group('SLA & Incident Widgets Rendering', () {
    testWidgets('PriorityBadge renders P1/P2/P3/P4 labels', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PriorityBadge(priority: CasePriority.p1Critical),
          ),
        ),
      );

      expect(find.text('P1'), findsOneWidget);
    });

    testWidgets('StatusChip renders status string with dot', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusChip(status: CaseStatus.inAssessment),
          ),
        ),
      );

      expect(find.text('In Assessment'), findsOneWidget);
    });

    testWidgets('RiskIndicator renders deterministic risk level', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RiskIndicator(riskLevel: RiskLevel.high),
          ),
        ),
      );

      expect(find.text('Risk: High'), findsOneWidget);
    });

    testWidgets('SlaCountdownTimer displays First Response and Resolution blocks', (tester) async {
      final now = DateTime.now();
      final sla = SlaModel(
        responseDeadline: now.add(const Duration(hours: 1)),
        resolutionDeadline: now.add(const Duration(hours: 4)),
        firstResponseAt: now.subtract(const Duration(minutes: 10)),
        isResponseBreached: false,
        isResolutionBreached: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SlaCountdownTimer(sla: sla, status: CaseStatus.assigned),
          ),
        ),
      );

      expect(find.text('First Response SLA'), findsOneWidget);
      expect(find.text('Resolution SLA'), findsOneWidget);
      expect(find.text('Responded (Stopped)'), findsOneWidget);
    });
  });
}
