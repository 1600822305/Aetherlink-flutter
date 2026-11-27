// 内置浏览器页：多标签 + 地址栏 + 前进/后退/刷新，实时渲染智能体正在用的
// 同一个 WebView（headless 转可见 + keepAlive）。用户在地址栏导航即接管该
// 标签（智能体暂停），点「交回给智能体」后恢复。

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_browser/aetherlink_browser.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/browser/browser_tool.dart';

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

  @override
  void dispose() {
    _address.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('内置浏览器')),
      body: ListenableBuilder(
        listenable: _manager,
        builder: (context, _) {
          final infos = _manager.sessionInfos;
          if (infos.isEmpty) {
            return const _Empty();
          }
          final selected = infos.firstWhere(
            (i) => i.id == _selectedId,
            orElse: () => infos.firstWhere(
              (i) => i.ownership == SessionOwnership.delegatedToUser,
              orElse: () => infos.last,
            ),
          );
          final session = _liveSession(selected.id);
          if (_shownId != selected.id) {
            _shownId = selected.id;
            _address.text = session?.lastUrl ?? '';
          }
          return Column(
            children: [
              _SessionBar(
                infos: infos,
                selectedId: selected.id,
                onSelect: (id) => setState(() => _selectedId = id),
                onClose: (id) => _manager.closeSession(id),
              ),
              _OwnershipBanner(info: selected, manager: _manager),
              if (session != null) _addressBar(context, selected.id, session),
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
    HeadlessBrowserSession session,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: '后退',
            icon: const Icon(LucideIcons.arrowLeft, size: 18),
            onPressed: () => _userAction(id, session.goBack),
          ),
          IconButton(
            tooltip: '前进',
            icon: const Icon(LucideIcons.arrowRight, size: 18),
            onPressed: () => _userAction(id, session.goForward),
          ),
          IconButton(
            tooltip: '刷新',
            icon: const Icon(LucideIcons.rotateCw, size: 18),
            onPressed: () => _userAction(id, session.reload),
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
    try {
      await _manager.run(
        sessionId: id,
        kind: BrowserCallKind.observation,
        (s) => s.open(url),
      );
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
      return const _NoLiveSessionPlaceholder();
    }
    return CoDriveWebView(
      key: ValueKey(selected.id),
      session: session,
      onUrlChanged: (url) {
        if (!_addressFocus.hasFocus && _address.text != url) {
          _address.text = url;
        }
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
          '还没有浏览器会话。\n智能体使用内置浏览器工具后，会话会显示在这里；'
          '需要你登录/过验证码时它会把会话交给你。',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
