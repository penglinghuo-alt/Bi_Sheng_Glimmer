import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/post_comment.dart';
import '../../../data/models/showcase_post.dart';
import '../providers/publish_provider.dart';
import '../providers/showcase_provider.dart';

class PublishPage extends ConsumerStatefulWidget {
  final String? initialRecordId;

  const PublishPage({super.key, this.initialRecordId});

  @override
  ConsumerState<PublishPage> createState() => _PublishPageState();
}

enum _PublishSource { repository, localFile }

class _PublishPageState extends ConsumerState<PublishPage> {
  _PublishSource _source = _PublishSource.repository;
  UnpublishedRecord? _selectedRecord;
  String? _localFileName;
  String _localFileContent = '';
  final _descriptionController = TextEditingController();
  final _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(publishProvider.notifier).loadUnpublished();
      final targetId = widget.initialRecordId;
      if (targetId != null && targetId.isNotEmpty) {
        final records = ref.read(publishProvider).records;
        final match = records.where((r) => r.id == targetId).toList();
        if (match.isNotEmpty && mounted) {
          setState(() => _selectedRecord = match.first);
        }
      }
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(publishProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('发布'), centerTitle: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sourceSelector(theme),
            const SizedBox(height: 20),
            if (_source == _PublishSource.repository)
              _repositoryPicker(theme, state)
            else
              _localFilePicker(theme),
            const SizedBox(height: 20),
            if (_selectedRecord != null || _localFileContent.isNotEmpty) ...[
              if (_source == _PublishSource.localFile) ...[
                Text('标题', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(hintText: '给这条记录起个标题'),
                ),
                const SizedBox(height: 16),
              ],
              Text('描述', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLength: 500,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '写点什么介绍这条记录（最多 500 字）',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(state.error!, style: TextStyle(color: AppColors.error, fontSize: 14)),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: state.publishing ? null : _publish,
                  icon: state.publishing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.publish_rounded),
                  label: Text(state.publishing ? '发布中...' : '发布'),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _sourceSelector(ThemeData theme) {
    return Row(children: [
      Expanded(
        child: _sourceOption(theme, _PublishSource.repository, Icons.storage_rounded, '从存储库选择'),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _sourceOption(theme, _PublishSource.localFile, Icons.upload_file_rounded, '上传本地文件'),
      ),
    ]);
  }

  Widget _sourceOption(ThemeData theme, _PublishSource source, IconData icon, String label) {
    final selected = _source == source;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: () => setState(() {
          _source = source;
          _selectedRecord = null;
          _localFileName = null;
          _localFileContent = '';
        }),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? theme.colorScheme.primary : Colors.transparent, width: 1.5),
          ),
          child: Column(children: [
            Icon(icon, size: 26, color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface)),
          ]),
        ),
      ),
    );
  }

  Widget _repositoryPicker(ThemeData theme, PublishState state) {
    if (state.loading) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    }
    if (state.records.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Icon(Icons.inventory_2_outlined, size: 40, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          Text('存储库中没有可发布的记录', style: theme.textTheme.bodySmall),
        ]),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('选择一条记录', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ...state.records.map((r) => _recordOption(theme, r)),
      ],
    );
  }

  Widget _recordOption(ThemeData theme, UnpublishedRecord record) {
    final selected = _selectedRecord?.id == record.id;
    return Semantics(
      button: true,
      label: record.title,
      child: InkWell(
        onTap: () => setState(() {
          _selectedRecord = selected ? null : record;
        }),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? theme.colorScheme.primary : Colors.transparent, width: 1.2),
          ),
          child: Row(children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(record.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text('${record.sourceType} · ${record.pageCount} 页', style: theme.textTheme.bodySmall),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _localFilePicker(ThemeData theme) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('选择本地文件', style: theme.textTheme.titleSmall),
      const SizedBox(height: 8),
      Semantics(
        button: true,
        label: '选择文件',
        child: InkWell(
          onTap: _pickLocalFile,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4), width: 1),
            ),
            child: Column(children: [
              Icon(Icons.upload_file_rounded, size: 40, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                _localFileName ?? '点击选择文本文件',
                textAlign: TextAlign.center,
                style: _localFileName == null ? theme.textTheme.bodyMedium : theme.textTheme.titleSmall,
              ),
            ]),
          ),
        ),
      ),
    ]);
  }

  Future<void> _pickLocalFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'md'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final name = file.name;
    String content = '';
    if (file.bytes != null) {
      content = String.fromCharCodes(file.bytes!);
    }
    setState(() {
      _localFileName = name;
      _localFileContent = content;
    });
  }

  Future<void> _publish() async {
    final desc = _descriptionController.text.trim();
    ShowcasePost? created;
    if (_source == _PublishSource.repository) {
      final record = _selectedRecord;
      if (record == null) {
        _showSnack('请先选择一条记录');
        return;
      }
      created = await ref.read(publishProvider.notifier).publish(
            recordId: record.id,
            description: desc,
          );
    } else {
      if (_localFileContent.isEmpty) {
        _showSnack('请先选择本地文件');
        return;
      }
      final title = _titleController.text.trim().isEmpty ? _localFileName ?? '未命名记录' : _titleController.text.trim();
      created = await ref.read(publishProvider.notifier).publish(
            title: title,
            textContent: _localFileContent,
            description: desc,
          );
    }

    if (created != null && mounted) {
      ref.read(showcaseProvider.notifier).loadFirstPage();
      _showSnack('发布成功');
      context.pop();
    } else if (mounted) {
      _showSnack('发布失败，请稍后重试');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
