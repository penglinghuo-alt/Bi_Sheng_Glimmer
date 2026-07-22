import 'dart:convert';
import 'dart:io' show File, Directory;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/braille_record.dart';
import '../services/api_client.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._() {
    _loadFromDisk();
  }

  final List<BrailleRecord> _records = [];
  final List<void Function()> _listeners = [];
  final ApiClient _api = ApiClient();

  void addListener(void Function() cb) => _listeners.add(cb);
  void removeListener(void Function() cb) => _listeners.remove(cb);
  void _notify() {
    _saveToDisk();
    for (final l in _listeners) {
      l();
    }
  }

  List<BrailleRecord> getRecords({String? search, bool orderByDate = true}) {
    var list = List<BrailleRecord>.from(_records);
    if (search != null && search.isNotEmpty) {
      list = list.where((r) => r.title.toLowerCase().contains(search.toLowerCase())).toList();
    }
    if (orderByDate) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  void addRecord(BrailleRecord record) {
    _records.add(record);
    _notify();
  }

  void deleteRecord(String id) {
    _records.removeWhere((r) => r.id == id);
    _notify();
    _api.deleteRecord(id);
  }

  void renameRecord(String id, String newTitle) {
    final idx = _records.indexWhere((r) => r.id == id);
    if (idx != -1) {
      _records[idx] = _records[idx].copyWith(title: newTitle);
      _notify();
      _api.renameRecord(id, newTitle);
    }
  }

  BrailleRecord? getRecordById(String id) {
    try {
      return _records.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> syncFromBackend() async {
    try {
      final data = await _api.getRecords();
      final recordsList = data['records'] as List? ?? [];
      for (final item in recordsList) {
        final record = BrailleRecord.fromJson(item as Map<String, dynamic>);
        final exists = _records.any((r) => r.id == record.id);
        if (!exists) {
          _records.add(record);
        }
      }
      _notify();
    } catch (_) {}
  }

  Future<String?> saveToBackend(BrailleRecord record) async {
    try {
      final res = await _api.createRecord(record.toJson());
      return res['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  String get _storageFilePath {
    if (kIsWeb) return '';
    try {
      final dir = Directory('/tmp/book_scanner');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return '${dir.path}/records.json';
    } catch (_) {
      return '';
    }
  }

  void _saveToDisk() {
    final path = _storageFilePath;
    if (path.isEmpty) return;
    try {
      final file = File(path);
      file.writeAsStringSync(jsonEncode(_records.map((r) => r.toJson()).toList()));
    } catch (_) {}
  }

  void _loadFromDisk() {
    final path = _storageFilePath;
    if (path.isEmpty) return;
    try {
      final file = File(path);
      if (!file.existsSync()) return;
      final content = file.readAsStringSync();
      final list = jsonDecode(content) as List;
      _records.clear();
      for (final item in list) {
        _records.add(BrailleRecord.fromJson(item as Map<String, dynamic>));
      }
    } catch (_) {}
  }
}
