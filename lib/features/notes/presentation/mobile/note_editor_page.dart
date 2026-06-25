import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/app_markdown.dart';
import 'package:aetherlink_flutter/features/notes/application/notes_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

/// Two editor view modes for a note.
enum _NoteViewMode { source, preview }

/// Markdown note editor: a source view (with a formatting toolbar) and a live
/// preview rendered through the shared [AppMarkdown]. Auto-saves 2s after the
/// last edit (and on leaving), mirroring the original's debounce.
class NoteEditorPage extends ConsumerStatefulWidget {
  const NoteEditorPage({
    required this.relativePath,
    required this.title,
    super.key,
  });

  final String relativePath;
  final String title;

  @override
  ConsumerState<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends ConsumerState<NoteEditorPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  _NoteViewMode _mode = _NoteViewMode.source;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String _original = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // Best-effort final save if there are unsaved edits.
    if (_dirty) {
      final store = ref.read(notesFileStoreProvider);
      unawaited(store.write(widget.relativePath, _controller.text));
    }
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final store = ref.read(notesFileStoreProvider);
    final content = await store.read(widget.relativePath);
    if (!mounted) return;
    setState(() {
      _controller.text = content;
      _original = content;
      _loading = false;
      _dirty = false;
    });
  }

  void _onChanged(String value) {
    final dirty = value != _original;
    if (dirty != _dirty) setState(() => _dirty = dirty);
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _save);
  }

  Future<void> _save() async {
    if (_saving || !_dirty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(notesFileStoreProvider)
          .write(widget.relativePath, _controller.text);
      if (!mounted) return;
      setState(() {
        _original = _controller.text;
        _dirty = false;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('保存失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: ModelSettingsAppBar(
        title: widget.title,
        actions: [
          // Source / preview toggle.
          IconButton(
            icon: Icon(
              _mode == _NoteViewMode.source
                  ? LucideIcons.eye
                  : LucideIcons.code,
              size: 20,
            ),
            color: theme.colorScheme.onSurfaceVariant,
            tooltip: _mode == _NoteViewMode.source ? '预览' : '源码',
            onPressed: () => setState(() {
              _mode = _mode == _NoteViewMode.source
                  ? _NoteViewMode.preview
                  : _NoteViewMode.source;
            }),
          ),
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _dirty ? LucideIcons.save : LucideIcons.check,
                    size: 20,
                  ),
            color: _dirty
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            tooltip: _dirty ? '保存' : '已保存',
            onPressed: _dirty ? _save : null,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_mode == _NoteViewMode.source)
                  _MarkdownToolbar(onAction: _applyToolbar),
                Expanded(
                  child: _mode == _NoteViewMode.source
                      ? _buildSource(theme)
                      : _buildPreview(theme),
                ),
              ],
            ),
    );
  }

  Widget _buildSource(ThemeData theme) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: _onChanged,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: TextInputType.multiline,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontFamily: 'monospace',
        fontFamilyFallback: const ['monospace'],
        height: 1.5,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.all(16),
        hintText: '开始输入 Markdown…',
      ),
    );
  }

  Widget _buildPreview(ThemeData theme) {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return Center(
        child: Text(
          '（空白笔记）',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: AppMarkdown(content: _controller.text),
    );
  }

  /// Applies a toolbar formatting action to the current selection / cursor.
  void _applyToolbar(_ToolbarAction action) {
    final sel = _controller.selection;
    final text = _controller.text;
    final hasSel = sel.isValid && !sel.isCollapsed;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final selected = hasSel ? text.substring(start, end) : '';

    String newText;
    int caret;
    switch (action) {
      case _ToolbarAction.bold:
        newText = text.replaceRange(start, end, '**$selected**');
        caret = start + 2 + selected.length + (hasSel ? 2 : 0);
      case _ToolbarAction.italic:
        newText = text.replaceRange(start, end, '*$selected*');
        caret = start + 1 + selected.length + (hasSel ? 1 : 0);
      case _ToolbarAction.strike:
        newText = text.replaceRange(start, end, '~~$selected~~');
        caret = start + 2 + selected.length + (hasSel ? 2 : 0);
      case _ToolbarAction.inlineCode:
        newText = text.replaceRange(start, end, '`$selected`');
        caret = start + 1 + selected.length + (hasSel ? 1 : 0);
      case _ToolbarAction.h1:
        return _applyLinePrefix('# ');
      case _ToolbarAction.h2:
        return _applyLinePrefix('## ');
      case _ToolbarAction.bulletList:
        return _applyLinePrefix('- ');
      case _ToolbarAction.orderedList:
        return _applyLinePrefix('1. ');
      case _ToolbarAction.quote:
        return _applyLinePrefix('> ');
      case _ToolbarAction.codeBlock:
        final block = '```\n$selected\n```';
        newText = text.replaceRange(start, end, block);
        caret = start + 4 + selected.length;
      case _ToolbarAction.link:
        newText = text.replaceRange(
          start,
          end,
          '[${selected.isEmpty ? '链接文字' : selected}](url)',
        );
        caret = newText.length;
      case _ToolbarAction.divider:
        final insert = '\n---\n';
        newText = text.replaceRange(start, end, insert);
        caret = start + insert.length;
    }
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: caret.clamp(0, newText.length)),
    );
    _onChanged(newText);
    _focusNode.requestFocus();
  }

  /// Inserts [prefix] at the start of the line containing the cursor.
  void _applyLinePrefix(String prefix) {
    final sel = _controller.selection;
    final text = _controller.text;
    final pos = sel.isValid ? sel.start : text.length;
    var lineStart = pos;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }
    final newText = text.replaceRange(lineStart, lineStart, prefix);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + prefix.length),
    );
    _onChanged(newText);
    _focusNode.requestFocus();
  }
}

enum _ToolbarAction {
  h1,
  h2,
  bold,
  italic,
  strike,
  inlineCode,
  bulletList,
  orderedList,
  quote,
  codeBlock,
  link,
  divider,
}

class _MarkdownToolbar extends StatelessWidget {
  const _MarkdownToolbar({required this.onAction});

  final ValueChanged<_ToolbarAction> onAction;

  static const List<({_ToolbarAction action, IconData icon, String tip})>
  _items = [
    (action: _ToolbarAction.h1, icon: LucideIcons.heading1, tip: '一级标题'),
    (action: _ToolbarAction.h2, icon: LucideIcons.heading2, tip: '二级标题'),
    (action: _ToolbarAction.bold, icon: LucideIcons.bold, tip: '加粗'),
    (action: _ToolbarAction.italic, icon: LucideIcons.italic, tip: '斜体'),
    (
      action: _ToolbarAction.strike,
      icon: LucideIcons.strikethrough,
      tip: '删除线',
    ),
    (action: _ToolbarAction.inlineCode, icon: LucideIcons.code, tip: '行内代码'),
    (action: _ToolbarAction.bulletList, icon: LucideIcons.list, tip: '无序列表'),
    (
      action: _ToolbarAction.orderedList,
      icon: LucideIcons.listOrdered,
      tip: '有序列表',
    ),
    (action: _ToolbarAction.quote, icon: LucideIcons.quote, tip: '引用'),
    (action: _ToolbarAction.codeBlock, icon: LucideIcons.squareCode, tip: '代码块'),
    (action: _ToolbarAction.link, icon: LucideIcons.link, tip: '链接'),
    (action: _ToolbarAction.divider, icon: LucideIcons.minus, tip: '分割线'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            for (final item in _items)
              IconButton(
                icon: Icon(item.icon, size: 18),
                color: theme.colorScheme.onSurfaceVariant,
                tooltip: item.tip,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onAction(item.action);
                },
              ),
          ],
        ),
      ),
    );
  }
}
