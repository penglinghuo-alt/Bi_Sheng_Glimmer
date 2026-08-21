import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/api_client.dart';

enum AiReportStatus { idle, generating, done, error }

/// AI 盲文报告全局状态：切 tab 不销毁，回来仍显示工作现场
class AiReportState {
  final bool active; // 是否处于"未退出的 AI 报告会话"
  final AiReportStatus status;
  final String topic;
  final String extra;
  final String? title;
  final String content;
  final String? error;

  const AiReportState({
    this.active = false,
    this.status = AiReportStatus.idle,
    this.topic = '',
    this.extra = '',
    this.title,
    this.content = '',
    this.error,
  });

  AiReportState copyWith({
    bool? active,
    AiReportStatus? status,
    String? topic,
    String? extra,
    String? title,
    String? content,
    String? error,
  }) {
    return AiReportState(
      active: active ?? this.active,
      status: status ?? this.status,
      topic: topic ?? this.topic,
      extra: extra ?? this.extra,
      title: title ?? this.title,
      content: content ?? this.content,
      error: error ?? this.error,
    );
  }
}

final aiReportProvider = StateNotifierProvider<AiReportNotifier, AiReportState>((ref) {
  return AiReportNotifier(ApiClient());
});

class AiReportNotifier extends StateNotifier<AiReportState> {
  AiReportNotifier(this._api) : super(const AiReportState());

  final ApiClient _api;

  /// 进入 AI 报告页：标记会话活跃，切 tab 后再点新闻 tab 会回到此页
  void enter() => state = state.copyWith(active: true);

  /// 用户主动退出 AI 报告页：会话结束，下次点新闻 tab 回新闻列表
  void exit() => state = const AiReportState();

  void setTopic(String v) => state = state.copyWith(topic: v);

  void setExtra(String v) => state = state.copyWith(extra: v);

  Future<void> generate() async {
    final topic = state.topic.trim();
    if (topic.isEmpty) {
      state = state.copyWith(status: AiReportStatus.error, error: '请输入报告主题');
      return;
    }
    state = state.copyWith(status: AiReportStatus.generating, error: null, title: null, content: '');
    try {
      final data = await _api.fetchAiReport(topic, extra: state.extra.trim());
      final rawTitle = (data['title'] as String?)?.trim();
      final content = (data['content'] as String?) ?? '';
      if (mounted) {
        state = state.copyWith(
          status: AiReportStatus.done,
          title: (rawTitle != null && rawTitle.isNotEmpty) ? rawTitle : topic,
          content: content,
          error: content.isEmpty ? '报告内容为空' : null,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(status: AiReportStatus.error, error: '报告生成失败，请检查网络后重试');
      }
    }
  }
}
