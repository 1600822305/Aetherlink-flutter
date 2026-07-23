// 浏览共驾页（升级设计 §2.4 M4d）：agent 用 browser_hand_off 把会话交给
// 用户后，用户在这里亲自完成登录/验证码/滑块等操作，再交回给 agent。
// 可见 WebView 与 headless 会话是不同实例，但 cookie/登录态全局共享
// （WebView 平台特性），用户登录后 agent 的会话直接复用登录态。

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
              Expanded(
                child: selected.ownership == SessionOwnership.agent
                    ? const _AgentOwnedPlaceholder()
                    : CoDriveWebView(
                        // 会话切换/交接后重建 WebView，加载交接时的页面。
                        key: ValueKey(
                          '${selected.id}:${selected.handOffUrl ?? ''}',
                        ),
                        initialUrl: selected.handOffUrl,
                      ),
              ),
            ],
          );
        },
      ),
    );
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
      SessionOwnership.agent => ('智能体控制中', LucideIcons.bot),
      SessionOwnership.delegatedToUser => ('等你操作', LucideIcons.user),
      SessionOwnership.user => ('你已接管', LucideIcons.user),
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

class _AgentOwnedPlaceholder extends StatelessWidget {
  const _AgentOwnedPlaceholder();

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
              '该会话由智能体控制中',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '智能体在后台（无界面）浏览。点「接管」可暂停智能体、'
              '由你在可见窗口继续操作；登录态与智能体会话共享。',
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
