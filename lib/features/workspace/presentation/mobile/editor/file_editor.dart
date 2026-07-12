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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/application/editor_auto_save.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_body.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_diff_view.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_edit_ops.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_language.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_limits.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_placeholders.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_registry.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_settings_page.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_text_area.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_header.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/file_open_policy.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/image_preview.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/find_replace_bar.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/find_session.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/readable_path.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/workspace_file_share.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

class FileEditor extends ConsumerStatefulWidget {
  const FileEditor({super.key, required this.entry});

  final WorkspaceEntry entry;

  @override
  ConsumerState<FileEditor> createState() => _FileEditorState();
}

class _FileEditorState extends ConsumerState<FileEditor>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _undo = UndoHistoryController();
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

  // 自动保存防抖（编辑停顿后触发）；延时改变时重建。
  AutoSaveDebouncer? _autoSave;

  // Live external-change watch (in-app mutations from file-ops / agent tools).
  StreamSubscription<WorkspaceChangeEvent>? _watchSub;
  // Conflict/notice banner text shown when the open file changed on disk and
  // can't be re-synced silently (unsaved edits, delete, move, non-editable).
  String? _externalNotice;
  // Whether the banner offers a 「重新加载」 action.
  bool _externalReloadable = false;
  // The disk content behind a conflict banner, enabling the 「对比」 diff
  // sheet (only set when there are unsaved local edits to compare against).
  String? _conflictDisk;
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
  // 自动保存的前提：可写且不处于外部修改冲突（冲突时静默写盘会
  // 覆盖磁盘版本，必须等用户在 banner 里做决定）。
  bool get _canAutoSave =>
      _writable && _externalNotice == null && _conflictDisk == null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fontSize = ref.read(editorSettingsProvider).fontSize;
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
    WidgetsBinding.instance.removeObserver(this);
    _autoSave?.dispose();
    _findDebounce?.cancel();
    _watchSub?.cancel();
    _controller.removeListener(_onTextChanged);
    ref.read(editorRegistryProvider).unregister(_path);
    ref.read(dirtyFilesProvider.notifier).clear(_path);
    _controller.dispose();
    _undo.dispose();
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
        if (_externalNotice != null) {
          setState(() {
            _externalNotice = null;
            _conflictDisk = null;
          });
        }
        return;
      }
      if (_dirty) {
        setState(() {
          _externalNotice = '文件已被外部修改，你有未保存的修改';
          _externalReloadable = true;
          _conflictDisk = disk;
        });
      } else {
        setState(() {
          _original = disk;
          _controller.text = disk;
          _externalNotice = null;
          _conflictDisk = null;
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
      _conflictDisk = null;
      _ready = _load();
    });
  }

  // Banner 「对比」: full-height diff sheet (local buffer vs disk), resolving
  // to reload or keep-mine.
  Future<void> _showConflictDiff() async {
    final disk = _conflictDisk;
    if (disk == null) return;
    final resolution = await showConflictDiffSheet(
      context,
      fileName: widget.entry.name,
      local: _controller.text,
      disk: disk,
    );
    if (!mounted) return;
    switch (resolution) {
      case DiffResolution.reloadDisk:
        _reloadFromDisk();
      case DiffResolution.keepMine:
        setState(() {
          _externalNotice = null;
          _conflictDisk = null;
        });
      case null:
        break;
    }
  }

  void _onTextChanged() {
    // Dirty state flows through [dirtyFilesProvider] (deduped), so the header /
    // save button rebuild only on a dirty *transition*, watched in [build] —
    // not on every keystroke. The text area, caret highlight and status bar
    // each listen to the controller directly, so no whole-page setState is
    // needed here for typing. The find recompute is an O(text) scan, so it is
    // debounced instead of running per keystroke while the find bar is open.
    ref.read(dirtyFilesProvider.notifier).set(_path, dirty: _dirty);
    _scheduleAutoSave();
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
        FileOpenKind.binary => EditorPlaceholders.binary(
            widget.entry,
            onOpenExternally: _shareEntry,
          ),
        FileOpenKind.tooLarge => EditorPlaceholders.tooLarge(
            widget.entry,
            onOpenExternally: _shareEntry,
          ),
        FileOpenKind.image => ImagePreview(
            entry: widget.entry,
            backend: ref.read(workspacePreviewBackendProvider)!,
          ),
        _ => null,
      };

  void _shareEntry() =>
      shareWorkspaceFile(context, ref, entry: widget.entry);

  // Drops unsaved edits (used when closing a dirty tab via "放弃").
  void _discard() {
    _original = _controller.text;
    ref.read(dirtyFilesProvider.notifier).clear(_path);
  }

  Future<bool> _save({bool notify = true}) async {
    final backend = ref.read(workspacePreviewBackendProvider);
    if (backend == null || !backend.capabilities.canWrite) return false;
    _autoSave?.cancel();
    setState(() => _saving = true);
    try {
      await backend.writeFile(widget.entry.path, _controller.text);
      _original = _controller.text;
      ref.read(dirtyFilesProvider.notifier).clear(_path);
      if (notify) _snack('已保存');
      return true;
    } catch (e) {
      _snack('保存失败:$e', error: true);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // 编辑时排一次自动保存（开关关闭 / 不可写 / 冲突中则取消待触发项）。
  void _scheduleAutoSave() {
    final settings = ref.read(editorSettingsProvider);
    if (!settings.autoSave || !_editing || !_dirty || !_canAutoSave) {
      _autoSave?.cancel();
      return;
    }
    final delay = Duration(seconds: settings.autoSaveDelaySecs);
    if (_autoSave == null || _autoSave!.delay != delay) {
      _autoSave?.cancel();
      _autoSave = AutoSaveDebouncer(delay: delay, onFire: _fireAutoSave);
    }
    _autoSave!.notifyEdit();
  }

  void _fireAutoSave() {
    if (!mounted || _saving) return;
    if (!_editing || !_dirty || !_canAutoSave) return;
    if (!ref.read(editorSettingsProvider).autoSave) return;
    _save(notify: false);
  }

  // app 切后台时兼顾未触发的自动保存，避免手机上切走丢编辑。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.hidden &&
        state != AppLifecycleState.paused) {
      return;
    }
    if (!_dirty || _saving || !_canAutoSave) return;
    if (!ref.read(editorSettingsProvider).autoSave) return;
    _save(notify: false);
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
    _jumpToLine(req.line);
  }

  // 把光标移到目标行首并请求滚动（同时驱动只读查看器与编辑态 TextField）。
  // [target] 是 1-based 行号，超出范围会被夹到有效行。
  void _jumpToLine(int target) {
    final text = _controller.text;
    var offset = 0;
    var line = 1;
    while (line < target) {
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

  // 状态栏点击：弹输入框，跳到用户输入的行。
  Future<void> _promptJumpToLine(int lineCount) async {
    final target = await showJumpToLineDialog(context, maxLine: lineCount);
    if (target == null || !mounted) return;
    _jumpToLine(target);
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
    final editorSettings = ref.watch(editorSettingsProvider);
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
            actions: _headerActions(),
            onTapTitle: _showPathPanel,
          ),
          if (_hasTextBody) EditorToolbar(children: _toolbarButtons(dirty)),
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
              history: ref.watch(findHistoryProvider),
              onCommitQuery: (q) =>
                  ref.read(findHistoryProvider.notifier).add(q),
            ),
          if (_readOnlyReason != null) ReadOnlyBanner(text: _readOnlyReason!),
          if (_externalNotice != null)
            ExternalChangeBanner(
              text: _externalNotice!,
              onReload: _externalReloadable ? _reloadFromDisk : null,
              onDiff: _conflictDisk != null ? _showConflictDiff : null,
              onDismiss: () => setState(() {
                _externalNotice = null;
                _conflictDisk = null;
              }),
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
              language: editorSettings.syntaxHighlight
                  ? languageForFileName(widget.entry.name)
                  : null,
              commentPrefix: lineCommentForLanguage(
                languageForFileName(widget.entry.name),
              ),
              undoController: _undo,
              indentUnit: editorSettings.indentUnit,
              softWrap: editorSettings.softWrap,
              autoClosePairs: editorSettings.autoClosePairs,
              autoIndent: editorSettings.autoIndent,
              currentLineHighlight: editorSettings.currentLineHighlight,
            ),
          ),
          if (_hasTextBody)
            EditorStatusBar(
              controller: _controller,
              onTapCaret: _promptJumpToLine,
            ),
        ],
      ),
    );
  }

  // 头部只放开关型按钮（编辑态切换/锁定页面）；其余功能性按钮统一在
  // 下方可横向滚动的工具条里。
  List<Widget> _headerActions() {
    final locked = ref.watch(workspacePageLockProvider);
    final primary = Theme.of(context).colorScheme.primary;
    return [
      if (_writable)
        IconButton(
          tooltip: _editing ? '退出编辑' : '编辑',
          icon: Icon(
            _editing ? LucideIcons.pencilOff : LucideIcons.pencil,
            size: 18,
          ),
          color: _editing ? primary : null,
          onPressed: _toggleEditing,
        ),
      IconButton(
        tooltip: locked ? '解锁页面(可横向翻页)' : '锁定页面(防止缩放误触翻页)',
        icon: Icon(locked ? LucideIcons.lock : LucideIcons.lockOpen, size: 18),
        color: locked ? primary : null,
        onPressed: () =>
            ref.read(workspacePageLockProvider.notifier).toggle(),
      ),
      PopupMenuButton<String>(
        tooltip: '更多',
        icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
        onSelected: (value) {
          if (value == 'settings') showEditorSettingsPage(context);
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'settings',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(LucideIcons.settings2, size: 18),
              title: Text('编辑器设置'),
            ),
          ),
        ],
      ),
    ];
  }

  // 编辑态开关：退出时若有未保存修改，先问保存/放弃/取消。
  Future<void> _toggleEditing() async {
    if (!_editing) {
      setState(() => _editing = true);
      _focus.requestFocus();
      return;
    }
    if (_dirty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('退出编辑'),
          content: const Text('有未保存的修改，退出前要保存吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('discard'),
              child: const Text('放弃修改'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop('save'),
              child: const Text('保存'),
            ),
          ],
        ),
      );
      if (!mounted || choice == null) return;
      if (choice == 'save') {
        if (!await _save()) return;
        if (!mounted) return;
      } else {
        _controller.text = _original;
        ref.read(dirtyFilesProvider.notifier).clear(_path);
      }
    }
    setState(() => _editing = false);
    _focus.unfocus();
  }

  // 点击头部文件名/路径：弹面板展示完整文件名与可读路径，支持一键复制。
  Future<void> _showPathPanel() async {
    final readable = readableWorkspacePath(widget.entry.path);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CopyRow(
              label: '文件名',
              value: widget.entry.name,
              onCopied: () => _snack('已复制文件名'),
            ),
            const Divider(height: 1, indent: 20, endIndent: 20),
            _CopyRow(
              label: '路径',
              value: readable,
              onCopied: () => _snack('已复制路径'),
            ),
          ],
        ),
      ),
    );
  }

  IconButton _toolButton({
    required String tooltip,
    required Widget icon,
    VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      icon: icon,
      onPressed: onPressed,
    );
  }

  List<Widget> _toolbarButtons(bool dirty) {
    return [
      _toolButton(
        tooltip: '查找',
        icon: const Icon(LucideIcons.search, size: 18),
        onPressed: () => setState(() => _showFind = !_showFind),
      ),
      if (_editing)
        ValueListenableBuilder<UndoHistoryValue>(
          valueListenable: _undo,
          builder: (context, value, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _toolButton(
                tooltip: '撤销',
                icon: const Icon(LucideIcons.undo2, size: 18),
                onPressed: value.canUndo
                    ? () {
                        _undo.undo();
                        _focus.requestFocus();
                      }
                    : null,
              ),
              _toolButton(
                tooltip: '重做',
                icon: const Icon(LucideIcons.redo2, size: 18),
                onPressed: value.canRedo
                    ? () {
                        _undo.redo();
                        _focus.requestFocus();
                      }
                    : null,
              ),
            ],
          ),
        ),
      if (_editing &&
          lineCommentForLanguage(languageForFileName(widget.entry.name)) !=
              null)
        _toolButton(
          tooltip: '注释切换 (Ctrl+/)',
          icon: const Icon(LucideIcons.squareSlash, size: 18),
          onPressed: () {
            final prefix = lineCommentForLanguage(
              languageForFileName(widget.entry.name),
            );
            if (prefix == null) return;
            _controller.value = toggleLineComment(_controller.value, prefix);
            _focus.requestFocus();
          },
        ),
      if (_editing)
        _toolButton(
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

/// 路径面板里的一行：标签 + 可换行完整值 + 复制按钮。
class _CopyRow extends StatelessWidget {
  const _CopyRow({
    required this.label,
    required this.value,
    required this.onCopied,
  });

  final String label;
  final String value;
  final VoidCallback onCopied;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          IconButton(
            tooltip: '复制$label',
            visualDensity: VisualDensity.compact,
            icon: const Icon(LucideIcons.copy, size: 17),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              onCopied();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
