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
      title: '三年级语文课文《春》',
      sourceType: '现场扫描',
      dotMatrixWidth: 40,
      dotMatrixHeight: 30,
      dotMatrixData: List.generate(30, (_) => List.filled(40, 0)),
      createdAt: now.subtract(const Duration(hours: 3)),
      pageCount: 3,
    ));
    _db.addRecord(BrailleRecord(
      id: 'seed_002',
      title: '数学练习册 第五单元',
      sourceType: '本地文件',
      dotMatrixWidth: 0,
      dotMatrixHeight: 0,
      dotMatrixData: [],
      createdAt: now.subtract(const Duration(days: 1)),
      pageCount: 8,
    ));
    _db.addRecord(BrailleRecord(
      id: 'seed_003',
      title: '英语单词表 Unit 3',
      sourceType: '现场扫描',
      dotMatrixWidth: 32,
      dotMatrixHeight: 24,
      dotMatrixData: List.generate(24, (_) => List.filled(32, 0)),
      createdAt: now.subtract(const Duration(days: 2)),
      pageCount: 2,
    ));
    _db.addRecord(BrailleRecord(
      id: 'seed_004',
      title: '通知：期末考试安排',
      sourceType: '本地文件',
      dotMatrixWidth: 0,
      dotMatrixHeight: 0,
      dotMatrixData: [],
      createdAt: now.subtract(const Duration(days: 3)),
      pageCount: 1,
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
