// The middle-page file editor. Loads the selected file (whole-file read, or a
// read-only line-range preview when it exceeds the plugin's 10 MB cap), and
// lets the user edit + save it on writable (SAF) backends. Find/replace works
// in both view and edit modes. Dirty edits are guarded on close / file switch.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/data/local_saf_backend.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_body.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_header.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/find_replace_bar.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/find_session.dart';

/// Whole-file read cap (plugin spec §3.3). Larger files fall back to a
/// read-only ranged preview of the first [_previewLines] lines.
const int _wholeFileReadCap = 10 * 1024 * 1024;
const int _previewLines = 5000;

class FileEditor extends ConsumerStatefulWidget {
  const FileEditor({super.key, required this.entry, required this.topInset});

  final WorkspaceEntry entry;
  final double topInset;

  @override
  ConsumerState<FileEditor> createState() => _FileEditorState();
}

class _FileEditorState extends ConsumerState<FileEditor> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late final FindSession _find = FindSession(_controller, _focus);
  late WorkspaceEntry _guarded;
  late Future<void> _ready;

  String _original = '';
  bool _editing = false;
  bool _saving = false;
  String? _readOnlyReason;

  bool _showFind = false;
  bool _showReplace = false;

  bool get _dirty => _controller.text != _original;
  bool get _writable =>
      ref.read(workspacePreviewBackendProvider) is LocalSafBackend &&
      _readOnlyReason == null;

  @override
  void initState() {
    super.initState();
    _guarded = widget.entry;
    _ready = _load();
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(FileEditor old) {
    super.didUpdateWidget(old);
    if (widget.entry.path == _guarded.path) return;
    if (!_dirty) {
      _guarded = widget.entry;
      setState(() => _ready = _load());
      return;
    }
    // Unsaved edits: bounce the selection back, then ask what to do.
    final target = widget.entry;
    ref.read(selectedWorkspaceFileProvider.notifier).select(_guarded);
    WidgetsBinding.instance.addPostFrameCallback((_) => _confirmSwitch(target));
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_find.query.isNotEmpty) _find.recompute();
    setState(() {});
  }

  Future<void> _load() async {
    final backend = ref.read(workspacePreviewBackendProvider);
    if (backend == null) throw StateError('没有打开的工作区');
    _editing = false;
    _showFind = false;
    _find.update('', _find.options);
    if (widget.entry.size > _wholeFileReadCap) {
      final range =
          await backend.readFileRange(widget.entry.path, 1, _previewLines);
      _readOnlyReason = '文件过大(${_fmtBytes(widget.entry.size)}),'
          '仅显示前 ${range.endLine}/${range.totalLines} 行,暂不可编辑';
      _original = range.content;
    } else {
      _readOnlyReason = null;
      _original = await backend.readFile(widget.entry.path);
    }
    _controller.text = _original;
  }

  Future<void> _confirmSwitch(WorkspaceEntry target) async {
    final action = await showUnsavedDialog(context, _guarded.name);
    if (action == LeaveAction.cancel) return;
    if (action == LeaveAction.save) {
      if (!await _save()) return;
    } else {
      _original = _controller.text; // discard → clear dirty so no re-bounce
    }
    if (mounted) {
      ref.read(selectedWorkspaceFileProvider.notifier).select(target);
    }
  }

  Future<void> _close() async {
    if (_dirty) {
      final action = await showUnsavedDialog(context, _guarded.name);
      if (action == LeaveAction.cancel) return;
      if (action == LeaveAction.save && !await _save()) return;
    }
    if (mounted) {
      ref.read(selectedWorkspaceFileProvider.notifier).clear();
    }
  }

  Future<bool> _save() async {
    final backend = ref.read(workspacePreviewBackendProvider);
    if (backend is! LocalSafBackend) return false;
    setState(() => _saving = true);
    try {
      await backend.writeFile(widget.entry.path, _controller.text);
      _original = _controller.text;
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
    final topPad = MediaQuery.paddingOf(context).top + widget.topInset + 8;
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EditorHeader(
              name: widget.entry.name,
              path: widget.entry.path,
              dirty: _dirty,
              topPad: topPad,
              actions: _headerActions(),
              onClose: _close,
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
                onRetry: () => setState(() => _ready = _load()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _headerActions() {
    return [
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
