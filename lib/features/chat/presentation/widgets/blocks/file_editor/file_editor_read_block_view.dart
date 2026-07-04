import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/code_block/code_block_view.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/file_editor/file_editor_ui.dart';
import 'package:aetherlink_flutter/shared/utils/line_diff.dart';

/// Compact rendering for read-only `@aether/file-editor` tools (read_file,
/// list_files, search_files, …): a one-line header with an icon, summary, and
/// a chevron that expands to the file content / entry list.
class FileEditorReadBlockView extends StatefulWidget {
  const FileEditorReadBlockView({required this.block, super.key});

  final ToolBlock block;

  @override
  State<FileEditorReadBlockView> createState() =>
      _FileEditorReadBlockViewState();
}

class _FileEditorReadBlockViewState extends State<FileEditorReadBlockView> {
  bool _expanded = false;

  ToolBlock get block => widget.block;
  String get _tool => block.toolName ?? '';
  Map<String, Object?> get _args => block.arguments ?? const {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = block.status;
    final isProcessing = status == MessageBlockStatus.pending ||
        status == MessageBlockStatus.processing ||
        status == MessageBlockStatus.streaming;
    final hasError = status == MessageBlockStatus.error;
    final data = _data();

    final (icon, summary) = _header(data);
    final body = (!isProcessing && !hasError) ? _body(context, data) : null;
    final canExpand = body != null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: canExpand ? () => setState(() => _expanded = !_expanded) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  if (isProcessing)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  else
                    Icon(
                      hasError ? LucideIcons.circleAlert : icon,
                      size: 15,
                      color: hasError
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isProcessing ? _processingLabel() : summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: hasError ? theme.colorScheme.error : null,
                      ),
                    ),
                  ),
                  if (canExpand)
                    AnimatedRotation(
                      turns: _expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        LucideIcons.chevronRight,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (hasError)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: FileEditorErrorRow(message: _error() ?? '读取失败'),
            ),
          if (canExpand)
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: body,
              ),
              crossFadeState:
                  _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
        ],
      ),
    );
  }

  // ----- header -----

  (IconData, String) _header(Map<String, Object?>? data) {
    switch (_tool) {
      case 'read_file':
        final files = data?['files'];
        if (files is List) {
          return (LucideIcons.fileText, '读取 ${files.length} 个文件');
        }
        final name = fileNameFromPath(data?['path']?.toString() ??
            _args['path']?.toString());
        final start = data?['startLine'];
        final end = data?['endLine'];
        final range = (start != null && end != null) ? ' ($start–$end 行)' : '';
        return (LucideIcons.fileText, '读取 $name$range');
      case 'list_files':
      case 'get_workspace_files':
        final count = data?['count'] ?? 0;
        final name = fileNameFromPath(data?['path']?.toString() ??
            _args['path']?.toString());
        return (LucideIcons.folderOpen, '列出 $name · $count 项');
      case 'get_file_info':
        final name = fileNameFromPath(data?['name']?.toString() ??
            _args['path']?.toString());
        return (LucideIcons.info, '文件信息 · $name');
      case 'search_files':
        final count = data?['count'] ?? 0;
        final query = _args['query']?.toString() ?? '';
        return (LucideIcons.search, '检索「$query」· $count 个结果');
    }
    return (LucideIcons.file, _tool);
  }

  String _processingLabel() => switch (_tool) {
        'read_file' => '读取文件中...',
        'search_files' => '检索中...',
        _ => '执行中...',
      };

  // ----- body -----

  Widget? _body(BuildContext context, Map<String, Object?>? data) {
    if (data == null) return null;
    switch (_tool) {
      case 'read_file':
        return _readFileBody(data);
      case 'list_files':
      case 'get_workspace_files':
      case 'search_files':
        return _entryListBody(data['files']);
      case 'get_file_info':
        return _fileInfoBody(data);
    }
    return null;
  }

  Widget? _readFileBody(Map<String, Object?> data) {
    final files = data['files'];
    if (files is List) {
      final widgets = <Widget>[];
      for (final f in files) {
        if (f is! Map) continue;
        final path = f['path']?.toString() ?? '';
        final name = fileNameFromPath(path);
        if (f['status'] == 'error') {
          widgets.add(Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: FileEditorErrorRow(message: '$name: ${f['error'] ?? ''}'),
          ));
        } else {
          widgets.add(_fileContent(name, f['content']?.toString() ?? ''));
        }
      }
      return Padding(
        padding: const EdgeInsets.all(4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widgets),
      );
    }
    final name = fileNameFromPath(data['path']?.toString());
    return Padding(
      padding: const EdgeInsets.all(4),
      child: _fileContent(name, data['content']?.toString() ?? ''),
    );
  }

  Widget _fileContent(String name, String content) {
    final lang = languageForFileName(name) ?? 'text';
    // read_file output is prefixed `N | ` per line; strip it and let the code
    // block's own gutter show the numbers, otherwise they appear twice.
    final stripped = _stripLineNumberPrefixes(content);
    if (stripped != null) {
      return CodeBlockView(
        language: lang,
        code: stripped.code,
        gutterStartLine: stripped.startAt,
      );
    }
    return CodeBlockView(language: lang, code: content);
  }

  static final RegExp _numberedLine = RegExp(r'^\s*(\d+) \|(?: (.*))?$');

  /// Detects the `N | 内容` prefixes produced by the read tools' `numberLines`
  /// and strips them. Returns null (leave content untouched) unless every line
  /// carries the prefix with strictly consecutive numbers.
  static ({String code, int startAt})? _stripLineNumberPrefixes(
    String content,
  ) {
    if (content.isEmpty) return null;
    final hasTrailingNewline = content.endsWith('\n');
    final lines = (hasTrailingNewline
            ? content.substring(0, content.length - 1)
            : content)
        .split('\n');
    int? startAt;
    var expected = 0;
    final out = <String>[];
    for (final line in lines) {
      final m = _numberedLine.firstMatch(line);
      if (m == null) return null;
      final n = int.parse(m.group(1)!);
      if (startAt == null) {
        startAt = n;
        expected = n;
      }
      if (n != expected) return null;
      expected++;
      out.add(m.group(2) ?? '');
    }
    return (
      code: out.join('\n') + (hasTrailingNewline ? '\n' : ''),
      startAt: startAt!,
    );
  }

  Widget _entryListBody(Object? files) {
    if (files is! List || files.isEmpty) {
      return const FileEditorEmptyBody();
    }
    return Column(
      children: [
        for (final e in files)
          if (e is Map) _EntryRow(entry: e.cast<String, Object?>()),
      ],
    );
  }

  Widget _fileInfoBody(Map<String, Object?> data) {
    final entries = <(String, String)>[
      ('名称', data['name']?.toString() ?? '-'),
      ('类型', data['type']?.toString() ?? '-'),
      if (data['size'] != null) ('大小', _formatSize((data['size'] as num).toInt())),
      if (data['lines'] != null) ('行数', '${data['lines']}'),
    ];
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, value) in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(label,
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ),
                  Expanded(
                    child: Text(value, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ----- result parsing -----

  Map<String, Object?>? _data() {
    final content = block.content;
    if (content is! String || content.isEmpty) return null;
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map && decoded['success'] == true) {
        final data = decoded['data'];
        if (data is Map) return data.cast<String, Object?>();
      }
    } catch (_) {}
    return null;
  }

  String? _error() {
    final content = block.content;
    if (content is String && content.isNotEmpty) {
      try {
        final decoded = jsonDecode(content);
        if (decoded is Map && decoded['error'] != null) {
          return decoded['error'].toString();
        }
      } catch (_) {}
    }
    final blockErr = block.error;
    if (blockErr != null && blockErr['message'] is String) {
      return blockErr['message'] as String;
    }
    return null;
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final Map<String, Object?> entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDir = entry['type'] == 'directory';
    final name = entry['name']?.toString() ?? '';
    final size = entry['size'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          Icon(
            isDir ? LucideIcons.folder : LucideIcons.file,
            size: 14,
            color: isDir
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall),
          ),
          if (!isDir && size is num)
            Text(_formatSize(size.toInt()),
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}


String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
