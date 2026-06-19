import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/braille_record.dart';
import '../../../data/services/api_client.dart';

class RepoState {
  final List<BrailleRecord> records;
  final String searchQuery;
  final bool isLoading;
  final String? error;

  const RepoState({this.records = const [], this.searchQuery = '', this.isLoading = false, this.error});

  RepoState copyWith({List<BrailleRecord>? records, String? searchQuery, bool? isLoading, String? error, bool clearError = false}) {
    return RepoState(
      records: records ?? this.records,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class RepoNotifier extends StateNotifier<RepoState> {
  final ApiClient _api = ApiClient();

  RepoNotifier() : super(const RepoState()) {
    loadRecords();
  }

  Future<void> loadRecords({String? search}) async {
    state = state.copyWith(isLoading: true, searchQuery: search, clearError: true);
    try {
      final data = await _api.getRecords(search: search ?? '');
      final records = (data['records'] as List).map((j) => BrailleRecord.fromJson(j)).toList();
      state = state.copyWith(records: records, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '加载失败，请检查网络连接');
    }
  }

  Future<void> deleteRecord(String id) async {
    try {
      await _api.deleteRecord(id);
      loadRecords(search: state.searchQuery);
    } catch (e) {
      state = state.copyWith(error: '删除失败');
    }
  }

  Future<void> renameRecord(String id, String newTitle) async {
    try {
      await _api.renameRecord(id, newTitle);
      loadRecords(search: state.searchQuery);
    } catch (e) {
      state = state.copyWith(error: '重命名失败');
    }
  }

  Future<BrailleRecord?> getRecord(String id) async {
    try {
      final data = await _api.getRecord(id);
      return BrailleRecord.fromJson(data);
    } catch (e) {
      return null;
    }
  }
}

final repoProvider = StateNotifierProvider<RepoNotifier, RepoState>((ref) => RepoNotifier());
