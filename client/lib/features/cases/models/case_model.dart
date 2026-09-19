import '../../auth/models/user_model.dart';

enum CaseStatus {
  draft,
  newCase,
  inAssessment,
  assigned,
  awaitingRequester,
  awaitingApproval,
  resolved,
  closed,
  cancelled;

  static CaseStatus fromString(String status) {
    final s = status.toLowerCase().replaceAll('_', ' ').trim();
    switch (s) {
      case 'draft':
        return CaseStatus.draft;
      case 'new':
        return CaseStatus.newCase;
      case 'in assessment':
        return CaseStatus.inAssessment;
      case 'assigned':
        return CaseStatus.assigned;
      case 'awaiting requester':
        return CaseStatus.awaitingRequester;
      case 'awaiting approval':
        return CaseStatus.awaitingApproval;
      case 'pending / external dependency':
      case 'pending':
        return CaseStatus.inAssessment;
      case 'resolved':
        return CaseStatus.resolved;
      case 'closed':
        return CaseStatus.closed;
      case 'cancelled':
        return CaseStatus.cancelled;
      default:
        return CaseStatus.newCase;
    }
  }

  String toDisplayString() {
    switch (this) {
      case CaseStatus.draft:
        return 'Draft';
      case CaseStatus.newCase:
        return 'New';
      case CaseStatus.inAssessment:
        return 'In Assessment';
      case CaseStatus.assigned:
        return 'Assigned';
      case CaseStatus.awaitingRequester:
        return 'Awaiting Requester';
      case CaseStatus.awaitingApproval:
        return 'Awaiting Approval';
      case CaseStatus.resolved:
        return 'Resolved';
      case CaseStatus.closed:
        return 'Closed';
      case CaseStatus.cancelled:
        return 'Cancelled';
    }
  }

  String toBackendString() {
    switch (this) {
      case CaseStatus.draft:
        return 'Draft';
      case CaseStatus.newCase:
        return 'New';
      case CaseStatus.inAssessment:
        return 'In Assessment';
      case CaseStatus.assigned:
        return 'Assigned';
      case CaseStatus.awaitingRequester:
        return 'Awaiting Requester';
      case CaseStatus.awaitingApproval:
        return 'Awaiting Approval';
      case CaseStatus.resolved:
        return 'Resolved';
      case CaseStatus.closed:
        return 'Closed';
      case CaseStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isOpen =>
      this != CaseStatus.closed && this != CaseStatus.cancelled && this != CaseStatus.resolved;
}

enum CasePriority {
  p1Critical,
  p2High,
  p3Medium,
  p4Low;

  static CasePriority fromString(String priority) {
    final upper = priority.toUpperCase();
    if (upper.contains('P1') || upper.contains('CRITICAL')) {
      return CasePriority.p1Critical;
    }
    if (upper.contains('P2') || upper.contains('HIGH')) {
      return CasePriority.p2High;
    }
    if (upper.contains('P3') || upper.contains('MEDIUM')) {
      return CasePriority.p3Medium;
    }
    return CasePriority.p4Low;
  }

  String get code {
    switch (this) {
      case CasePriority.p1Critical:
        return 'P1';
      case CasePriority.p2High:
        return 'P2';
      case CasePriority.p3Medium:
        return 'P3';
      case CasePriority.p4Low:
        return 'P4';
    }
  }

  String toBackendString() {
    switch (this) {
      case CasePriority.p1Critical:
        return 'P1 — Critical';
      case CasePriority.p2High:
        return 'P2 — High';
      case CasePriority.p3Medium:
        return 'P3 — Medium';
      case CasePriority.p4Low:
        return 'P4 — Low';
    }
  }

  String toDisplayString() {
    switch (this) {
      case CasePriority.p1Critical:
        return 'P1 - Critical';
      case CasePriority.p2High:
        return 'P2 - High';
      case CasePriority.p3Medium:
        return 'P3 - Medium';
      case CasePriority.p4Low:
        return 'P4 - Low';
    }
  }
}

enum RiskLevel {
  low,
  moderate,
  high,
  critical;

  static RiskLevel fromString(String risk) {
    switch (risk.toUpperCase()) {
      case 'HIGH':
        return RiskLevel.high;
      case 'CRITICAL':
        return RiskLevel.critical;
      case 'MODERATE':
      case 'MEDIUM':
        return RiskLevel.moderate;
      case 'LOW':
      default:
        return RiskLevel.low;
    }
  }

  String toDisplayString() {
    switch (this) {
      case RiskLevel.critical:
        return 'Critical';
      case RiskLevel.high:
        return 'High';
      case RiskLevel.moderate:
        return 'Moderate';
      case RiskLevel.low:
        return 'Low';
    }
  }
}

DateTime? parseUtcDateTime(dynamic value) {
  if (value == null) return null;
  final str = value.toString().trim();
  if (str.isEmpty) return null;
  if (!str.endsWith('Z') && !str.contains('+') && !RegExp(r'-\d{2}:\d{2}$').hasMatch(str)) {
    return DateTime.tryParse('${str}Z')?.toLocal();
  }
  return DateTime.tryParse(str)?.toLocal();
}

class SlaModel {
  final DateTime? responseDeadline;
  final DateTime? resolutionDeadline;
  final DateTime? firstResponseAt;
  final DateTime? resolvedAt;
  final bool isResponseBreached;
  final bool isResolutionBreached;

  const SlaModel({
    this.responseDeadline,
    this.resolutionDeadline,
    this.firstResponseAt,
    this.resolvedAt,
    this.isResponseBreached = false,
    this.isResolutionBreached = false,
  });

  factory SlaModel.fromJson(Map<String, dynamic> json) {
    final respRaw = json['target_response_at'] ?? json['response_deadline'];
    final resRaw = json['target_resolve_at'] ?? json['resolution_deadline'];
    return SlaModel(
      responseDeadline: parseUtcDateTime(respRaw),
      resolutionDeadline: parseUtcDateTime(resRaw),
      firstResponseAt: parseUtcDateTime(json['first_responded_at']),
      resolvedAt: parseUtcDateTime(json['resolved_at']),
      isResponseBreached: json['response_breached'] as bool? ?? false,
      isResolutionBreached: json['resolve_breached'] as bool? ?? (json['resolution_breached'] as bool? ?? false),
    );
  }
}

class CaseMessageModel {
  final String id;
  final String caseId;
  final String senderId;
  final String senderName;
  final UserRole senderRole;
  final String body;
  final bool isInternal;
  final bool isAiGenerated;
  final DateTime createdAt;

  const CaseMessageModel({
    required this.id,
    required this.caseId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.body,
    required this.isInternal,
    required this.isAiGenerated,
    required this.createdAt,
  });

  factory CaseMessageModel.fromJson(Map<String, dynamic> json) {
    return CaseMessageModel(
      id: json['id']?.toString() ?? '',
      caseId: json['case_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? json['user_id']?.toString() ?? '',
      senderName: json['sender_name'] as String? ?? json['author_name'] as String? ?? 'Agent',
      senderRole: UserRole.fromString(json['sender_role'] as String? ?? 'operator'),
      body: json['content'] as String? ?? json['body'] as String? ?? '',
      isInternal: json['visibility'] == 'internal_only' || (json['is_internal'] as bool? ?? false),
      isAiGenerated: json['ai_generated'] as bool? ?? false,
      createdAt: parseUtcDateTime(json['created_at']) ?? DateTime.now(),
    );
  }
}

class AttachmentModel {
  final String id;
  final String caseId;
  final String fileName;
  final int fileSizeBytes;
  final String mimeType;
  final String? downloadUrl;
  final DateTime createdAt;

  const AttachmentModel({
    required this.id,
    required this.caseId,
    required this.fileName,
    required this.fileSizeBytes,
    required this.mimeType,
    this.downloadUrl,
    required this.createdAt,
  });

  factory AttachmentModel.fromJson(Map<String, dynamic> json) {
    return AttachmentModel(
      id: json['id']?.toString() ?? '',
      caseId: json['case_id']?.toString() ?? '',
      fileName: json['file_name'] as String? ?? 'file',
      fileSizeBytes: json['file_size_bytes'] as int? ?? json['file_size'] as int? ?? 0,
      mimeType: json['content_type'] as String? ?? json['mime_type'] as String? ?? 'application/octet-stream',
      downloadUrl: json['download_url'] as String?,
      createdAt: parseUtcDateTime(json['created_at']) ?? DateTime.now(),
    );
  }
}

class CaseModel {
  final String id;
  final String referenceNumber;
  final String title;
  final String description;
  final String category;
  final CasePriority priority;
  final CaseStatus status;
  final RiskLevel riskLevel;
  final int version;
  final String requesterId;
  final String? requesterName;
  final String? assignedOperatorId;
  final String? assignedOperatorName;
  final String? assignedTeamId;
  final String? assignedTeamName;
  final SlaModel? sla;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? closedAt;

  const CaseModel({
    required this.id,
    required this.referenceNumber,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    required this.riskLevel,
    required this.version,
    required this.requesterId,
    this.requesterName,
    this.assignedOperatorId,
    this.assignedOperatorName,
    this.assignedTeamId,
    this.assignedTeamName,
    this.sla,
    required this.createdAt,
    required this.updatedAt,
    this.closedAt,
  });

  factory CaseModel.fromJson(Map<String, dynamic> json) {
    return CaseModel(
      id: json['id']?.toString() ?? '',
      referenceNumber: json['reference_number'] as String? ?? json['ref_no'] as String? ?? 'INC-PENDING',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      priority: CasePriority.fromString(json['priority'] as String? ?? 'P4'),
      status: CaseStatus.fromString(json['status'] as String? ?? 'new'),
      riskLevel: RiskLevel.fromString(json['risk_level'] as String? ?? 'LOW'),
      version: json['version'] as int? ?? 1,
      requesterId: json['requester_id']?.toString() ?? '',
      requesterName: json['requester_name'] as String?,
      assignedOperatorId: json['owner_id']?.toString() ?? json['assigned_to_user_id']?.toString() ?? json['assigned_operator_id']?.toString(),
      assignedOperatorName: json['assigned_operator_name'] as String? ?? json['assignee_name'] as String?,
      assignedTeamId: json['team_id']?.toString() ?? json['assigned_team_id']?.toString(),
      assignedTeamName: json['assigned_team_name'] as String?,
      sla: json['sla'] != null ? SlaModel.fromJson(json['sla'] as Map<String, dynamic>) : null,
      createdAt: parseUtcDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: parseUtcDateTime(json['updated_at']) ?? DateTime.now(),
      closedAt: parseUtcDateTime(json['closed_at']),
    );
  }

  bool get canReopen {
    if (status != CaseStatus.closed || closedAt == null) return false;
    final now = DateTime.now();
    return now.difference(closedAt!).inDays <= 7;
  }
}
