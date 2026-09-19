import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/api/api_client.dart';
import '../models/case_model.dart';
import '../../ai/models/ai_model.dart';

final caseApiServiceProvider = Provider<CaseApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CaseApiService(apiClient);
});

class CaseApiService {
  final ApiClient _apiClient;

  CaseApiService(this._apiClient);

  Future<List<CaseModel>> listCases({
    String? status,
    String? priority,
    String? assignedTo,
    int page = 1,
    int pageSize = 50,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (priority != null && priority.isNotEmpty) params['priority'] = priority;
    if (assignedTo != null && assignedTo.isNotEmpty) params['assigned_to'] = assignedTo;

    final response = await _apiClient.get('/api/v1/cases/', queryParameters: params);
    if (response is List) {
      return response.map((item) => CaseModel.fromJson(item as Map<String, dynamic>)).toList();
    } else if (response is Map && response['items'] is List) {
      return (response['items'] as List)
          .map((item) => CaseModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<CaseModel> getCaseDetail(String caseId) async {
    final response = await _apiClient.get('/api/v1/cases/$caseId');
    return CaseModel.fromJson(response as Map<String, dynamic>);
  }

  Future<CaseModel> createCase({
    required String title,
    required String description,
    required String category,
    required CasePriority priority,
    String? serviceId,
  }) async {
    final payload = {
      'title': title,
      'description': description,
      'type': 'Incident',
      'priority': priority.toBackendString(),
      if (serviceId != null) 'service_id': serviceId,
    };

    final response = await _apiClient.post('/api/v1/cases/', data: payload);
    return CaseModel.fromJson(response as Map<String, dynamic>);
  }

  Future<CaseModel> updateCaseStatus({
    required String caseId,
    required CaseStatus newStatus,
    required int currentVersion,
    String? resolutionNotes,
  }) async {
    final payload = {
      'target_status': newStatus.toBackendString(),
      'version': currentVersion,
      if (resolutionNotes != null) 'reason': resolutionNotes,
    };

    final response = await _apiClient.post('/api/v1/cases/$caseId/transition', data: payload);
    return CaseModel.fromJson(response as Map<String, dynamic>);
  }

  Future<CaseModel> reopenCase({
    required String caseId,
    required int currentVersion,
    required String reason,
  }) async {
    final payload = {
      'target_status': 'Assigned',
      'reason': reason,
      'version': currentVersion,
    };

    final response = await _apiClient.post('/api/v1/cases/$caseId/transition', data: payload);
    return CaseModel.fromJson(response as Map<String, dynamic>);
  }

  Future<List<CaseMessageModel>> listMessages(String caseId) async {
    final response = await _apiClient.get('/api/v1/cases/$caseId/messages');
    if (response is Map<String, dynamic> && response['items'] is List) {
      return (response['items'] as List)
          .map((item) => CaseMessageModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } else if (response is List) {
      return response.map((item) => CaseMessageModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<CaseMessageModel> addMessage({
    required String caseId,
    required String body,
    bool isInternal = false,
  }) async {
    final payload = {
      'body': body,
      'visibility': isInternal ? 'internal_only' : 'requester_visible',
    };

    final response = await _apiClient.post('/api/v1/cases/$caseId/messages', data: payload);
    return CaseMessageModel.fromJson(response as Map<String, dynamic>);
  }

  Future<AttachmentModel> uploadAttachment({
    required String caseId,
    required String fileName,
    required Uint8List fileBytes,
    required String mimeType,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
    });

    final response = await _apiClient.post('/api/v1/cases/$caseId/attachments', data: formData);
    return AttachmentModel.fromJson(response as Map<String, dynamic>);
  }

  Future<List<AttachmentModel>> listAttachments(String caseId) async {
    final response = await _apiClient.get('/api/v1/cases/$caseId/attachments');
    if (response is List) {
      return response.map((item) => AttachmentModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  // --- AI Copilot Endpoints ---
  Future<AITriageModel> triggerAITriage(String caseId) async {
    final response = await _apiClient.post('/api/v1/cases/$caseId/ai/triage');
    return AITriageModel.fromJson(response as Map<String, dynamic>);
  }

  Future<CaseSummaryModel> generateCaseSummary(String caseId) async {
    final response = await _apiClient.post('/api/v1/cases/$caseId/ai/summarize');
    return CaseSummaryModel.fromJson(response as Map<String, dynamic>);
  }

  Future<CommunicationDraftModel> generateDraft({
    required String caseId,
    required DraftType draftType,
  }) async {
    final payload = {'draft_type': draftType.toBackendString()};
    final response = await _apiClient.post('/api/v1/cases/$caseId/ai/drafts', data: payload);
    return CommunicationDraftModel.fromJson(response as Map<String, dynamic>);
  }

  Future<CaseMessageModel> sendApprovedDraft({
    required String caseId,
    required String draftId,
    required String finalContent,
  }) async {
    final payload = {'final_content': finalContent};
    final response = await _apiClient.post('/api/v1/cases/$caseId/ai/drafts/$draftId/send', data: payload);
    return CaseMessageModel.fromJson(response as Map<String, dynamic>);
  }

  // --- Sweeps & Manual Admin Trigger ---
  Future<Map<String, dynamic>> triggerManualSweep() async {
    final response = await _apiClient.post('/api/v1/admin/sweeps/run');
    return (response is Map<String, dynamic>) ? response : {};
  }
}
