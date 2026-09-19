import '../../cases/models/case_model.dart';

class AITriageModel {
  final String category;
  final CasePriority priority;
  final double confidenceScore;
  final String reasoning;
  final List<String> missingInfo;

  const AITriageModel({
    required this.category,
    required this.priority,
    required this.confidenceScore,
    required this.reasoning,
    required this.missingInfo,
  });

  factory AITriageModel.fromJson(Map<String, dynamic> json) {
    return AITriageModel(
      category: json['suggested_category'] as String? ?? json['category'] as String? ?? 'General',
      priority: CasePriority.fromString(json['suggested_priority'] as String? ?? json['priority'] as String? ?? 'P3'),
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.85,
      reasoning: (json['supporting_factors'] as List<dynamic>?)?.join(', ') ?? json['reasoning'] as String? ?? '',
      missingInfo: (json['missing_info'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class CaseSummaryModel {
  final String summary;
  final List<String> keyPoints;
  final DateTime generatedAt;

  const CaseSummaryModel({
    required this.summary,
    required this.keyPoints,
    required this.generatedAt,
  });

  factory CaseSummaryModel.fromJson(Map<String, dynamic> json) {
    return CaseSummaryModel(
      summary: json['summary_text'] as String? ?? json['summary'] as String? ?? '',
      keyPoints: (json['key_points'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      generatedAt: json['generated_at'] != null || json['updated_at'] != null
          ? DateTime.tryParse((json['generated_at'] ?? json['updated_at']).toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

enum DraftType {
  infoRequest,
  progressUpdate,
  resolution,
  escalationSummary;

  static DraftType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'info_request':
        return DraftType.infoRequest;
      case 'progress_update':
        return DraftType.progressUpdate;
      case 'resolution':
        return DraftType.resolution;
      case 'escalation_summary':
      default:
        return DraftType.escalationSummary;
    }
  }

  String toBackendString() {
    switch (this) {
      case DraftType.infoRequest:
        return 'info_request';
      case DraftType.progressUpdate:
        return 'progress_update';
      case DraftType.resolution:
        return 'resolution';
      case DraftType.escalationSummary:
        return 'escalation_summary';
    }
  }

  String toDisplayString() {
    switch (this) {
      case DraftType.infoRequest:
        return 'Information Request';
      case DraftType.progressUpdate:
        return 'Progress Update';
      case DraftType.resolution:
        return 'Resolution Notice';
      case DraftType.escalationSummary:
        return 'Escalation Summary';
    }
  }
}

class CommunicationDraftModel {
  final String id;
  final String caseId;
  final DraftType draftType;
  final String draftText;
  final bool isApproved;
  final bool isSent;
  final DateTime createdAt;

  const CommunicationDraftModel({
    required this.id,
    required this.caseId,
    required this.draftType,
    required this.draftText,
    required this.isApproved,
    required this.isSent,
    required this.createdAt,
  });

  factory CommunicationDraftModel.fromJson(Map<String, dynamic> json) {
    return CommunicationDraftModel(
      id: json['id']?.toString() ?? '',
      caseId: json['case_id']?.toString() ?? '',
      draftType: DraftType.fromString(json['draft_type'] as String? ?? 'info_request'),
      draftText: json['body'] as String? ?? json['draft_text'] as String? ?? json['content'] as String? ?? '',
      isApproved: json['is_approved'] as bool? ?? false,
      isSent: json['status'] == 'sent' || (json['is_sent'] as bool? ?? false),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
    );
  }

  CommunicationDraftModel copyWith({
    String? id,
    String? caseId,
    DraftType? draftType,
    String? draftText,
    bool? isApproved,
    bool? isSent,
    DateTime? createdAt,
  }) {
    return CommunicationDraftModel(
      id: id ?? this.id,
      caseId: caseId ?? this.caseId,
      draftType: draftType ?? this.draftType,
      draftText: draftText ?? this.draftText,
      isApproved: isApproved ?? this.isApproved,
      isSent: isSent ?? this.isSent,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
