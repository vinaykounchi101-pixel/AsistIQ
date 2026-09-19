import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/case_model.dart';
import '../services/case_api_service.dart';

class CaseListState {
  final List<CaseModel> cases;
  final bool isLoading;
  final String? errorMessage;
  final String? selectedStatus;
  final String? selectedPriority;
  final String searchQuery;

  const CaseListState({
    this.cases = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedStatus,
    this.selectedPriority,
    this.searchQuery = '',
  });

  List<CaseModel> get filteredCases {
    return cases.where((c) {
      if (selectedStatus != null && selectedStatus!.isNotEmpty) {
        if (c.status.name != selectedStatus) return false;
      }
      if (selectedPriority != null && selectedPriority!.isNotEmpty) {
        if (c.priority.code != selectedPriority) return false;
      }
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchTitle = c.title.toLowerCase().contains(q);
        final matchRef = c.referenceNumber.toLowerCase().contains(q);
        final matchDesc = c.description.toLowerCase().contains(q);
        return matchTitle || matchRef || matchDesc;
      }
      return true;
    }).toList();
  }

  CaseListState copyWith({
    List<CaseModel>? cases,
    bool? isLoading,
    String? errorMessage,
    String? selectedStatus,
    String? selectedPriority,
    String? searchQuery,
  }) {
    return CaseListState(
      cases: cases ?? this.cases,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      selectedPriority: selectedPriority ?? this.selectedPriority,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

final caseListNotifierProvider = StateNotifierProvider<CaseListNotifier, CaseListState>((ref) {
  final apiService = ref.watch(caseApiServiceProvider);
  return CaseListNotifier(apiService);
});

class CaseListNotifier extends StateNotifier<CaseListState> {
  final CaseApiService _apiService;

  CaseListNotifier(this._apiService) : super(const CaseListState()) {
    fetchCases();
  }

  Future<void> fetchCases() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final cases = await _apiService.listCases(
        status: state.selectedStatus,
        priority: state.selectedPriority,
      );
      state = state.copyWith(cases: cases, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setStatusFilter(String? status) {
    state = state.copyWith(selectedStatus: status);
    fetchCases();
  }

  void setPriorityFilter(String? priority) {
    state = state.copyWith(selectedPriority: priority);
    fetchCases();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }
}
