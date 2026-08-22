import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/voice_provider.dart';

class VoicePage extends ConsumerStatefulWidget {
  const VoicePage({super.key});

  @override
  ConsumerState<VoicePage> createState() => _VoicePageState();
}

class _VoicePageState extends ConsumerState<VoicePage> {
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    ref.read(voiceProvider.notifier).init();
  }

  void _start() {
    final status = ref.read(voiceProvider).status;
    if (_pressed || status == VoiceStatus.recording || status == VoiceStatus.starting) {
      return;
    }
    _pressed = true;
    ref.read(voiceProvider.notifier).startRecording();
  }

  Future<void> _stop() async {
    if (!_pressed) return;
    _pressed = false;
    await ref.read(voiceProvider.notifier).stopRecording();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(voiceProvider);

    // 录音结束（无论成功/失败/出错）都释放按键锁，保证可再次按住重试
    ref.listen(voiceProvider.select((s) => s.status), (prev, next) {
      if (next != VoiceStatus.recording && next != VoiceStatus.starting) {
        _pressed = false;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('语音输入')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: _textArea(theme, state),
                ),
              ),
              _hintText(theme, state),
              const SizedBox(height: 20),
              _recordButton(theme, state),
              if (state.status == VoiceStatus.done) ...[
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: state.finalText.isEmpty ? null : () => _save(),
                      icon: const Icon(Icons.save_alt_rounded),
                      label: const Text('保存到存储库'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => ref.read(voiceProvider.notifier).reset(),
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('重新录音'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                    ),
                  ),
                ]),
              ],
              if (state.status == VoiceStatus.saving) const Padding(
                padding: EdgeInsets.only(top: 16),
                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textArea(ThemeData theme, VoiceState state) {
    final isRecording = state.status == VoiceStatus.recording;
    final display = isRecording && state.partialText.isNotEmpty
        ? state.partialText
        : state.finalText.isNotEmpty
            ? state.finalText
            : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.record_voice_over_rounded, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(_statusLabel(state), style: theme.textTheme.titleMedium),
          ]),
          if (state.deviceName != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.mic_none_rounded, size: 14, color: theme.colorScheme.outline),
              const SizedBox(width: 6),
              Text(
                '麦克风：${state.deviceName}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
            ]),
          ],
          const SizedBox(height: 16),
          if (display.isEmpty && state.error == null)
            Text('按住下方按钮开始录音，松开停止。实时语音将自动转换为文字。', style: theme.textTheme.bodyMedium)
          else if (display.isNotEmpty)
            Text(display, style: theme.textTheme.bodyLarge?.copyWith(height: 1.6))
          else
            Text('暂无内容', style: theme.textTheme.bodyMedium),
          if (state.error != null) ...[
            const SizedBox(height: 12),
            Text(state.error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            const SizedBox(height: 6),
            Text('点击下方"按住说话"可重新尝试连接',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          ],
        ],
      ),
    );
  }

  String _statusLabel(VoiceState state) {
    switch (state.status) {
      case VoiceStatus.starting:
        return '正在启动后端录音…';
      case VoiceStatus.recording:
        return '录音中…';
      case VoiceStatus.processing:
        return '正在识别…';
      case VoiceStatus.saving:
        return '正在保存…';
      case VoiceStatus.done:
        return '识别完成';
      case VoiceStatus.error:
        return '出错了';
      default:
        return '语音转文字';
    }
  }

  Widget _hintText(ThemeData theme, VoiceState state) {
    if (state.status != VoiceStatus.recording) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '松开按钮结束录音',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
      ),
    );
  }

  Widget _recordButton(ThemeData theme, VoiceState state) {
    final recording = state.status == VoiceStatus.recording;
    final busy = state.status == VoiceStatus.starting ||
        state.status == VoiceStatus.processing ||
        state.status == VoiceStatus.saving;

    return GestureDetector(
      onTapDown: busy ? null : (_) => _start(),
      onTapUp: recording ? (_) => _stop() : null,
      onTapCancel: recording ? () => _stop() : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 72,
        decoration: BoxDecoration(
          color: recording ? theme.colorScheme.error : theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: (recording ? theme.colorScheme.error : theme.colorScheme.primary).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              recording ? Icons.stop_circle_outlined : Icons.mic_rounded,
              color: Colors.white,
              size: 30,
            ),
            const SizedBox(width: 10),
            Text(
              recording ? '正在录音，松开结束' : (busy ? '请稍候…' : '按住说话'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final ok = await ref.read(voiceProvider.notifier).save();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存到存储库'), behavior: SnackBarBehavior.floating),
      );
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      }
    }
  }
}
