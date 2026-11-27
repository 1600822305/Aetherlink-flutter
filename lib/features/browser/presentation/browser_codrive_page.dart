// 内置浏览器页：多标签 + 地址栏 + 前进/后退/刷新，实时渲染智能体正在用的
// 同一个 WebView（headless 转可见 + keepAlive）。用户在地址栏导航即接管该
// 标签（智能体暂停），点「交回给智能体」后恢复。

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
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

class _BrowserCoDrivePageState extends State<BrowserCoDrivePage> {
  final BrowserSessionManager _manager = sharedBrowserManager();
  final TextEditingController _address = TextEditingController();
  final FocusNode _addressFocus = FocusNode();
  String? _selectedId;
  String? _shownId;

  /// 用户新开、尚未加载页面的标签（只显示地址栏）。
  String? _draftId;
  int _userTabSeq = 0;

  /// 用户自己开的标签放在独立作用域，智能体看不到也不会动它。
  String _newUserTabId() {
    final used = _manager.sessionInfos.map((i) => i.id).toSet();
    String id;
    do {
      id = 'user::web${++_userTabSeq}';
    } while (used.contains(id));
    return id;
  }

  void _newTab() {
    setState(() {
      _draftId = _newUserTabId();
      _selectedId = _draftId;
      _shownId = _draftId;
      _address.clear();
    });
    _addressFocus.requestFocus();
  }

  Timer? _saveTimer;
  bool _restored = false;
  final Set<String> _reopening = {};

  @override
  void initState() {
    super.initState();
    _manager.addListener(_scheduleSave);
    _restore();
  }

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

  @override
  void dispose() {
    _manager.removeListener(_scheduleSave);
    _saveTimer?.cancel();
    if (_restored) _saveNow();
    _address.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('内置浏览器'),
        actions: [
          IconButton(
            tooltip: '书签 / 历史 / 下载',
            icon: ListenableBuilder(
              listenable: BrowserLibrary.instance,
              builder: (context, _) {
                final running = BrowserLibrary.instance.downloads.any(
                  (d) => d.status == BrowserDownloadStatus.running,
                );
                return Badge(
                  isLabelVisible: running,
                  child: const Icon(LucideIcons.libraryBig),
                );
              },
            ),
            onPressed: () => showBrowserLibrarySheet(
              context,
              onOpen: (url) => _go(_selectedId ?? _draftId ?? _newUserTabId(), url),
            ),
          ),
          IconButton(
            tooltip: '新标签',
            icon: const Icon(LucideIcons.plus),
            onPressed: _newTab,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _manager,
        builder: (context, _) {
          final infos = _manager.sessionInfos;
          final draft = _draftId;
          if (draft != null && !infos.any((i) => i.id == draft)) {
            // 新标签尚未打开页面：只给地址栏。
            return Column(
              children: [
                if (infos.isNotEmpty)
                  _SessionBar(
                    infos: infos,
                    selectedId: draft,
                    onSelect: (id) => setState(() {
                      _draftId = null;
                      _selectedId = id;
                    }),
                    onClose: (id) => _manager.closeSession(id),
                  ),
                _addressBar(context, draft, null),
                Expanded(
                  child: BrowserStartPage(onOpen: (url) => _go(draft, url)),
                ),
              ],
            );
          }
          if (infos.isEmpty) {
            if (!_restored) return const SizedBox.shrink();
            _draftId = _newUserTabId();
            _shownId = _draftId;
            return Column(
              children: [
                _addressBar(context, _draftId!, null),
                Expanded(
                  child: BrowserStartPage(
                    onOpen: (url) => _go(_draftId!, url),
                  ),
                ),
              ],
            );
          }
          final selected = infos.firstWhere(
            (i) => i.id == _selectedId,
            orElse: () => infos.firstWhere(
              (i) => i.ownership == SessionOwnership.delegatedToUser,
              orElse: () => infos.last,
            ),
          );
          final session = _liveSession(selected.id);
          if (session == null) _reopenIfNeeded(selected.id);
          if (_shownId != selected.id) {
            _shownId = selected.id;
            _address.text =
                session?.lastUrl ?? _manager.lastUrlOf(selected.id) ?? '';
          }
          return Column(
            children: [
              _SessionBar(
                infos: infos,
                selectedId: selected.id,
                onSelect: (id) {
                  setState(() => _selectedId = id);
                  _scheduleSave();
                },
                onClose: (id) => _manager.closeSession(id),
              ),
              _OwnershipBanner(info: selected, manager: _manager),
              _addressBar(context, selected.id, session),
              Expanded(child: _liveView(selected, session)),
            ],
          );
        },
      ),
    );
  }

  HeadlessBrowserSession? _liveSession(String id) {
    final session = _manager.peekSession(id);
    if (session is! HeadlessBrowserSession || session.disposed) return null;
    return session;
  }

  Widget _addressBar(
    BuildContext context,
    String id,
    HeadlessBrowserSession? session,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: '后退',
            icon: const Icon(LucideIcons.arrowLeft, size: 18),
            onPressed: session == null
                ? null
                : () => _userAction(id, session.goBack),
          ),
          IconButton(
            tooltip: '前进',
            icon: const Icon(LucideIcons.arrowRight, size: 18),
            onPressed: session == null
                ? null
                : () => _userAction(id, session.goForward),
          ),
          IconButton(
            tooltip: '刷新',
            icon: const Icon(LucideIcons.rotateCw, size: 18),
            onPressed: session == null
                ? null
                : () => _userAction(id, session.reload),
          ),
          Expanded(
            child: TextField(
              controller: _address,
              focusNode: _addressFocus,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                isDense: true,
                hintText: '输入网址或搜索',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              onSubmitted: (value) => _go(id, value),
            ),
          ),
          if (session != null)
            ListenableBuilder(
              listenable: BrowserLibrary.instance,
              builder: (context, _) {
                final url = session.lastUrl;
                final marked =
                    url != null && BrowserLibrary.instance.isBookmarked(url);
                return IconButton(
                  tooltip: marked ? '取消收藏' : '收藏',
                  icon: Icon(
                    LucideIcons.star,
                    size: 18,
                    color: marked ? Colors.amber : null,
                  ),
                  onPressed: url == null || !url.startsWith('http')
                      ? null
                      : () => BrowserLibrary.instance.toggleBookmark(
                          url,
                          session.lastTitle ?? '',
                        ),
                );
              },
            ),
        ],
      ),
    );
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
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

  /// 始终渲染会话自己的 WebView（存活时），无关谁在主导。
  Widget _liveView(BrowserSessionInfo selected, HeadlessBrowserSession? session) {
    if (session == null) {
      final url = _manager.lastUrlOf(selected.id);
      if (url == null || url.isEmpty) {
        return BrowserStartPage(onOpen: (u) => _go(selected.id, u));
      }
      return const _NoLiveSessionPlaceholder();
    }
    return CoDriveWebView(
      key: ValueKey(selected.id),
      session: session,
      onUrlChanged: (url) {
        if (!_addressFocus.hasFocus && _address.text != url) {
          _address.text = url;
        }
        _scheduleSave();
      },
    );
  }
}

/// 标签条：每个会话一个标签，可关闭。
class _SessionBar extends StatelessWidget {
  const _SessionBar({
    required this.infos,
    required this.selectedId,
    required this.onSelect,
    required this.onClose,
  });

  final List<BrowserSessionInfo> infos;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final info in infos)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InputChip(
                label: Text(_tabLabel(info)),
                selected: info.id == selectedId,
                avatar: info.ownership == SessionOwnership.agent
                    ? const Icon(LucideIcons.bot, size: 14)
                    : const Icon(LucideIcons.user, size: 14),
                onSelected: (_) => onSelect(info.id),
                onDeleted: () => onClose(info.id),
                deleteButtonTooltipMessage: '关闭标签',
              ),
            ),
        ],
      ),
    );
  }

  static String _tabLabel(BrowserSessionInfo info) {
    final label = browserSessionLabel(info.id);
    final url = info.handOffUrl;
    if (url == null) return label;
    final host = Uri.tryParse(url)?.host ?? '';
    return host.isEmpty ? label : '$label · $host';
  }
}

/// 所有权状态条：显示当前控制方 + 交接说明 + 接管/交回按钮。
class _OwnershipBanner extends StatelessWidget {
  const _OwnershipBanner({required this.info, required this.manager});

  final BrowserSessionInfo info;
  final BrowserSessionManager manager;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, icon) = switch (info.ownership) {
      SessionOwnership.agent => ('智能体主导', LucideIcons.bot),
      SessionOwnership.delegatedToUser => ('等你操作（智能体已暂停）', LucideIcons.user),
      SessionOwnership.user => ('你在主导（智能体已暂停，只能观察）', LucideIcons.user),
    };
    final note = info.handOffNote;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                note == null || note.isEmpty ? label : '$label · $note',
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (info.ownership == SessionOwnership.agent)
              TextButton(
                onPressed: () => manager.userClaim(info.id),
                child: const Text('接管（暂停智能体）'),
              )
            else
              FilledButton.tonal(
                onPressed: () => manager.takeOver(info.id),
                child: const Text('交回给智能体'),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoLiveSessionPlaceholder extends StatelessWidget {
  const _NoLiveSessionPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.bot,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              '该会话的页面尚未加载',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '智能体打开页面后，这里会实时显示同一个页面；'
              '点「接管」后智能体暂停操作，由你主导。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          '在上方输入网址或搜索词即可浏览（登录态会保留，智能体之后也能用）。\n'
          '智能体使用内置浏览器后，它的标签也会显示在这里；'
          '需要你登录/过验证码时它会把标签交给你。',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
