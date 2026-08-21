import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../voice/providers/voice_provider.dart';

/// 发帖语音输入：复用语音转写链路，把说话内容转成文字供描述框使用
class VoiceInputSheet extends ConsumerStatefulWidget {
  const VoiceInputSheet({super.key});

  @override
  ConsumerState<VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends ConsumerState<VoiceInputSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceProvider.notifier).init();
    });
  }

  @override
  void dispose() {
    ref.read(voiceProvider.notifier).reset();
    super.dispose();
  }

  Future<void> _toggle() async {
    final status = ref.read(voiceProvider).status;
    final notifier = ref.read(voiceProvider.notifier);
    if (status == VoiceStatus.recording) {
      await notifier.stopRecording();
    } else if (status == VoiceStatus.starting) {
      return;
    } else {
      await notifier.startRecording();
    }
  }

  void _useText() {
    final text = ref.read(voiceProvider).finalText.trim();
    if (text.isEmpty) return;
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(voiceProvider);
    final recording = state.status == VoiceStatus.recording;
    final processing = state.status == VoiceStatus.processing || state.status == VoiceStatus.starting;
    final hasFinal = state.finalText.trim().isNotEmpty;
    final hasError = state.status == VoiceStatus.error && state.error != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.mic_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('语音输入', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                tooltip: '清空',
                onPressed: hasFinal || recording ? () => ref.read(voiceProvider.notifier).reset() : null,
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ]),
            const SizedBox(height: 8),
            if (state.deviceName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('当前麦克风：${state.deviceName}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
              ),
            Container(
              constraints: const BoxConstraints(minHeight: 88),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  hasFinal
                      ? state.finalText
                      : (state.partialText.isNotEmpty ? state.partialText : '点击下方按钮开始说话…'),
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ),
            ),
            if (hasError) ...[
              const SizedBox(height: 8),
              Text(state.error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            Center(
              child: Semantics(
                button: true,
                label: recording ? '停止录音' : '开始录音',
                child: InkWell(
                  onTap: processing ? null : _toggle,
                  borderRadius: BorderRadius.circular(40),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: recording
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary.withValues(alpha: 0.12),
                      border: Border.all(
                        color: recording ? theme.colorScheme.error : theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    child: processing
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            recording ? Icons.stop_rounded : Icons.mic_rounded,
                            color: recording ? Colors.white : theme.colorScheme.primary,
                            size: 32,
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                recording ? '正在聆听，点击停止' : (processing ? '正在转写…' : (hasFinal ? '转写完成' : '点击开始说话')),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: hasFinal ? _useText : null,
              icon: const Icon(Icons.check_rounded),
              label: const Text('使用这段文字'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ],
        ),
      ),
    );
  }
}
