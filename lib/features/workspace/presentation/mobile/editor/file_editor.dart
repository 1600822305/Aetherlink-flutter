// One open file's editor, kept alive inside the middle-page tab IndexedStack.
// Loads the file (whole-file read, or a read-only line-range preview when it
// exceeds the plugin's 10 MB cap) and lets the user edit + save it on writable
// (SAF) backends. Find/replace works in both view and edit modes.
//
// Each instance owns a single fixed [entry] (one editor per tab). It mirrors
// its dirty state into [dirtyFilesProvider] (for the tab strip's dirty dot) and
// registers a save/discard [EditorHandle] so the tab strip can close it even
// when it isn't the visible tab.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/data/local_saf_backend.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_body.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_registry.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_text_area.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_header.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/find_replace_bar.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/find_session.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/readable_path.dart';

/// Whole-file read cap (plugin spec §3.3). Larger files fall back to a
/// read-only ranged preview of the first [_previewLines] lines.
const int _wholeFileReadCap = 10 * 1024 * 1024;
const int _previewLines = 5000;

class FileEditor extends ConsumerStatefulWidget {
  const FileEditor({super.key, required this.entry});

  final WorkspaceEntry entry;

  @override
  ConsumerState<FileEditor> createState() => _FileEditorState();
}

class _FileEditorState extends ConsumerState<FileEditor> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late final FindSession _find = FindSession(_controller, _focus);
  late Future<void> _ready;

  String _original = '';
  bool _editing = false;
  bool _saving = false;
  String? _readOnlyReason;

  bool _showFind = false;
  bool _showReplace = false;
  double _fontSize = kEditorDefaultFontSize;

  String get _path => widget.entry.path;
  bool get _dirty => _controller.text != _original;
  bool get _writable =>
      ref.read(workspacePreviewBackendProvider) is LocalSafBackend &&
      _readOnlyReason == null;

  @override
  void initState() {
    super.initState();
    _ready = _load();
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(editorRegistryProvider)
          .register(_path, EditorHandle(save: _save, discard: _discard));
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    ref.read(editorRegistryProvider).unregister(_path);
    ref.read(dirtyFilesProvider.notifier).clear(_path);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_find.query.isNotEmpty) _find.recompute();
    ref.read(dirtyFilesProvider.notifier).set(_path, dirty: _dirty);
    setState(() {});
  }

  Future<void> _load() async {
    final backend = ref.read(workspacePreviewBackendProvider);
    if (backend == null) throw StateError('没有打开的工作区');
    _editing = false;
    _showFind = false;
    _find.update('', _find.options);
    if (widget.entry.size > _wholeFileReadCap) {
      final range = await backend.readFileRange(
        widget.entry.path,
        1,
        _previewLines,
      );
      _readOnlyReason =
          '文件过大(${_fmtBytes(widget.entry.size)}),'
          '仅显示前 ${range.endLine}/${range.totalLines} 行,暂不可编辑';
      _original = range.content;
    } else {
      _readOnlyReason = null;
      _original = await backend.readFile(widget.entry.path);
    }
    _controller.text = _original;
  }

  // Drops unsaved edits (used when closing a dirty tab via "放弃").
  void _discard() {
    _original = _controller.text;
    ref.read(dirtyFilesProvider.notifier).clear(_path);
  }

  Future<bool> _save() async {
    final backend = ref.read(workspacePreviewBackendProvider);
    if (backend is! LocalSafBackend) return false;
    setState(() => _saving = true);
    try {
      await backend.writeFile(widget.entry.path, _controller.text);
      _original = _controller.text;
      ref.read(dirtyFilesProvider.notifier).clear(_path);
      _snack('已保存');
      return true;
    } catch (e) {
      _snack('保存失败:$e', error: true);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? scheme.errorContainer : null,
      ),
    );
  }

  static String _fmtBytes(int n) {
    if (n >= 1 << 20) return '${(n / (1 << 20)).toStringAsFixed(1)}MB';
    if (n >= 1 << 10) return '${(n / (1 << 10)).toStringAsFixed(1)}KB';
    return '${n}B';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EditorHeader(
            name: widget.entry.name,
            path: readableWorkspacePath(widget.entry.path),
            dirty: _dirty,
            topPad: 6,
            actions: _headerActions(),
          ),
          Divider(height: 1, color: theme.dividerColor),
          if (_showFind)
            FindReplaceBar(
              matchCount: _find.matches.length,
              currentIndex: _find.index,
              showReplace: _showReplace,
              canReplace: _editing && _writable,
              onQueryChanged: (q, o) => setState(() => _find.update(q, o)),
              onNext: () => setState(_find.next),
              onPrev: () => setState(_find.prev),
              onReplaceOne: (r) => setState(() => _find.replaceOne(r)),
              onReplaceAll: (r) => setState(() {
                _snack('替换 ${_find.replaceEverything(r)} 处');
              }),
              onToggleReplace: () =>
                  setState(() => _showReplace = !_showReplace),
              onClose: () => setState(() => _showFind = false),
            ),
          if (_readOnlyReason != null) ReadOnlyBanner(text: _readOnlyReason!),
          Expanded(
            child: EditorContent(
              ready: _ready,
              controller: _controller,
              focusNode: _focus,
              editing: _editing,
              fontSize: _fontSize,
              onFontSize: (v) => setState(() => _fontSize = v),
              onRetry: () => setState(() => _ready = _load()),
            ),
          ),
          EditorStatusBar(controller: _controller),
        ],
      ),
    );
  }

  List<Widget> _headerActions() {
    final locked = ref.watch(workspacePageLockProvider);
    return [
      IconButton(
        tooltip: locked ? '解锁页面(可横向翻页)' : '锁定页面(防止缩放误触翻页)',
        icon: Icon(locked ? LucideIcons.lock : LucideIcons.lockOpen, size: 18),
        color: locked ? Theme.of(context).colorScheme.primary : null,
        onPressed: () =>
            ref.read(workspacePageLockProvider.notifier).toggle(),
      ),
      IconButton(
        tooltip: '查找',
        icon: const Icon(LucideIcons.search, size: 18),
        onPressed: () => setState(() => _showFind = !_showFind),
      ),
      if (_writable && !_editing)
        IconButton(
          tooltip: '编辑',
          icon: const Icon(LucideIcons.pencil, size: 18),
          onPressed: () {
            setState(() => _editing = true);
            _focus.requestFocus();
          },
        ),
      if (_editing)
        IconButton(
          tooltip: '保存',
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(LucideIcons.save, size: 18),
          onPressed: (_dirty && !_saving) ? () => _save() : null,
        ),
    ];
  }
}
