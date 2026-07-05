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
    _seedIfEmpty();
    loadRecords();
    _db.addListener(() => loadRecords());
  }

  void _seedIfEmpty() {
    if (_db.getRecords().isNotEmpty) return;

    final now = DateTime.now();
    _db.addRecord(BrailleRecord(
      id: 'seed_001',
      title: '第四章 黎族船形屋文化源流与建筑特色',
      sourceType: '现场扫描',
      dotMatrixWidth: 40,
      dotMatrixHeight: 30,
      dotMatrixData: List.generate(30, (_) => List.filled(40, 0)),
      createdAt: now.subtract(const Duration(hours: 3)),
      pageCount: 4,
    ));
  }

  Future<void> loadRecords({String? search}) async {
    final records = _db.getRecords(search: search);
    state = state.copyWith(records: records, searchQuery: search);
  }

  Future<void> refreshRecords() async {
    final records = _db.getRecords(search: state.searchQuery);
    state = state.copyWith(records: records);
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
