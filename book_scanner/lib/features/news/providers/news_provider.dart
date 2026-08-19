import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/news_item.dart';
import '../../../data/services/api_client.dart';

class NewsState {
  final List<NewsItem> items;
  final String source;
  final bool loading;
  final String? error;

  const NewsState({
    this.items = const [],
    this.source = '',
    this.loading = false,
    this.error,
  });

  NewsState copyWith({
    List<NewsItem>? items,
    String? source,
    bool? loading,
    String? error,
  }) {
    return NewsState(
      items: items ?? this.items,
      source: source ?? this.source,
      loading: loading ?? this.loading,
      error: error ?? this.error,
    );
  }
}

class NewsNotifier extends StateNotifier<NewsState> {
  final ApiClient _api = ApiClient();

  NewsNotifier() : super(const NewsState());

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final data = await _api.fetchNews();
      final rawItems = (data['items'] as List<dynamic>?) ?? [];
      final items = rawItems
          .map((e) => NewsItem.fromJson(e as Map<String, dynamic>))
          .where((e) => e.title.isNotEmpty)
          .toList();
      state = state.copyWith(
        items: items,
        source: (data['source'] as String?) ?? '',
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: '新闻加载失败，请稍后重试');
    }
  }

  void clear() {
    state = const NewsState();
  }
}

final newsProvider =
    StateNotifierProvider<NewsNotifier, NewsState>((ref) => NewsNotifier());
