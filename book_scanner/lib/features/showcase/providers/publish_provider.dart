import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/post_comment.dart';
import '../../../data/models/showcase_post.dart';
import '../../../data/services/api_client.dart';

class PublishState {
  final List<UnpublishedRecord> records;
  final bool loading;
  final bool publishing;
  final String? error;

  const PublishState({this.records = const [], this.loading = false, this.publishing = false, this.error});

  PublishState copyWith({
    List<UnpublishedRecord>? records,
    bool? loading,
    bool? publishing,
    String? error,
  }) {
    return PublishState(
      records: records ?? this.records,
      loading: loading ?? this.loading,
      publishing: publishing ?? this.publishing,
      error: error ?? this.error,
    );
  }
}

class PublishNotifier extends StateNotifier<PublishState> {
  final ApiClient _api = ApiClient();

  PublishNotifier() : super(const PublishState());

  Future<void> loadUnpublished() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final data = await _api.getUnpublishedRecords();
      state = state.copyWith(
        records: data.map((e) => UnpublishedRecord.fromJson(e)).toList(),
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: '加载失败，请稍后重试');
    }
  }

  Future<ShowcasePost?> publish({
    String? recordId,
    String? title,
    String? textContent,
    int pageCount = 1,
    String? description,
  }) async {
    state = state.copyWith(publishing: true, error: null);
    try {
      final data = await _api.createShowcasePost({
        if (recordId != null) 'record_id': recordId,
        if (title != null) 'title': title,
        if (textContent != null) 'text_content': textContent,
        'page_count': pageCount,
        if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
      });
      state = state.copyWith(publishing: false);
      return ShowcasePost.fromJson(data);
    } catch (e) {
      state = state.copyWith(publishing: false, error: '发布失败，请稍后重试');
      return null;
    }
  }
}

final publishProvider = StateNotifierProvider<PublishNotifier, PublishState>((ref) => PublishNotifier());
