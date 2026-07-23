// 浏览共驾页（升级设计 §2.4 M4d，宽松共驾）：始终实时渲染 agent
// 正在用的同一个 WebView（headless 转可见 + keepAlive），不管谁在
// 主导都能看、都能操作；「接管/交回」只切换主导标记，不限制双方。

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
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('浏览共驾')),
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
              orElse: () => infos.first,
            ),
          );
          return Column(
            children: [
              _SessionBar(
                infos: infos,
                selectedId: selected.id,
                onSelect: (id) => setState(() => _selectedId = id),
              ),
              _OwnershipBanner(info: selected, manager: _manager),
              Expanded(child: _liveView(selected)),
            ],
          );
        },
      ),
    );
  }

  /// 始终渲染会话自己的 WebView（存活时），无关谁在主导。
  Widget _liveView(BrowserSessionInfo selected) {
    final session = _manager.peekSession(selected.id);
    if (session is! HeadlessBrowserSession || session.disposed) {
      return const _NoLiveSessionPlaceholder();
    }
    return CoDriveWebView(key: ValueKey(selected.id), session: session);
  }
}

/// 会话切换条（多会话时显示）。
class _SessionBar extends StatelessWidget {
  const _SessionBar({
    required this.infos,
    required this.selectedId,
    required this.onSelect,
  });

  final List<BrowserSessionInfo> infos;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (infos.length <= 1) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final info in infos)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(info.id),
                selected: info.id == selectedId,
                avatar: info.ownership == SessionOwnership.agent
                    ? const Icon(LucideIcons.bot, size: 14)
                    : const Icon(LucideIcons.user, size: 14),
                onSelected: (_) => onSelect(info.id),
              ),
            ),
        ],
      ),
    );
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
      SessionOwnership.agent => ('智能体主导（你也可直接操作）', LucideIcons.bot),
      SessionOwnership.delegatedToUser => ('等你操作', LucideIcons.user),
      SessionOwnership.user => ('你在主导（智能体仍可调用）', LucideIcons.user),
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
                child: const Text('接管'),
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
              '你可以直接操作，也可点「接管」标记由你主导。',
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
