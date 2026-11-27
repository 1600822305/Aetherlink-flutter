// 内置浏览器页（布局参考 kelivo）：
// - 手机：网页铺满，底部悬浮玻璃工具条（后退 · 地址胶囊 · 标签数 · 更多），
//   标签页用全屏卡片网格切换；
// - 宽屏：顶部标签条 + 导航/地址/操作工具栏。
// 实时渲染智能体正在用的同一个 WebView（headless 转可见 + keepAlive）。
// 用户在智能体的标签上导航即接管（智能体暂停），点「交回给智能体」恢复。

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_browser/aetherlink_browser.dart';
import 'package:aetherlink_flutter/features/browser/presentation/browser_library_views.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/browser/browser_library.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/browser/browser_tool.dart';

/// 用户标签持久化：`<应用支持目录>/browser/user_tabs.json`，
/// 记录用户自己开的标签（id、URL）和最后选中的标签。智能体的标签
/// 属于对话，不在这里保存。
class _UserTabStore {
  static Future<File> _file() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}/browser');
    await dir.create(recursive: true);
    return File('${dir.path}/user_tabs.json');
  }

  static Future<({List<(String, String)> tabs, String? selected})>
  load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return (tabs: <(String, String)>[], selected: null);
      final data = jsonDecode(await file.readAsString());
      if (data is! Map || data['version'] != 1) {
        return (tabs: <(String, String)>[], selected: null);
      }
      final tabs = <(String, String)>[
        for (final t in (data['tabs'] as List? ?? const []))
          if (t is Map && t['id'] is String && t['url'] is String)
            (t['id'] as String, t['url'] as String),
      ];
      return (tabs: tabs, selected: data['selected'] as String?);
    } catch (_) {
      return (tabs: <(String, String)>[], selected: null);
    }
  }

  static Future<void> _writes = Future<void>.value();

  /// 串行写，先写临时文件再替换，避免半截文件。
  static Future<void> save(List<(String, String)> tabs, String? selected) {
    final encoded = jsonEncode({
      'version': 1,
      'selected': selected,
      'tabs': [
        for (final (id, url) in tabs) {'id': id, 'url': url},
      ],
    });
    return _writes = _writes.then((_) async {
      try {
        final file = await _file();
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(encoded, flush: true);
        await tmp.rename(file.path);
      } catch (_) {}
    });
  }
}

class BrowserCoDrivePage extends StatefulWidget {
  const BrowserCoDrivePage({super.key});

  @override
  State<BrowserCoDrivePage> createState() => _BrowserCoDrivePageState();
}

/// 一个标签（会话条目或尚未打开页面的新标签）。
class _TabItem {
  const _TabItem(this.id, this.info);

  final String id;
  final BrowserSessionInfo? info;
}

/// 当前帧要展示的标签。
class _View {
  const _View({
    required this.id,
    required this.info,
    required this.session,
    required this.tabs,
  });

  final String id;
  final BrowserSessionInfo? info;
  final HeadlessBrowserSession? session;
  final List<_TabItem> tabs;
}

class _BrowserCoDrivePageState extends State<BrowserCoDrivePage> {
  final BrowserSessionManager _manager = sharedBrowserManager();
  final TextEditingController _address = TextEditingController();
  final FocusNode _addressFocus = FocusNode();
  final ValueNotifier<double> _progress = ValueNotifier<double>(1);
  final Map<String, Uint8List> _thumbs = {};
  String? _selectedId;
  String? _shownId;
  String? _currentId;
  bool _editing = false;
  bool _showTabs = false;
  bool _exiting = false;

  /// 真正退出浏览器页（PopScope 默认拦截返回键用于网页后退）。
  void _exit() {
    setState(() => _exiting = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  /// 用户新开、尚未加载页面的标签（显示起始页）。
  String? _draftId;
  int _userTabSeq = 0;

  Timer? _saveTimer;
  bool _restored = false;
  final Set<String> _reopening = {};

  /// 用户自己开的标签放在独立作用域，智能体看不到也不会动它。
  String _newUserTabId() {
    final used = _manager.sessionInfos.map((i) => i.id).toSet();
    String id;
    do {
      id = 'user::web${++_userTabSeq}';
    } while (used.contains(id));
    return id;
  }

  @override
  void initState() {
    super.initState();
    _manager.addListener(_scheduleSave);
    _addressFocus.addListener(_onAddressFocus);
    _restore();
  }

  @override
  void dispose() {
    _manager.removeListener(_scheduleSave);
    _addressFocus.removeListener(_onAddressFocus);
    _saveTimer?.cancel();
    if (_restored) _saveNow();
    _address.dispose();
    _addressFocus.dispose();
    _progress.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- 持久化

  Future<void> _restore() async {
    final saved = await _UserTabStore.load();
    if (!mounted) return;
    for (final (id, url) in saved.tabs) {
      _manager.restoreUserSession(id, url);
      final n = int.tryParse(id.replaceFirst('user::web', ''));
      if (n != null && n > _userTabSeq) _userTabSeq = n;
    }
    final selected = saved.selected;
    setState(() {
      _restored = true;
      if (selected != null &&
          _manager.sessionInfos.any((i) => i.id == selected)) {
        _selectedId = selected;
        _draftId = null;
        _shownId = null;
      }
    });
  }

  void _scheduleSave() {
    if (!_restored) return; // 恢复完成前不覆盖旧文件
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _saveNow);
  }

  void _saveNow() {
    final tabs = <(String, String)>[
      for (final info in _manager.sessionInfos)
        if (info.id.startsWith('user::'))
          if (_manager.lastUrlOf(info.id) case final url?
              when url.isNotEmpty && url != 'about:blank')
            (info.id, url),
    ];
    final selected = _selectedId;
    unawaited(
      _UserTabStore.save(
        tabs,
        selected != null && tabs.any((t) => t.$1 == selected) ? selected : null,
      ),
    );
  }

  /// 恢复出来的标签首次被选中时才真正加载页面。
  void _reopenIfNeeded(String id) {
    if (!id.startsWith('user::') || _reopening.contains(id)) return;
    if (_liveSession(id) != null) return;
    final url = _manager.lastUrlOf(id);
    if (url == null || url.isEmpty) return;
    _reopening.add(id);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _manager.run(
          sessionId: id,
          kind: BrowserCallKind.observation,
          (s) => s.open(url),
        );
      } on BrowserException {
        // 打不开就留在占位页，用户可在地址栏重新输入。
      } finally {
        _reopening.remove(id);
        if (mounted) setState(() {});
      }
    });
  }

  // ---------------------------------------------------------------- 状态

  HeadlessBrowserSession? _liveSession(String? id) {
    if (id == null) return null;
    final session = _manager.peekSession(id);
    if (session is! HeadlessBrowserSession || session.disposed) return null;
    return session;
  }

  String? _urlOf(String id) => _liveSession(id)?.lastUrl ?? _manager.lastUrlOf(id);

  String _titleOf(String id) {
    final title = _liveSession(id)?.lastTitle;
    if (title != null && title.isNotEmpty) return title;
    final host = _hostOf(_urlOf(id));
    if (host.isNotEmpty) return host;
    return id.startsWith('user::') ? '新标签' : '智能体 · ${browserSessionLabel(id)}';
  }

  static String _hostOf(String? url) {
    if (url == null || url.isEmpty || url == 'about:blank') return '';
    final host = Uri.tryParse(url)?.host ?? '';
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  /// 地址胶囊未编辑时的显示：搜索结果显示搜索词，其余显示域名。
  static String _displayOf(String? url) {
    if (url == null || url.isEmpty || url == 'about:blank') return '';
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final q = uri.queryParameters['q'] ?? uri.queryParameters['wd'];
    final isSearch =
        uri.path.contains('search') || uri.host.contains('baidu.com');
    if (q != null && q.isNotEmpty && isSearch) return q;
    return _hostOf(url);
  }

  _View? _resolve() {
    final infos = _manager.sessionInfos;
    final draft = _draftId;
    String id;
    BrowserSessionInfo? info;
    if (draft != null && !infos.any((i) => i.id == draft)) {
      id = draft;
    } else if (infos.isEmpty) {
      if (!_restored) return null;
      _draftId = _newUserTabId();
      id = _draftId!;
    } else {
      info = infos.firstWhere(
        (i) => i.id == _selectedId,
        orElse: () => infos.firstWhere(
          (i) => i.ownership == SessionOwnership.delegatedToUser,
          orElse: () => infos.last,
        ),
      );
      id = info.id;
    }
    final session = _liveSession(id);
    if (info != null && session == null) _reopenIfNeeded(id);
    if (_shownId != id) {
      _shownId = id;
      final text = _urlOf(id) ?? '';
      // 构建期间不能改 controller / notifier（会在 build 中触发重建）。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_addressFocus.hasFocus) _address.text = text;
        _progress.value = 1;
      });
    }
    _currentId = id;
    final currentDraft = _draftId;
    return _View(
      id: id,
      info: info,
      session: session,
      tabs: [
        for (final i in infos) _TabItem(i.id, i),
        if (currentDraft != null && !infos.any((i) => i.id == currentDraft))
          _TabItem(currentDraft, null),
      ],
    );
  }

  // ---------------------------------------------------------------- 操作

  void _onAddressFocus() {
    final focused = _addressFocus.hasFocus;
    if (focused) {
      final id = _currentId;
      _address.text = id == null ? '' : (_urlOf(id) ?? '');
      _address.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _address.text.length,
      );
    }
    if (focused != _editing) setState(() => _editing = focused);
  }

  void _newTab() {
    setState(() {
      _draftId = _newUserTabId();
      _selectedId = _draftId;
      _shownId = _draftId;
      _showTabs = false;
      _address.clear();
    });
    _addressFocus.requestFocus();
  }

  void _select(String id) {
    setState(() {
      if (id != _draftId) _draftId = null;
      _selectedId = id;
      _showTabs = false;
    });
    _scheduleSave();
  }

  void _closeTab(String id) {
    _thumbs.remove(id);
    if (id == _draftId) {
      setState(() => _draftId = null);
      return;
    }
    if (_selectedId == id) _selectedId = null;
    unawaited(_manager.closeSession(id));
  }

  /// 用户亲自操作页面：智能体主导时自动接管（真暂停，避免双方抢页面）。
  Future<void> _userAction(String id, Future<void> Function() action) async {
    if (_manager.ownershipOf(id) == SessionOwnership.agent) {
      _manager.userClaim(id);
    }
    await action();
  }

  Future<void> _go(String id, String input) async {
    final url = _normalizeAddress(input);
    if (url == null) return;
    _addressFocus.unfocus();
    if (_manager.ownershipOf(id) == SessionOwnership.agent) {
      _manager.userClaim(id);
    }
    final fresh = _draftId == id;
    try {
      final run = _manager.run(
        sessionId: id,
        kind: BrowserCallKind.observation,
        (s) => s.open(url),
      );
      if (fresh) {
        // 新标签：条目在 run 时才建，建好后标记为用户主导（不被回收、
        // 智能体不能动），并切过去。
        _manager.userClaim(id);
        setState(() {
          _draftId = null;
          _selectedId = id;
          _shownId = null;
        });
      }
      await run;
    } on BrowserException catch (e) {
      _toast(e.message);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 地址栏输入：像网址就补 https://，否则走搜索。
  static String? _normalizeAddress(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return null;
    final uri = Uri.tryParse(input);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return input;
    }
    final looksLikeHost =
        !input.contains(' ') &&
        RegExp(r'^[\w-]+(\.[\w-]+)+(:\d+)?(/.*)?$').hasMatch(input);
    if (looksLikeHost) return 'https://$input';
    return 'https://www.bing.com/search?q=${Uri.encodeQueryComponent(input)}';
  }

  Future<void> _openTabs() async {
    _addressFocus.unfocus();
    final id = _currentId;
    final current = _liveSession(id);
    if (id != null && current != null) {
      final bytes = await current.thumbnail(width: 480);
      if (bytes != null) _thumbs[id] = bytes;
    }
    if (!mounted) return;
    setState(() => _showTabs = true);
    // 其它存活标签的缩略图异步补上（不可见的 WebView 可能截不到，回退字母占位）。
    for (final info in _manager.sessionInfos) {
      if (info.id == id) continue;
      final s = _liveSession(info.id);
      if (s == null) continue;
      unawaited(
        s.thumbnail(width: 480).then((bytes) {
          if (bytes != null && mounted) setState(() => _thumbs[info.id] = bytes);
        }),
      );
    }
  }

  Future<void> _handleBack() async {
    if (_showTabs) {
      setState(() => _showTabs = false);
      return;
    }
    if (_addressFocus.hasFocus) {
      _addressFocus.unfocus();
      return;
    }
    final id = _currentId;
    final s = _liveSession(id);
    if (id != null && s != null && await s.canGoBack()) {
      await _userAction(id, s.goBack);
      return;
    }
    if (mounted) _exit();
  }

  void _openLibrary(int tab) {
    showBrowserLibrarySheet(
      context,
      initialTab: tab,
      onOpen: (url) => _go(_currentId ?? _newUserTabId(), url),
    );
  }

  void _showMenu(_View v) {
    final s = v.session;
    final url = s?.lastUrl;
    final bookmarkUrl = url != null && url.startsWith('http') ? url : null;
    final info = v.info;
    final agentTab = !v.id.startsWith('user::');
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) {
        void act(VoidCallback f) {
          Navigator.pop(sheet);
          f();
        }

        final marked =
            bookmarkUrl != null &&
            BrowserLibrary.instance.isBookmarked(bookmarkUrl);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _MenuTile(
                  icon: LucideIcons.arrowRight,
                  label: '前进',
                  onTap: s == null
                      ? null
                      : () => act(() => _userAction(v.id, s.goForward)),
                ),
                _MenuTile(
                  icon: LucideIcons.rotateCw,
                  label: '刷新',
                  onTap: s == null
                      ? null
                      : () => act(() => _userAction(v.id, s.reload)),
                ),
                _MenuTile(
                  icon: LucideIcons.star,
                  label: marked ? '取消收藏' : '收藏',
                  highlighted: marked,
                  onTap: bookmarkUrl == null
                      ? null
                      : () => act(
                          () => BrowserLibrary.instance.toggleBookmark(
                            bookmarkUrl,
                            s?.lastTitle ?? '',
                          ),
                        ),
                ),
                _MenuTile(
                  icon: LucideIcons.squarePlus,
                  label: '新标签',
                  onTap: () => act(_newTab),
                ),
                _MenuTile(
                  icon: LucideIcons.bookMarked,
                  label: '书签',
                  onTap: () => act(() => _openLibrary(0)),
                ),
                _MenuTile(
                  icon: LucideIcons.history,
                  label: '历史',
                  onTap: () => act(() => _openLibrary(1)),
                ),
                _MenuTile(
                  icon: LucideIcons.download,
                  label: '下载',
                  onTap: () => act(() => _openLibrary(2)),
                ),
                _MenuTile(
                  icon: LucideIcons.link,
                  label: '复制链接',
                  onTap: url == null || url.isEmpty
                      ? null
                      : () => act(() {
                          Clipboard.setData(ClipboardData(text: url));
                          _toast('链接已复制');
                        }),
                ),
                if (info != null &&
                    agentTab &&
                    info.ownership == SessionOwnership.agent)
                  _MenuTile(
                    icon: LucideIcons.hand,
                    label: '接管',
                    onTap: () => act(() => _manager.userClaim(v.id)),
                  ),
                if (info != null &&
                    agentTab &&
                    info.ownership != SessionOwnership.agent)
                  _MenuTile(
                    icon: LucideIcons.bot,
                    label: '交回智能体',
                    onTap: () => act(() => _manager.takeOver(v.id)),
                  ),
                _MenuTile(
                  icon: LucideIcons.x,
                  label: '关闭标签',
                  onTap: () => act(() => _closeTab(v.id)),
                ),
                _MenuTile(
                  icon: LucideIcons.logOut,
                  label: '退出浏览器',
                  onTap: () => act(_exit),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------- 构建

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_manager, BrowserLibrary.instance]),
      builder: (context, _) {
        final v = _resolve();
        if (v == null) return const Scaffold(body: SizedBox.shrink());
        final wide = MediaQuery.sizeOf(context).width >= 840;
        return PopScope(
          canPop: _exiting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_handleBack());
          },
          child: wide ? _desktop(context, v) : _mobile(context, v),
        );
      },
    );
  }

  Widget _content(_View v) {
    final s = v.session;
    if (s != null) {
      return CoDriveWebView(
        key: ValueKey(v.id),
        session: s,
        onProgress: (p) => _progress.value = p,
        onTitleChanged: (_) {
          if (mounted) setState(() {});
        },
        onUrlChanged: (url) {
          if (!_addressFocus.hasFocus && _address.text != url) {
            _address.text = url;
          }
          _scheduleSave();
          if (mounted) setState(() {});
        },
      );
    }
    final url = _manager.lastUrlOf(v.id);
    if (url == null || url.isEmpty) {
      return BrowserStartPage(onOpen: (u) => _go(v.id, u));
    }
    if (v.id.startsWith('user::')) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return const _ReleasedPlaceholder();
  }

  Widget? _statusChip(_View v) {
    final info = v.info;
    if (info == null) return null;
    final userTab = v.id.startsWith('user::');
    if (userTab && info.ownership == SessionOwnership.user) return null;
    final note = info.handOffNote;
    final (IconData icon, String label, String action, VoidCallback onTap) =
        switch (info.ownership) {
          SessionOwnership.agent => (
            LucideIcons.bot,
            '智能体正在操作此标签',
            '接管',
            () => _manager.userClaim(v.id),
          ),
          SessionOwnership.delegatedToUser => (
            LucideIcons.hand,
            note == null || note.isEmpty ? '智能体请你接手处理' : '智能体请你处理：$note',
            '交回给智能体',
            () => _manager.takeOver(v.id),
          ),
          SessionOwnership.user => (
            LucideIcons.user,
            '你已接管，智能体已暂停',
            '交回给智能体',
            () => _manager.takeOver(v.id),
          ),
        };
    final cs = Theme.of(context).colorScheme;
    return _Glass(
      radius: 16,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(onPressed: onTap, child: Text(action)),
          ],
        ),
      ),
    );
  }

  /// 地址胶囊：未编辑时显示域名/搜索词（点按进入编辑），底部细进度条。
  Widget _addressPill(_View v, {required double height}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = v.session;
    final url = _urlOf(v.id);
    final secure = url != null && url.startsWith('https://');
    final display = _displayOf(url);
    final field = TextField(
      controller: _address,
      focusNode: _addressFocus,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.go,
      autocorrect: false,
      style: theme.textTheme.bodyMedium,
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: '搜索或输入网址',
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      onSubmitted: (value) => _go(v.id, value),
    );
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: Center(child: field)),
          if (!_editing)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _addressFocus.requestFocus,
                child: Container(
                    color: cs.surfaceContainerHighest,
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (display.isNotEmpty)
                          Icon(
                            secure ? LucideIcons.lock : LucideIcons.globe,
                            size: 13,
                            color: cs.onSurface.withValues(alpha: 0.55),
                          ),
                        if (display.isNotEmpty) const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            display.isEmpty ? '搜索或输入网址' : display,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: display.isEmpty
                                  ? cs.onSurface.withValues(alpha: 0.5)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ),
            ),
          if (!_editing && s != null)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: IconButton(
                tooltip: '刷新',
                iconSize: 16,
                icon: const Icon(LucideIcons.rotateCw),
                onPressed: () => _userAction(v.id, s.reload),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _progress,
              builder: (context, p, _) => p >= 1 || s == null
                  ? const SizedBox.shrink()
                  : LinearProgressIndicator(
                      value: p <= 0 ? null : p,
                      minHeight: 2,
                      backgroundColor: Colors.transparent,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobile(BuildContext context, _View v) {
    final s = v.session;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    const dockHeight = 56.0;
    final reserve = dockHeight + 16 + bottomSafe;
    final status = _statusChip(v);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: reserve),
                child: _content(v),
              ),
            ),
          ),
          if (status != null && !_showTabs)
            Positioned(
              left: 12,
              right: 12,
              bottom: reserve + 4,
              child: status,
            ),
          if (!_showTabs)
            Positioned(
              left: 10,
              right: 10,
              bottom: 8 + bottomSafe,
              child: _Glass(
                radius: dockHeight / 2,
                child: SizedBox(
                  height: dockHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      children: _editing
                          ? [
                              Expanded(child: _addressPill(v, height: 42)),
                              TextButton(
                                onPressed: _addressFocus.unfocus,
                                child: const Text('取消'),
                              ),
                            ]
                          : [
                              _DockButton(
                                tooltip: '后退',
                                icon: LucideIcons.chevronLeft,
                                onTap: s == null ? null : _handleBack,
                              ),
                              const SizedBox(width: 2),
                              Expanded(child: _addressPill(v, height: 42)),
                              const SizedBox(width: 2),
                              _DockButton(
                                tooltip: '标签页',
                                onTap: _openTabs,
                                child: _TabCount(count: v.tabs.length),
                              ),
                              _DockButton(
                                tooltip: '更多',
                                icon: LucideIcons.ellipsis,
                                onTap: () => _showMenu(v),
                              ),
                            ],
                    ),
                  ),
                ),
              ),
            ),
          if (_showTabs) Positioned.fill(child: _tabSwitcher(v)),
        ],
      ),
    );
  }

  Widget _desktop(BuildContext context, _View v) {
    final s = v.session;
    final cs = Theme.of(context).colorScheme;
    final status = _statusChip(v);
    final url = s?.lastUrl;
    final bookmarkUrl = url != null && url.startsWith('http') ? url : null;
    final marked =
        bookmarkUrl != null && BrowserLibrary.instance.isBookmarked(bookmarkUrl);
    final downloading = BrowserLibrary.instance.downloads.any(
      (d) => d.status == BrowserDownloadStatus.running,
    );
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 42,
              color: cs.surfaceContainer,
              child: Row(
                children: [
                  IconButton(
                    tooltip: '退出浏览器',
                    iconSize: 18,
                    icon: const Icon(LucideIcons.arrowLeft),
                    onPressed: _exit,
                  ),
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(top: 6),
                      children: [
                        for (final t in v.tabs)
                          _DesktopTab(
                            title: t.info == null ? '新标签' : _titleOf(t.id),
                            agent: !t.id.startsWith('user::'),
                            selected: t.id == v.id,
                            onTap: () => _select(t.id),
                            onClose: () => _closeTab(t.id),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '新标签',
                    iconSize: 18,
                    icon: const Icon(LucideIcons.plus),
                    onPressed: _newTab,
                  ),
                ],
              ),
            ),
            Container(
              height: 48,
              color: cs.surface,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '后退',
                    iconSize: 18,
                    icon: const Icon(LucideIcons.arrowLeft),
                    onPressed: s == null
                        ? null
                        : () => _userAction(v.id, s.goBack),
                  ),
                  IconButton(
                    tooltip: '前进',
                    iconSize: 18,
                    icon: const Icon(LucideIcons.arrowRight),
                    onPressed: s == null
                        ? null
                        : () => _userAction(v.id, s.goForward),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: _addressPill(v, height: 34),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: marked ? '取消收藏' : '收藏',
                    iconSize: 18,
                    icon: Icon(
                      LucideIcons.star,
                      color: marked ? Colors.amber : null,
                    ),
                    onPressed: bookmarkUrl == null
                        ? null
                        : () => BrowserLibrary.instance.toggleBookmark(
                            bookmarkUrl,
                            s?.lastTitle ?? '',
                          ),
                  ),
                  IconButton(
                    tooltip: '书签 / 历史 / 下载',
                    iconSize: 18,
                    icon: Badge(
                      isLabelVisible: downloading,
                      child: const Icon(LucideIcons.libraryBig),
                    ),
                    onPressed: () => _openLibrary(downloading ? 2 : 0),
                  ),
                  IconButton(
                    tooltip: '更多',
                    iconSize: 18,
                    icon: const Icon(LucideIcons.ellipsisVertical),
                    onPressed: () => _showMenu(v),
                  ),
                ],
              ),
            ),
            if (status != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                child: status,
              ),
            Divider(height: 1, color: cs.outlineVariant),
            Expanded(child: _content(v)),
          ],
        ),
      ),
    );
  }

  Widget _tabSwitcher(_View v) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    return Material(
      color: cs.surfaceContainerLow,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Text(
                    '${v.tabs.length} 个标签页',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _showTabs = false),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.count(
                crossAxisCount: width >= 600 ? 3 : 2,
                childAspectRatio: 0.72,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                children: [
                  for (final t in v.tabs)
                    _TabCard(
                      title: t.info == null ? '新标签' : _titleOf(t.id),
                      host: _hostOf(_urlOf(t.id)),
                      agent: !t.id.startsWith('user::'),
                      paused:
                          !t.id.startsWith('user::') &&
                          t.info?.ownership != SessionOwnership.agent,
                      selected: t.id == v.id,
                      thumbnail: _thumbs[t.id],
                      onTap: () => _select(t.id),
                      onClose: () => _closeTab(t.id),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: _newTab,
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: const Text('新标签'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ 组件

/// 磨砂玻璃底板（悬浮工具条/状态条）。
class _Glass extends StatelessWidget {
  const _Glass({required this.child, this.radius = 28});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.86),
              borderRadius: shape,
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.tooltip,
    this.icon,
    this.child,
    this.onTap,
  });

  final String tooltip;
  final IconData? icon;
  final Widget? child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      iconSize: 22,
      color: cs.onSurface,
      disabledColor: cs.onSurface.withValues(alpha: 0.28),
      icon: child ?? Icon(icon),
    );
  }
}

/// 标签数方框（同 kelivo / 系统浏览器）。
class _TabCount extends StatelessWidget {
  const _TabCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        count > 99 ? ':D' : '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1,
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final enabled = onTap != null;
    final color = cs.onSurface.withValues(alpha: enabled ? 1 : 0.3);
    return SizedBox(
      width: 80,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: highlighted ? Colors.amber : color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabCard extends StatelessWidget {
  const _TabCard({
    required this.title,
    required this.host,
    required this.agent,
    required this.paused,
    required this.selected,
    required this.thumbnail,
    required this.onTap,
    required this.onClose,
  });

  final String title;
  final String host;
  final bool agent;
  final bool paused;
  final bool selected;
  final Uint8List? thumbnail;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final letter = host.isEmpty ? '+' : host.characters.first.toUpperCase();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 34,
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  if (agent)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        paused ? LucideIcons.user : LucideIcons.bot,
                        size: 13,
                        color: cs.primary,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    iconSize: 14,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(LucideIcons.x),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            Expanded(
              child: thumbnail != null
                  ? Image.memory(
                      thumbnail!,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      gaplessPlayback: true,
                    )
                  : ColoredBox(
                      color: cs.surfaceContainerHighest,
                      child: Center(
                        child: Text(
                          letter,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.35),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopTab extends StatelessWidget {
  const _DesktopTab({
    required this.title,
    required this.agent,
    required this.selected,
    required this.onTap,
    required this.onClose,
  });

  final String title;
  final bool agent;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Material(
        color: selected ? cs.surface : Colors.transparent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        child: InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          onTap: onTap,
          child: SizedBox(
            width: 200,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(
                  agent ? LucideIcons.bot : LucideIcons.globe,
                  size: 14,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
                IconButton(
                  tooltip: '关闭标签',
                  iconSize: 14,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(LucideIcons.x),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReleasedPlaceholder extends StatelessWidget {
  const _ReleasedPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          '这个智能体标签的页面已释放以节省内存，\n智能体下次操作时会自动重新打开。',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
