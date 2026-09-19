import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/case_model.dart';
import '../services/case_api_service.dart';
import '../../ai/models/ai_model.dart';

class CaseDetailState {
  final CaseModel? activeCase;
  final List<CaseMessageModel> messages;
  final List<AttachmentModel> attachments;
  final AITriageModel? aiTriage;
  final CaseSummaryModel? caseSummary;
  final CommunicationDraftModel? activeDraft;
  final bool isLoading;
  final bool isAiLoading;
  final String? errorMessage;
  final bool isConflictStale;

  const CaseDetailState({
    this.activeCase,
    this.messages = const [],
    this.attachments = const [],
    this.aiTriage,
    this.caseSummary,
    this.activeDraft,
    this.isLoading = false,
    this.isAiLoading = false,
    this.errorMessage,
    this.isConflictStale = false,
  });

  List<CaseMessageModel> get publicMessages =>
      messages.where((m) => !m.isInternal).toList();

  List<CaseMessageModel> get internalNotes =>
      messages.where((m) => m.isInternal).toList();

  CaseDetailState copyWith({
    CaseModel? activeCase,
    List<CaseMessageModel>? messages,
    List<AttachmentModel>? attachments,
    AITriageModel? aiTriage,
    CaseSummaryModel? caseSummary,
    CommunicationDraftModel? activeDraft,
    bool? isLoading,
    bool? isAiLoading,
    String? errorMessage,
    bool? isConflictStale,
  }) {
    return CaseDetailState(
      activeCase: activeCase ?? this.activeCase,
      messages: messages ?? this.messages,
      attachments: attachments ?? this.attachments,
      aiTriage: aiTriage ?? this.aiTriage,
      caseSummary: caseSummary ?? this.caseSummary,
      activeDraft: activeDraft ?? this.activeDraft,
      isLoading: isLoading ?? this.isLoading,
      isAiLoading: isAiLoading ?? this.isAiLoading,
      errorMessage: errorMessage,
      isConflictStale: isConflictStale ?? this.isConflictStale,
    );
  }
}

final caseDetailNotifierProvider =
    StateNotifierProvider.family<CaseDetailNotifier, CaseDetailState, String>((ref, caseId) {
  final apiService = ref.watch(caseApiServiceProvider);
  return CaseDetailNotifier(apiService, caseId);
});

class CaseDetailNotifier extends StateNotifier<CaseDetailState> {
  final CaseApiService _apiService;
  final String caseId;

  CaseDetailNotifier(this._apiService, this.caseId) : super(const CaseDetailState()) {
    loadCaseData();
  }

  Future<void> loadCaseData() async {
    state = state.copyWith(isLoading: true, errorMessage: null, isConflictStale: false);
    try {
      final caseDetail = await _apiService.getCaseDetail(caseId);
      final messages = await _apiService.listMessages(caseId);
      final attachments = await _apiService.listAttachments(caseId);

      state = state.copyWith(
        activeCase: caseDetail,
        messages: messages,
        attachments: attachments,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> postMessage({required String content, bool isInternal = false}) async {
    try {
      final newMessage = await _apiService.addMessage(
        caseId: caseId,
        body: content,
        isInternal: isInternal,
      );

      // If staff public message, reload case to update first_responded_at SLA clock
      final updatedMessages = [...state.messages, newMessage];
      state = state.copyWith(messages: updatedMessages);

      if (!isInternal && state.activeCase?.sla?.firstResponseAt == null) {
        await loadCaseData();
      }
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> uploadFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    try {
      final attachment = await _apiService.uploadAttachment(
        caseId: caseId,
        fileName: fileName,
        fileBytes: bytes,
        mimeType: mimeType,
      );
      state = state.copyWith(attachments: [...state.attachments, attachment]);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> transitionStatus(CaseStatus newStatus, {String? resolutionNotes}) async {
    final currentCase = state.activeCase;
    if (currentCase == null) return false;

    try {
      final updatedCase = await _apiService.updateCaseStatus(
        caseId: caseId,
        newStatus: newStatus,
        currentVersion: currentCase.version,
        resolutionNotes: resolutionNotes,
      );
      state = state.copyWith(activeCase: updatedCase, isConflictStale: false);
      return true;
    } catch (e) {
      if (e.toString().contains('409') || e.toString().contains('Conflict') || e.toString().contains('STALE_VERSION')) {
        state = state.copyWith(isConflictStale: true);
      } else {
        state = state.copyWith(errorMessage: e.toString());
      }
      return false;
    }
  }

  Future<bool> reopen(String reason) async {
    final currentCase = state.activeCase;
    if (currentCase == null) return false;

    try {
      final updatedCase = await _apiService.reopenCase(
        caseId: caseId,
        currentVersion: currentCase.version,
        reason: reason,
      );
      state = state.copyWith(activeCase: updatedCase);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  // --- AI Copilot Operations ---
  Future<void> fetchAiTriage() async {
    state = state.copyWith(isAiLoading: true);
    try {
      final triage = await _apiService.triggerAITriage(caseId);
      state = state.copyWith(aiTriage: triage, isAiLoading: false);
    } catch (e) {
      state = state.copyWith(isAiLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> fetchAiSummary() async {
    state = state.copyWith(isAiLoading: true);
    try {
      final summary = await _apiService.generateCaseSummary(caseId);
      state = state.copyWith(caseSummary: summary, isAiLoading: false);
    } catch (e) {
      state = state.copyWith(isAiLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> createAiDraft(DraftType type) async {
    state = state.copyWith(isAiLoading: true);
    try {
      final draft = await _apiService.generateDraft(caseId: caseId, draftType: type);
      state = state.copyWith(activeDraft: draft, isAiLoading: false);
    } catch (e) {
      state = state.copyWith(isAiLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> sendApprovedDraft(String finalContent) async {
    final draft = state.activeDraft;
    if (draft == null) return false;

    state = state.copyWith(isAiLoading: true);
    try {
      final message = await _apiService.sendApprovedDraft(
        caseId: caseId,
        draftId: draft.id,
        finalContent: finalContent,
      );
      state = state.copyWith(
        messages: [...state.messages, message],
        activeDraft: draft.copyWith(isSent: true, isApproved: true),
        isAiLoading: false,
      );
      // Reload to ensure SLA first_responded_at clock is updated
      await loadCaseData();
      return true;
    } catch (e) {
      state = state.copyWith(isAiLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}
