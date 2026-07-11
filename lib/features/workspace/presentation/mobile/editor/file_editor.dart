// One open file's editor, kept alive inside the middle-page tab IndexedStack.
// Loads the file (whole-file read, or a read-only line-range preview when it
// exceeds the plugin's 10 MB cap) and lets the user edit + save it on writable
// (SAF) backends. Find/replace works in both view and edit modes.
//
// Each instance owns a single fixed [entry] (one editor per tab). It mirrors
// its dirty state into [dirtyFilesProvider] (for the tab strip's dirty dot) and
// registers a save/discard [EditorHandle] so the tab strip can close it even
// when it isn't the visible tab.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_body.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_language.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_limits.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_placeholders.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_registry.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_text_area.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_header.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/file_open_policy.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/image_preview.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/find_replace_bar.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/find_session.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/readable_path.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

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
  FileOpenKind _openKind = FileOpenKind.editable;

  bool _showFind = false;
  bool _showReplace = false;

  // 「跳到某行」（全局搜索结果）：token 每消费一次请求 +1，驱动只读查看器
  // 重新滚动（同一行再次跳也能触发）。
  int? _jumpLine;
  int _jumpToken = 0;
  double _fontSize = kEditorDefaultFontSize;
  bool _tooManyLinesToEdit = false;

  // Debounces the O(text) find recompute while typing with the find bar open.
  Timer? _findDebounce;

  // Live external-change watch (in-app mutations from file-ops / agent tools).
  StreamSubscription<WorkspaceChangeEvent>? _watchSub;
  // Conflict/notice banner text shown when the open file changed on disk and
  // can't be re-synced silently (unsaved edits, delete, move, non-editable).
  String? _externalNotice;
  // Whether the banner offers a 「重新加载」 action.
  bool _externalReloadable = false;
  // Guards against overlapping disk re-reads when events arrive in a burst.
  bool _checkingExternal = false;

  String get _path => widget.entry.path;
  bool get _dirty => _controller.text != _original;
  // Editing is only ever offered for small text files on a writable backend.
  bool get _writable =>
      _openKind == FileOpenKind.editable &&
      !_tooManyLinesToEdit &&
      (ref.read(workspacePreviewBackendProvider)?.capabilities.canWrite ??
          false);
  // Binary / too-large / image files render a placeholder instead of the text
  // editor, so the find bar, status bar and edit affordances are all suppressed.
  bool get _hasTextBody =>
      _openKind == FileOpenKind.editable ||
      _openKind == FileOpenKind.rangedReadOnly;

  @override
  void initState() {
    super.initState();
    _ready = _load();
    _controller.addListener(_onTextChanged);
    final backend = ref.read(workspacePreviewBackendProvider);
    if (backend != null && backend.capabilities.canWatch) {
      _watchSub = backend.watch().listen(_onWatchEvent);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(editorRegistryProvider)
          .register(_path, EditorHandle(save: _save, discard: _discard));
      final jump = ref.read(editorJumpProvider);
      if (jump != null && jump.path == _path) _consumeJump(jump);
    });
  }

  @override
  void dispose() {
    _findDebounce?.cancel();
    _watchSub?.cancel();
    _controller.removeListener(_onTextChanged);
    ref.read(editorRegistryProvider).unregister(_path);
    ref.read(dirtyFilesProvider.notifier).clear(_path);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  // Reacts to in-app file changes for *this* file. Self-writes are filtered out
  // by comparing disk content against [_original] (after a save they're equal),
  // so the editor's own save never trips the conflict banner.
  void _onWatchEvent(WorkspaceChangeEvent e) {
    if (!mounted) return;
    final isOurs = e.path == _path ||
        (e.kind == WorkspaceChangeKind.moved && e.fromPath == _path);
    if (!isOurs) return;
    switch (e.kind) {
      case WorkspaceChangeKind.deleted:
        setState(() {
          _externalNotice = '文件已被外部删除';
          _externalReloadable = false;
        });
      case WorkspaceChangeKind.moved:
        setState(() {
          _externalNotice = '文件已被外部移动或重命名，当前标签可能已失效';
          _externalReloadable = false;
        });
      case WorkspaceChangeKind.created:
      case WorkspaceChangeKind.modified:
        _handleExternalModify();
    }
  }

  // Re-reads the file and either re-syncs silently (no local edits) or raises a
  // conflict banner (unsaved edits). Non-editable kinds can't be diffed, so
  // they just get a reload affordance.
  Future<void> _handleExternalModify() async {
    if (_openKind != FileOpenKind.editable) {
      setState(() {
        _externalNotice = '文件已被外部修改';
        _externalReloadable = true;
      });
      return;
    }
    if (_checkingExternal) return;
    _checkingExternal = true;
    try {
      final backend = ref.read(workspacePreviewBackendProvider);
      if (backend == null) return;
      final disk = await backend.readFile(_path);
      if (!mounted) return;
      if (disk == _original) {
        // Our own write (or a no-op change): clear any stale notice.
        if (_externalNotice != null) setState(() => _externalNotice = null);
        return;
      }
      if (_dirty) {
        setState(() {
          _externalNotice = '文件已被外部修改，你有未保存的修改';
          _externalReloadable = true;
        });
      } else {
        setState(() {
          _original = disk;
          _controller.text = disk;
          _externalNotice = null;
        });
      }
    } catch (_) {
      // Transient read failures are ignored; the manual refresh still works.
    } finally {
      _checkingExternal = false;
    }
  }

  // Banner 「重新加载」: discard the buffer and re-read from disk.
  void _reloadFromDisk() {
    setState(() {
      _externalNotice = null;
      _externalReloadable = false;
      _ready = _load();
    });
  }

  void _onTextChanged() {
    // Dirty state flows through [dirtyFilesProvider] (deduped), so the header /
    // save button rebuild only on a dirty *transition*, watched in [build] —
    // not on every keystroke. The text area, caret highlight and status bar
    // each listen to the controller directly, so no whole-page setState is
    // needed here for typing. The find recompute is an O(text) scan, so it is
    // debounced instead of running per keystroke while the find bar is open.
    ref.read(dirtyFilesProvider.notifier).set(_path, dirty: _dirty);
    if (_find.query.isEmpty) return;
    _findDebounce?.cancel();
    _findDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      _find.recompute();
      if (_showFind) setState(() {});
    });
  }

  Future<void> _load() async {
    final backend = ref.read(workspacePreviewBackendProvider);
    if (backend == null) throw StateError('没有打开的工作区');
    _editing = false;
    _showFind = false;
    _find.update('', _find.options);
    _original = '';
    _controller.text = '';
    _tooManyLinesToEdit = false;

    final size = widget.entry.size;

    // 1. Hard size cap: refuse outright, without reading any bytes.
    if (size > kMaxOpenBytes) {
      _readOnlyReason = null;
      _openKind = FileOpenKind.tooLarge;
      return;
    }

    // 2. Content-based binary sniff over the file header (never decode the
    //    whole thing as text first — that's what froze the UI).
    final probeLen = size < kHeaderProbeBytes ? size : kHeaderProbeBytes;
    List<int> head = const [];
    if (probeLen > 0) {
      try {
        head = await backend.readFileBytes(widget.entry.path, length: probeLen);
      } on UnsupportedError {
        // Backend can't read raw bytes (e.g. the mock): fall back to treating
        // it as text rather than failing the open.
        head = const [];
      }
    }

    _openKind = classifyOpen(size: size, head: head);
    if (_openKind == FileOpenKind.binary ||
        _openKind == FileOpenKind.image) {
      _readOnlyReason = null;
      return;
    }

    // 3. Text: whole-file edit for small files, ranged read-only preview for
    //    large-but-allowed ones.
    if (_openKind == FileOpenKind.rangedReadOnly) {
      final range = await backend.readFileRange(
        widget.entry.path,
        1,
        kPreviewLines,
      );
      _readOnlyReason =
          '文件较大(${_fmtBytes(size)}),'
          '仅显示前 ${range.endLine}/${range.totalLines} 行,暂不可编辑';
      _original = range.content;
    } else {
      _original = await backend.readFile(widget.entry.path);
      // Small-by-bytes files can still have too many lines for the editable
      // whole-document TextField; keep those read-only (the virtualized
      // viewer handles them fine).
      var lines = 1;
      for (var i = 0; i < _original.length; i++) {
        if (_original.codeUnitAt(i) == 0x0A) lines++;
      }
      _tooManyLinesToEdit = lines > kMaxEditableLines;
      _readOnlyReason = _tooManyLinesToEdit
          ? '文件行数较多($lines 行),为保证流畅暂不可编辑'
          : null;
    }
    _controller.text = _original;
  }

  // The placeholder body for non-text files, or null when the editor's text
  // area should be shown.
  Widget? _placeholder() => switch (_openKind) {
        FileOpenKind.binary => EditorPlaceholders.binary(widget.entry),
        FileOpenKind.tooLarge => EditorPlaceholders.tooLarge(widget.entry),
        FileOpenKind.image => ImagePreview(
            entry: widget.entry,
            backend: ref.read(workspacePreviewBackendProvider)!,
          ),
        _ => null,
      };

  // Drops unsaved edits (used when closing a dirty tab via "放弃").
  void _discard() {
    _original = _controller.text;
    ref.read(dirtyFilesProvider.notifier).clear(_path);
  }

  Future<bool> _save() async {
    final backend = ref.read(workspacePreviewBackendProvider);
    if (backend == null || !backend.capabilities.canWrite) return false;
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
    if (error) {
      AppToast.error(context, message);
    } else {
      AppToast.info(context, message);
    }
  }

  // 消费一次跳行请求：等文件加载完再滚动，并把光标放到目标行首
  // （编辑态下 TextField 也能对上）。
  Future<void> _consumeJump(EditorJumpRequest req) async {
    ref.read(editorJumpProvider.notifier).clear();
    try {
      await _ready;
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final text = _controller.text;
    var offset = 0;
    var line = 1;
    while (line < req.line) {
      final nl = text.indexOf('\n', offset);
      if (nl < 0) break;
      offset = nl + 1;
      line++;
    }
    _controller.selection = TextSelection.collapsed(offset: offset);
    setState(() {
      _jumpLine = line;
      _jumpToken++;
    });
  }

  static String _fmtBytes(int n) {
    if (n >= 1 << 20) return '${(n / (1 << 20)).toStringAsFixed(1)}MB';
    if (n >= 1 << 10) return '${(n / (1 << 10)).toStringAsFixed(1)}KB';
    return '${n}B';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ref.listen<EditorJumpRequest?>(editorJumpProvider, (prev, next) {
      if (next != null && next.path == _path) _consumeJump(next);
    });
    // Rebuilds only on a dirty transition (set is deduped), not per keystroke.
    final dirty = ref.watch(
      dirtyFilesProvider.select((s) => s.contains(_path)),
    );
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EditorHeader(
            name: widget.entry.name,
            path: readableWorkspacePath(widget.entry.path),
            dirty: dirty,
            topPad: 6,
            actions: _headerActions(dirty),
          ),
          Divider(height: 1, color: theme.dividerColor),
          if (_hasTextBody && _showFind)
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
          if (_externalNotice != null)
            ExternalChangeBanner(
              text: _externalNotice!,
              onReload: _externalReloadable ? _reloadFromDisk : null,
              onDismiss: () => setState(() => _externalNotice = null),
            ),
          Expanded(
            child: EditorContent(
              ready: _ready,
              controller: _controller,
              focusNode: _focus,
              editing: _editing,
              fontSize: _fontSize,
              onFontSize: (v) => setState(() => _fontSize = v),
              onRetry: () => setState(() => _ready = _load()),
              placeholderBuilder: _placeholder,
              findMatches: _showFind ? _find.matches : const [],
              findIndex: _showFind ? _find.index : -1,
              jumpLine: _jumpLine,
              jumpToken: _jumpToken,
              language: languageForFileName(widget.entry.name),
            ),
          ),
          if (_hasTextBody) EditorStatusBar(controller: _controller),
        ],
      ),
    );
  }

  List<Widget> _headerActions(bool dirty) {
    final locked = ref.watch(workspacePageLockProvider);
    return [
      IconButton(
        tooltip: locked ? '解锁页面(可横向翻页)' : '锁定页面(防止缩放误触翻页)',
        icon: Icon(locked ? LucideIcons.lock : LucideIcons.lockOpen, size: 18),
        color: locked ? Theme.of(context).colorScheme.primary : null,
        onPressed: () =>
            ref.read(workspacePageLockProvider.notifier).toggle(),
      ),
      if (_hasTextBody)
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
          onPressed: (dirty && !_saving) ? () => _save() : null,
        ),
    ];
  }
}
