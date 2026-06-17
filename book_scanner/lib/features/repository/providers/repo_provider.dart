import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/braille_record.dart';
import '../../../data/local_db/database_helper.dart';

class RepoState {
  final List<BrailleRecord> records;
  final String searchQuery;
  final bool isLoading;

  const RepoState({this.records = const [], this.searchQuery = '', this.isLoading = false});

  RepoState copyWith({List<BrailleRecord>? records, String? searchQuery, bool? isLoading}) {
    return RepoState(
      records: records ?? this.records,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class RepoNotifier extends StateNotifier<RepoState> {
  final DatabaseHelper _db = DatabaseHelper();

  RepoNotifier() : super(const RepoState()) {
    _initDemoData();
  }

  void _initDemoData() {
    final now = DateTime.now();
    _db.addRecord(BrailleRecord(id: '1', title: '语文课本 第三单元', sourceType: '现场扫描', dotMatrixWidth: 32, dotMatrixHeight: 48, dotMatrixData: _genMatrix(32, 48), createdAt: now.subtract(const Duration(hours: 2)), pageCount: 12));
    _db.addRecord(BrailleRecord(id: '2', title: '数学公式集', sourceType: '本地文件', dotMatrixWidth: 40, dotMatrixHeight: 60, dotMatrixData: _genMatrix(40, 60), createdAt: now.subtract(const Duration(days: 1)), pageCount: 5));
    _db.addRecord(BrailleRecord(id: '3', title: '英语阅读理解', sourceType: '现场扫描', dotMatrixWidth: 28, dotMatrixHeight: 44, dotMatrixData: _genMatrix(28, 44), createdAt: now.subtract(const Duration(days: 2)), pageCount: 8));
    loadRecords();
  }

  List<List<int>> _genMatrix(int w, int h) {
    return List.generate(h, (y) => List.generate(w, (x) => (x * y) % 3 == 0 ? 1 : 0));
  }

  void loadRecords({String? search}) {
    state = state.copyWith(isLoading: true, searchQuery: search);
    state = state.copyWith(records: _db.getRecords(search: search), isLoading: false);
  }

  void deleteRecord(String id) {
    _db.deleteRecord(id);
    loadRecords(search: state.searchQuery);
  }

  void renameRecord(String id, String newTitle) {
    _db.renameRecord(id, newTitle);
    loadRecords(search: state.searchQuery);
  }

  BrailleRecord? getRecord(String id) => _db.getRecordById(id);
}

final repoProvider = StateNotifierProvider<RepoNotifier, RepoState>((ref) => RepoNotifier());
