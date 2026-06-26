import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/file_editor/diff_payload_parser.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/file_editor/file_editor_preview_provider.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/file_editor/file_editor_result.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/file_editor/file_editor_ui.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/file_editor/highlighted_diff_view.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/tool_confirmation_service.dart';
import 'package:aetherlink_flutter/shared/utils/line_diff.dart';

/// Cursor/Windsurf-style rendering for `@aether/file-editor` write & file-op
/// tool calls: a file-header card with an inline syntax-highlighted diff, the
/// `+N −M` stats badge, and the three HITL states (待确认 / 已应用 / 失败).
///
/// Read-only tools (read_file / list_files / …) are handled separately; this
/// view covers the mutating tools registered in the tool-renderer registry.
class FileEditorBlockView extends ConsumerStatefulWidget {
  const FileEditorBlockView({required this.block, super.key});

  final ToolBlock block;

  @override
  ConsumerState<FileEditorBlockView> createState() =>
      _FileEditorBlockViewState();
}

class _FileEditorBlockViewState extends ConsumerState<FileEditorBlockView> {
  bool _expanded = true;

  ToolBlock get block => widget.block;
  String get _tool => block.toolName ?? '';
  Map<String, Object?> get _args => block.arguments ?? const {};

  @override
  Widget build(BuildContext context) {
    final status = block.status;
    final isProcessing = status == MessageBlockStatus.pending ||
        status == MessageBlockStatus.processing ||
        status == MessageBlockStatus.streaming;
    final hasError = status == MessageBlockStatus.error;

    final needsConfirmation = block.metadata?['needsConfirmation'] == true &&
        isProcessing;
    final pending = needsConfirmation
        ? ref.watch(toolConfirmationProvider)[block.id]
        : null;

    // Light file ops (rename/move/copy/delete) render as a compact single row.
    if (_isLightOp(_tool)) {
      return FileEditorOpCard(
        icon: _opIcon(_tool),
        iconColor: _tool == 'delete_file'
            ? const Color(0xFFCB2431)
            : Theme.of(context).colorScheme.primary,
        label: _opLabel(),
        status: status,
        pending: pending,
        onApprove: pending == null ? null : () => _respond(pending, true),
        onReject: pending == null ? null : () => _respond(pending, false),
        errorText: hasError ? _resultError() : null,
      );
    }

    return _buildEditCard(
      context,
      isProcessing: isProcessing,
      hasError: hasError,
      pending: pending,
    );
  }

  Widget _buildEditCard(
    BuildContext context, {
    required bool isProcessing,
    required bool hasError,
    ToolConfirmationRequest? pending,
  }) {
    final result = parseFileEditorResult(block);
    final fileName = _editFileName();
    final language = languageForFileName(fileName);

    // Prefer backend-reported diffStats (apply_diff); otherwise fall back to
    // the client-derived diff for the sync edit tools so the header still shows
    // a +N/−M badge before/without a backend result.
    final derived = result.added == null ? _deriveDiff() : null;

    return FileEditorCard(
      fileName: fileName,
      subtitle: _editSubtitle(),
      icon: _fileIcon(fileName),
      status: block.status,
      addedLines: result.added ?? derived?.added,
      removedLines: result.removed ?? derived?.removed,
      expanded: _expanded,
      onToggle: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDiffBody(context, language: language),
          if (pending != null)
            FileEditorConfirmBar(
              summary: pending.summary,
              onApprove: () => _respond(pending, true),
              onReject: () => _respond(pending, false),
            )
          else if (isProcessing)
            const FileEditorProcessingRow()
          else if (hasError)
            FileEditorErrorRow(
              message: _resultError() ?? '执行失败',
              suggestion: _errorSuggestion(_resultError()),
            ),
        ],
      ),
    );
  }

  /// The diff/preview body. `write_to_file` reads the current file to render a
  /// real old→new diff; the other edit tools derive their diff from the args.
  Widget _buildDiffBody(BuildContext context, {String? language}) {
    if (_tool == 'write_to_file') {
      final path = _args['path']?.toString() ?? '';
      final newContent = _args['content']?.toString() ?? '';
      final current = ref.watch(fileEditorCurrentContentProvider(path));
      return current.when(
        loading: () => const FileEditorProcessingRow(label: '读取文件中...'),
        error: (_, __) => _diffView(
          computeLineDiff('', newContent),
          language,
        ),
        data: (old) => _diffView(
          computeLineDiff(old ?? '', newContent),
          language,
        ),
      );
    }

    final diff = _deriveDiff();
    if (diff == null || diff.isEmpty) {
      return const FileEditorEmptyBody();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_tool == 'insert_content')
          FileEditorHint(text: _insertHint(diff.added)),
        _diffView(diff, language),
      ],
    );
  }

  String _insertHint(int lines) {
    if (_args['at_end'] == true) return '在文件末尾追加 $lines 行';
    final line = _args['line'] ?? '?';
    final after = _args['position']?.toString().toLowerCase() == 'after';
    return after ? '在第 $line 行之后插入 $lines 行' : '在第 $line 行插入 $lines 行';
  }

  Widget _diffView(LineDiff diff, String? language) {
    if (diff.isEmpty) return const FileEditorEmptyBody();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: HighlightedDiffView(diff: diff, language: language),
    );
  }

  /// Derives a [LineDiff] from the tool args (everything except write_to_file,
  /// which needs an async read of the current file).
  LineDiff? _deriveDiff() {
    switch (_tool) {
      case 'apply_diff':
        final diff = _args['diff']?.toString() ?? '';
        final unified =
            _args['strategy']?.toString().toLowerCase() == 'unified';
        return parseDiffPayload(diff, unified: unified);
      case 'create_file':
        return computeLineDiff('', _args['content']?.toString() ?? '');
      case 'insert_content':
        final content = _args['content']?.toString() ?? '';
        if (_args['at_end'] == true) {
          // Position unknown until appended; suppress the gutter.
          return computeLineDiff('', content, assignLineNumbers: false);
        }
        final line = int.tryParse('${_args['line']}') ?? 1;
        final after = _args['position']?.toString().toLowerCase() == 'after';
        return computeLineDiff('', content, newStart: after ? line + 1 : line);
      case 'replace_in_file':
        // Position in the file is unknown, so suppress the line-number gutter.
        return computeLineDiff(
          _args['search']?.toString() ?? '',
          _args['replace']?.toString() ?? '',
          assignLineNumbers: false,
        );
    }
    return null;
  }

  // ----- header text -----

  String _editFileName() {
    final raw = switch (_tool) {
      'create_file' => _args['name']?.toString(),
      _ => _args['path']?.toString(),
    };
    return fileNameFromPath(raw);
  }

  String _editSubtitle() {
    final result = parseFileEditorResult(block);
    return switch (_tool) {
      'write_to_file' => '覆盖写入',
      'apply_diff' => result.error == null ? '应用 diff' : 'diff',
      'create_file' => '新建文件',
      'insert_content' => '插入内容',
      'replace_in_file' => '查找替换',
      _ => '',
    };
  }

  String _opLabel() {
    String tail(Object? p) => fileNameFromPath(p?.toString());
    return switch (_tool) {
      'rename_file' =>
        '重命名 ${tail(_args['path'])} → ${_args['new_name'] ?? ''}',
      'move_file' => _args['new_name'] != null
          ? '移动 ${tail(_args['source_path'])} → ${tail(_args['destination_path'])}/${_args['new_name']}'
          : '移动 ${tail(_args['source_path'])} → ${tail(_args['destination_path'])}/',
      'copy_file' =>
        '复制 ${tail(_args['source_path'])} → ${tail(_args['destination_path'])}/',
      'delete_file' => '删除 ${tail(_args['path'])}',
      _ => _tool,
    };
  }

  String? _resultError() => parseFileEditorResult(block).error;

  /// Surfaces an actionable "use the other tool" hint for common failures, most
  /// importantly write_to_file failing because the target doesn't exist yet.
  String? _errorSuggestion(String? error) {
    if (error == null) return null;
    if (_tool == 'write_to_file' &&
        (error.contains('不存在') || error.contains('create_file'))) {
      return '该文件不存在。新建文件请改用 create_file（参数：parent_path + name）。';
    }
    return null;
  }

  void _respond(ToolConfirmationRequest req, bool approved) {
    ref
        .read(toolConfirmationProvider.notifier)
        .respond(req.id, approved: approved);
  }

  IconData _fileIcon(String name) {
    final lang = languageForFileName(name);
    return lang == null ? LucideIcons.file : LucideIcons.fileCode2;
  }

  IconData _opIcon(String tool) => switch (tool) {
        'rename_file' => LucideIcons.pencil,
        'move_file' => LucideIcons.cornerUpRight,
        'copy_file' => LucideIcons.copy,
        'delete_file' => LucideIcons.trash2,
        _ => LucideIcons.file,
      };

  static bool _isLightOp(String tool) => const {
        'rename_file',
        'move_file',
        'copy_file',
        'delete_file',
      }.contains(tool);
}
