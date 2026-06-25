import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/app_markdown.dart';
import 'package:aetherlink_flutter/features/notes/application/notes_controller.dart';
import 'package:aetherlink_flutter/features/notes/domain/note_outline.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

/// The three editor view modes, mirroring the original web editor's
/// 源码 / 预览 / 只读 segmented switch.
///
/// Flutter has no WYSIWYG rich-markdown editor, so [preview] and [read] both
/// render through [AppMarkdown]; [read] additionally hides every editing
/// affordance for a distraction-free reading view.
enum _NoteViewMode { source, preview, read }

/// Markdown note editor mirroring the original web editor: a top sub-toolbar
/// (character count, zoom controls and a 源码/预览/只读 switch), a source view
/// with a formatting toolbar, and a live preview rendered through the shared
/// [AppMarkdown]. Font size is driven by a zoom scale (buttons + pinch).
/// Auto-saves 2s after the last edit (and on leaving), mirroring the
/// original's debounce.
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
  final UndoHistoryController _undoController = UndoHistoryController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _debounce;

  _NoteViewMode _mode = _NoteViewMode.source;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String _original = '';

  // Font zoom, mirroring the web editor's pinch-to-zoom (0.5×–3×, 0.1 steps).
  static const double _minScale = 0.5;
  static const double _maxScale = 3.0;
  static const double _scaleStep = 0.1;
  double _scale = 1.0;
  double _gestureBaseScale = 1.0;

  bool get _canZoomIn => _scale < _maxScale;
  bool get _canZoomOut => _scale > _minScale;

  void _setScale(double value) {
    final clamped = value.clamp(_minScale, _maxScale);
    if (clamped != _scale) setState(() => _scale = clamped);
  }

  void _zoomIn() => _setScale(_scale + _scaleStep);
  void _zoomOut() => _setScale(_scale - _scaleStep);
  void _resetZoom() => _setScale(1.0);

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
    _undoController.dispose();
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
    final showOutline = ref.watch(notesShowOutlineProvider);
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: showOutline ? _buildOutlineDrawer(theme) : null,
      appBar: ModelSettingsAppBar(
        title: widget.title,
        actions: [
          if (showOutline)
            IconButton(
              icon: const Icon(LucideIcons.list, size: 20),
              color: theme.colorScheme.onSurfaceVariant,
              tooltip: '目录大纲',
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          if (_dirty && !_saving)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text(
                  '未保存',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_dirty ? LucideIcons.save : LucideIcons.check, size: 20),
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
                _EditorSubToolbar(
                  charCount: _controller,
                  scale: _scale,
                  canZoomIn: _canZoomIn,
                  canZoomOut: _canZoomOut,
                  onZoomIn: _zoomIn,
                  onZoomOut: _zoomOut,
                  onResetZoom: _resetZoom,
                  mode: _mode,
                  onModeChanged: (m) => setState(() => _mode = m),
                ),
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return TextField(
      controller: _controller,
      undoController: _undoController,
      focusNode: _focusNode,
      onChanged: _onChanged,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: TextInputType.multiline,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontFamily: 'monospace',
        fontFamilyFallback: const ['monospace'],
        fontSize: 14 * _scale,
        height: 1.5,
      ),
      decoration: InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
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
    final mq = MediaQuery.of(context);
    return GestureDetector(
      onScaleStart: (_) => _gestureBaseScale = _scale,
      onScaleUpdate: (details) {
        if (details.scale == 1.0) return; // pan, not a pinch
        _setScale(_gestureBaseScale * details.scale);
      },
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + mq.padding.bottom),
        // Scale rendered text by reusing the platform text-scaler knob.
        child: MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(_scale)),
          child: AppMarkdown(content: _controller.text),
        ),
      ),
    );
  }

  /// The table-of-contents drawer: ATX headings parsed live from the source,
  /// indented by level. Tapping one jumps the cursor to that heading.
  Widget _buildOutlineDrawer(ThemeData theme) {
    final headings = parseOutline(_controller.text);
    return Drawer(
      width: 280,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.list,
                    size: 18,
                    color: theme.colorScheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '目录大纲',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            Expanded(
              child: headings.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          '暂无目录\n添加 # 标题后在此显示',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: headings.length,
                      itemBuilder: (context, index) {
                        final h = headings[index];
                        return InkWell(
                          onTap: () => _jumpToHeading(h),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              16.0 + (h.level - 1) * 14,
                              10,
                              16,
                              10,
                            ),
                            child: Text(
                              h.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: h.level == 1
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: h.level == 1
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Closes the outline drawer, switches to source mode and moves the cursor to
  /// the tapped heading so the editor scrolls it into view.
  void _jumpToHeading(NoteHeading heading) {
    Navigator.of(context).pop(); // close the drawer
    setState(() => _mode = _NoteViewMode.source);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final offset = heading.offset.clamp(0, _controller.text.length);
      _controller.selection = TextSelection.collapsed(offset: offset);
      _focusNode.requestFocus();
    });
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
      case _ToolbarAction.underline:
        // Markdown has no native underline; embed an HTML <u> tag.
        newText = text.replaceRange(start, end, '<u>$selected</u>');
        caret = start + 3 + selected.length + (hasSel ? 4 : 0);
      case _ToolbarAction.undo:
        return _undo();
      case _ToolbarAction.redo:
        return _redo();
      case _ToolbarAction.h1:
        return _applyBlockPrefix('# ');
      case _ToolbarAction.h2:
        return _applyBlockPrefix('## ');
      case _ToolbarAction.h3:
        return _applyBlockPrefix('### ');
      case _ToolbarAction.paragraph:
        return _applyBlockPrefix(null);
      case _ToolbarAction.bulletList:
        return _applyBlockPrefix('- ');
      case _ToolbarAction.orderedList:
        return _applyBlockPrefix('1. ');
      case _ToolbarAction.taskList:
        return _applyBlockPrefix('- [ ] ');
      case _ToolbarAction.quote:
        return _applyBlockPrefix('> ');
      case _ToolbarAction.codeBlock:
        final block = '```\n$selected\n```';
        newText = text.replaceRange(start, end, block);
        caret = start + 4 + selected.length;
      case _ToolbarAction.table:
        const tpl = '\n| 列 1 | 列 2 |\n| --- | --- |\n| 内容 | 内容 |\n';
        newText = text.replaceRange(start, end, tpl);
        caret = start + tpl.length;
      case _ToolbarAction.math:
        // Block math fence; place the caret on the empty middle line.
        final body = selected.isEmpty ? '' : selected;
        final insert = '\n\$\$\n$body\n\$\$\n';
        newText = text.replaceRange(start, end, insert);
        caret = start + 4 + body.length; // after "\n$$\n" + any selection
      case _ToolbarAction.link:
        return _applyLink(text, start, end, selected);
      case _ToolbarAction.divider:
        final insert = '\n---\n';
        newText = text.replaceRange(start, end, insert);
        caret = start + insert.length;
    }
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: caret.clamp(0, newText.length),
      ),
    );
    _onChanged(newText);
    _focusNode.requestFocus();
  }

  /// Inserts a link, selecting the `url` placeholder so it can be typed over.
  void _applyLink(String text, int start, int end, String selected) {
    final label = selected.isEmpty ? '链接文字' : selected;
    final inserted = '[$label](url)';
    final newText = text.replaceRange(start, end, inserted);
    final urlStart = start + 1 + label.length + 2; // after "[label]("
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: urlStart,
        extentOffset: urlStart + 3, // selects "url"
      ),
    );
    _onChanged(newText);
    _focusNode.requestFocus();
  }

  void _undo() {
    _undoController.undo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onChanged(_controller.text);
    });
  }

  void _redo() {
    _undoController.redo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onChanged(_controller.text);
    });
  }

  /// Detects the leading block-level Markdown prefix of [line], if any
  /// (heading, bullet/ordered/task list, or blockquote).
  String _detectBlockPrefix(String line) {
    final ordered = RegExp(r'^\d+\. ').firstMatch(line);
    if (ordered != null) return ordered.group(0)!;
    for (final p in const ['- [ ] ', '### ', '## ', '# ', '- ', '> ']) {
      if (line.startsWith(p)) return p;
    }
    return '';
  }

  /// Whether [existing] is the same *kind* of block prefix as [target]
  /// (so re-applying it toggles the prefix off rather than stacking).
  bool _samePrefixKind(String existing, String target) {
    if (existing.isEmpty) return false;
    final ordered = RegExp(r'^\d+\. $');
    if (ordered.hasMatch(target)) return ordered.hasMatch(existing);
    return existing == target;
  }

  /// Applies a block-level [prefix] to every line in the selection, toggling it
  /// off if already present and replacing any conflicting block prefix.
  /// A null [prefix] strips the existing prefix (the "正文/paragraph" action).
  void _applyBlockPrefix(String? prefix) {
    final sel = _controller.selection;
    final text = _controller.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : start;

    var lineStart = start;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }
    var lineEnd = end;
    while (lineEnd < text.length && text[lineEnd] != '\n') {
      lineEnd++;
    }

    final lines = text.substring(lineStart, lineEnd).split('\n');
    final newLines = lines.map((line) {
      final existing = _detectBlockPrefix(line);
      final body = line.substring(existing.length);
      if (prefix == null) return body;
      if (_samePrefixKind(existing, prefix)) return body;
      return '$prefix$body';
    }).toList();

    final replaced = newLines.join('\n');
    final newText = text.replaceRange(lineStart, lineEnd, replaced);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: lineStart,
        extentOffset: lineStart + replaced.length,
      ),
    );
    _onChanged(newText);
    _focusNode.requestFocus();
  }
}

enum _ToolbarAction {
  h1,
  h2,
  h3,
  paragraph,
  bold,
  italic,
  underline,
  strike,
  inlineCode,
  bulletList,
  orderedList,
  taskList,
  quote,
  codeBlock,
  table,
  math,
  link,
  divider,
  undo,
  redo,
}

/// The right-aligned sub-toolbar above the editor: live character count, zoom
/// controls (− / percent / + / reset) and the 源码 / 预览 / 只读 view switch —
/// mirroring the original web editor's top bar.
class _EditorSubToolbar extends StatelessWidget {
  const _EditorSubToolbar({
    required this.charCount,
    required this.scale,
    required this.canZoomIn,
    required this.canZoomOut,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
    required this.mode,
    required this.onModeChanged,
  });

  final TextEditingController charCount;
  final double scale;
  final bool canZoomIn;
  final bool canZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;
  final _NoteViewMode mode;
  final ValueChanged<_NoteViewMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          children: [
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: charCount,
              builder: (context, value, _) => Text(
                '${value.text.runes.length} 字符',
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
            ),
            const SizedBox(width: 12),
            _IconBtn(
              icon: LucideIcons.zoomOut,
              tooltip: '缩小',
              color: muted,
              onPressed: canZoomOut ? onZoomOut : null,
            ),
            SizedBox(
              width: 40,
              child: Text(
                '${(scale * 100).round()}%',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
            ),
            _IconBtn(
              icon: LucideIcons.zoomIn,
              tooltip: '放大',
              color: muted,
              onPressed: canZoomIn ? onZoomIn : null,
            ),
            _IconBtn(
              icon: LucideIcons.rotateCcw,
              tooltip: '重置缩放',
              color: muted,
              onPressed: scale == 1.0 ? null : onResetZoom,
            ),
            const SizedBox(width: 12),
            _ModeSwitch(mode: mode, onChanged: onModeChanged),
          ],
        ),
      ),
    );
  }
}

/// A compact icon button sized for the sub-toolbar.
class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 16),
      color: color,
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}

/// The segmented 源码 / 预览 / 只读 switch (the original's MUI ButtonGroup).
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  final _NoteViewMode mode;
  final ValueChanged<_NoteViewMode> onChanged;

  static const _segments = [
    (mode: _NoteViewMode.source, icon: LucideIcons.code2, label: '源码'),
    (mode: _NoteViewMode.preview, icon: LucideIcons.eye, label: '预览'),
    (mode: _NoteViewMode.read, icon: LucideIcons.fileText, label: '只读'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.primary),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final seg in _segments) ...[
            if (seg.mode != _NoteViewMode.source)
              SizedBox(
                width: 1,
                height: 28,
                child: ColoredBox(
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                ),
              ),
            _Segment(
              icon: seg.icon,
              label: seg.label,
              selected: mode == seg.mode,
              onTap: () => onChanged(seg.mode),
            ),
          ],
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = selected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? theme.colorScheme.primary : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkdownToolbar extends StatelessWidget {
  const _MarkdownToolbar({required this.onAction});

  final ValueChanged<_ToolbarAction> onAction;

  static const List<({_ToolbarAction action, IconData icon, String tip})>
  _items = [
    (action: _ToolbarAction.h1, icon: LucideIcons.heading1, tip: '一级标题'),
    (action: _ToolbarAction.h2, icon: LucideIcons.heading2, tip: '二级标题'),
    (action: _ToolbarAction.h3, icon: LucideIcons.heading3, tip: '三级标题'),
    (action: _ToolbarAction.paragraph, icon: LucideIcons.pilcrow, tip: '正文'),
    (action: _ToolbarAction.bold, icon: LucideIcons.bold, tip: '加粗'),
    (action: _ToolbarAction.italic, icon: LucideIcons.italic, tip: '斜体'),
    (action: _ToolbarAction.underline, icon: LucideIcons.underline, tip: '下划线'),
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
    (
      action: _ToolbarAction.taskList,
      icon: LucideIcons.listChecks,
      tip: '任务清单',
    ),
    (action: _ToolbarAction.quote, icon: LucideIcons.quote, tip: '引用'),
    (
      action: _ToolbarAction.codeBlock,
      icon: LucideIcons.squareCode,
      tip: '代码块',
    ),
    (action: _ToolbarAction.table, icon: LucideIcons.table, tip: '表格'),
    (action: _ToolbarAction.math, icon: LucideIcons.sigma, tip: '数学公式'),
    (action: _ToolbarAction.link, icon: LucideIcons.link, tip: '链接'),
    (action: _ToolbarAction.divider, icon: LucideIcons.minus, tip: '分割线'),
    (action: _ToolbarAction.undo, icon: LucideIcons.undo2, tip: '撤销'),
    (action: _ToolbarAction.redo, icon: LucideIcons.redo2, tip: '重做'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        // Auto-flowing grid so every button is visible without horizontal
        // scrolling (which users couldn't discover).
        child: Wrap(
          spacing: 2,
          runSpacing: 2,
          children: [
            for (final item in _items)
              IconButton(
                icon: Icon(item.icon, size: 18),
                color: theme.colorScheme.onSurfaceVariant,
                tooltip: item.tip,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
                padding: EdgeInsets.zero,
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
