import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/api/api_client.dart';

final reportApiServiceProvider = Provider<ReportApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ReportApiService(apiClient);
});

class ExecutiveSummaryModel {
  final int totalIncidents;
  final double slaComplianceRate;
  final double meanTimeToRespondMinutes;
  final double meanTimeToResolveHours;
  final String? aiNarrativeBriefing;

  ExecutiveSummaryModel({
    required this.totalIncidents,
    required this.slaComplianceRate,
    required this.meanTimeToRespondMinutes,
    required this.meanTimeToResolveHours,
    this.aiNarrativeBriefing,
  });

  factory ExecutiveSummaryModel.fromJson(Map<String, dynamic> json) {
    return ExecutiveSummaryModel(
      totalIncidents: json['total_incidents'] as int? ?? 0,
      slaComplianceRate: (json['sla_compliance_rate'] as num?)?.toDouble() ?? 0.0,
      meanTimeToRespondMinutes: (json['mean_time_to_respond_minutes'] as num?)?.toDouble() ?? 0.0,
      meanTimeToResolveHours: (json['mean_time_to_resolve_hours'] as num?)?.toDouble() ?? 0.0,
      aiNarrativeBriefing: json['ai_narrative_briefing'] as String?,
    );
  }
}

class SlaComplianceTierModel {
  final String tier;
  final int totalCases;
  final double responseMetPercentage;
  final double resolutionMetPercentage;

  SlaComplianceTierModel({
    required this.tier,
    required this.totalCases,
    required this.responseMetPercentage,
    required this.resolutionMetPercentage,
  });

  factory SlaComplianceTierModel.fromJson(Map<String, dynamic> json) {
    return SlaComplianceTierModel(
      tier: json['tier'] as String? ?? '',
      totalCases: json['total_cases'] as int? ?? 0,
      responseMetPercentage: (json['response_met_percentage'] as num?)?.toDouble() ?? 0.0,
      resolutionMetPercentage: (json['resolution_met_percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ReportApiService {
  final ApiClient _apiClient;

  ReportApiService(this._apiClient);

  Future<ExecutiveSummaryModel> getExecutiveSummary() async {
    final response = await _apiClient.get('/api/v1/reports/summary');
    return ExecutiveSummaryModel.fromJson(response as Map<String, dynamic>);
  }

  Future<List<SlaComplianceTierModel>> getSlaCompliance() async {
    final response = await _apiClient.get('/api/v1/reports/sla-compliance');
    if (response is Map<String, dynamic> && response['tiers'] is List) {
      return (response['tiers'] as List)
          .map((item) => SlaComplianceTierModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } else if (response is List) {
      return response.map((item) => SlaComplianceTierModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }
}
