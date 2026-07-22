import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/braille_record.dart';
import '../../../data/local_db/database_helper.dart';

class RepoState {
  final List<BrailleRecord> records;
  final String searchQuery;

  const RepoState({this.records = const [], this.searchQuery = ''});

  RepoState copyWith({List<BrailleRecord>? records, String? searchQuery}) {
    return RepoState(
      records: records ?? this.records,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class RepoNotifier extends StateNotifier<RepoState> {
  final DatabaseHelper _db = DatabaseHelper();

  RepoNotifier() : super(const RepoState()) {
    loadRecords();
    _db.addListener(() => loadRecords());
    _syncFromBackend();
  }

  Future<void> _syncFromBackend() async {
    await _db.syncFromBackend();
    loadRecords();
  }

  Future<void> loadRecords({String? search}) async {
    final records = _db.getRecords(search: search);
    state = state.copyWith(records: records, searchQuery: search);
  }

  Future<void> refreshRecords() async {
    await _syncFromBackend();
    loadRecords(search: state.searchQuery);
  }

  Future<void> deleteRecord(String id) async {
    _db.deleteRecord(id);
    loadRecords(search: state.searchQuery);
  }

  Future<void> renameRecord(String id, String newTitle) async {
    _db.renameRecord(id, newTitle);
    loadRecords(search: state.searchQuery);
  }

  Future<BrailleRecord?> getRecord(String id) async {
    return _db.getRecordById(id);
  }
}

final repoProvider = StateNotifierProvider<RepoNotifier, RepoState>((ref) => RepoNotifier());
