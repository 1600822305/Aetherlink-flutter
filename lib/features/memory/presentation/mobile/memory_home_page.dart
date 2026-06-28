import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/memory/application/memory_providers.dart';
import 'package:aetherlink_flutter/features/memory/application/memory_settings_controller.dart';
import 'package:aetherlink_flutter/features/memory/data/chat_memory_store.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_settings.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

/// The 记忆 home page (数据与知识 → 记忆功能) — the top-level landing page for
/// chat memory.
///
/// It is an overview-plus-entry hub: the master 启用记忆 switch and the two
/// 自动写入 toggles persist to the Drift KV store via [MemorySettingsController]
/// and take effect immediately. The 记忆概览 statistics and the 全局记忆 entry
/// are backed by the memory store (real counts + a working list page); the
/// remaining sections (按助手 / 搜索 management and the 记忆设置 sub-page) carry
/// an 「即将支持」 tag until they land, following the project's honest-placeholder
/// convention (no fabricated counts, no fake sub-pages).
///
/// Recomposed into the project's compact settings style (the
/// `_OutlinedCard` / `_CardHeader` / `_PrimaryRow` vocabulary shared with the
/// 行为 page). Colors are theme tokens (ADR-0008); icons are lucide (ADR-0009).
class MemoryHomePage extends ConsumerWidget {
  const MemoryHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final config = ref.watch(memorySettingsControllerProvider);
    final controller = ref.read(memorySettingsControllerProvider.notifier);
    final counts = ref.watch(memoryCountsProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        centerTitle: false,
        titleSpacing: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        leadingWidth: 44,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: const Icon(LucideIcons.arrowLeft, size: 24),
            color: theme.colorScheme.primary,
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(AppRouter.settingsPath),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: const Text('记忆'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _masterCard(theme, config.enabled, controller),
          if (config.enabled) ...[
            const SizedBox(height: 10),
            _overviewCard(theme, counts),
            const SizedBox(height: 14),
            const _GroupLabel('管理'),
            const SizedBox(height: 6),
            _manageCard(context, theme, counts),
            const SizedBox(height: 14),
            const _GroupLabel('自动写入'),
            const SizedBox(height: 6),
            _autoWriteCard(theme, config, controller),
            const SizedBox(height: 14),
            const _GroupLabel('配置'),
            const SizedBox(height: 6),
            _settingsCard(theme),
          ],
        ],
      ),
    );
  }

  Widget _masterCard(
    ThemeData theme,
    bool enabled,
    MemorySettingsController controller,
  ) {
    return _OutlinedCard(
      child: _PrimaryRow(
        icon: LucideIcons.brain,
        accent: const Color(0xFF8B5CF6),
        label: '启用记忆',
        description: '关闭后，助手不会记录对话内容，也不会调用任何记忆',
        value: enabled,
        onChanged: controller.setEnabled,
      ),
    );
  }

  Widget _overviewCard(ThemeData theme, AsyncValue<MemoryCounts> counts) {
    return _OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(title: '记忆概览', description: '记忆总数、全局与涉及助手分布'),
          Divider(height: 1, color: theme.dividerColor),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: counts.when(
              loading: () => const SizedBox(
                height: 44,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (e, _) => SizedBox(
                height: 44,
                child: Center(
                  child: Text(
                    '统计加载失败',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ),
              data: (c) => Row(
                children: [
                  _StatCell(value: c.total, label: '总记忆'),
                  _StatDivider(theme: theme),
                  _StatCell(value: c.global, label: '全局'),
                  _StatDivider(theme: theme),
                  _StatCell(value: c.assistants, label: '涉及助手'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _manageCard(
    BuildContext context,
    ThemeData theme,
    AsyncValue<MemoryCounts> counts,
  ) {
    final globalCount = counts.asData?.value.global;
    final assistantCount = counts.asData?.value.assistants;
    return _OutlinedCard(
      child: Column(
        children: [
          _NavRow(
            icon: LucideIcons.globe,
            accent: const Color(0xFF06B6D4),
            label: '全局记忆',
            description: '所有助手通用的偏好与事实',
            trailingText: globalCount?.toString(),
            onTap: () => context.push(AppRouter.globalMemoryPath),
          ),
          Divider(height: 1, color: theme.dividerColor),
          _NavRow(
            icon: LucideIcons.users,
            accent: const Color(0xFF10B981),
            label: '按助手查看',
            description: '查看并管理各助手的私有记忆',
            trailingText: assistantCount?.toString(),
            onTap: () => context.push(AppRouter.assistantMemoryIndexPath),
          ),
          Divider(height: 1, color: theme.dividerColor),
          _NavRow(
            icon: LucideIcons.search,
            accent: const Color(0xFFF59E0B),
            label: '搜索全部记忆',
            description: '跨全局与助手检索记忆条目',
            onTap: () => context.push(AppRouter.searchMemoryPath),
          ),
        ],
      ),
    );
  }

  Widget _autoWriteCard(
    ThemeData theme,
    MemorySettings config,
    MemorySettingsController controller,
  ) {
    return _OutlinedCard(
      child: Column(
        children: [
          _PrimaryRow(
            icon: LucideIcons.penLine,
            accent: const Color(0xFF10B981),
            label: '自动记忆 · 私有',
            description: '对话后自动提取事实，写入当前助手的私有记忆',
            value: config.autoWritePrivate,
            onChanged: controller.setAutoWritePrivate,
          ),
          Divider(height: 1, color: theme.dividerColor),
          _PrimaryRow(
            icon: LucideIcons.globe,
            accent: const Color(0xFF06B6D4),
            label: '自动记忆 · 全局',
            description: '允许把通用偏好自动写入全局记忆（默认关闭）',
            value: config.autoWriteGlobal,
            onChanged: controller.setAutoWriteGlobal,
          ),
        ],
      ),
    );
  }

  Widget _settingsCard(ThemeData theme) {
    return const _OutlinedCard(
      child: _NavRow(
        icon: LucideIcons.settings2,
        accent: Color(0xFF8B5CF6),
        label: '记忆设置',
        description: '注入方式 · 嵌入模型 · 高级参数',
        comingSoon: true,
      ),
    );
  }
}

/// A small uppercase-ish group label above a card (the 管理 / 自动写入 / 配置
/// headings), matching the settings hub's grouped sections.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A rounded, bordered surface card with the project's soft shadow (mirrors the
/// 行为 page card).
class _OutlinedCard extends StatelessWidget {
  const _OutlinedCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000), // rgba(0,0,0,0.05)
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A card section header: a faint strip with a title and a description.
class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: theme.colorScheme.onSurface.withValues(alpha: 0.015),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 12.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A primary toggle row: a small tinted glyph, a label and description on the
/// left, a [CustomSwitch] on the right (the 行为 page vocabulary).
class _PrimaryRow extends StatelessWidget {
  const _PrimaryRow({
    required this.icon,
    required this.accent,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    height: 1.3,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CustomSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// A navigation row: a tinted glyph, a label and description, and a trailing
/// chevron — or an 「即将支持」 tag while its target is not built yet (rendered
/// at half opacity, non-interactive), matching the settings hub's disabled rows.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.accent,
    required this.label,
    required this.description,
    this.comingSoon = false,
    this.onTap,
    this.trailingText,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String description;
  final bool comingSoon;
  final VoidCallback? onTap;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (comingSoon) ...[
                      const SizedBox(width: 6),
                      const _ComingSoonTag(),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    height: 1.3,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (trailingText != null) ...[
            Text(
              trailingText!,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Icon(
            LucideIcons.chevronRight,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );

    if (comingSoon) return Opacity(opacity: 0.5, child: row);
    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: row),
      );
    }
    return row;
  }
}

/// One number-over-label cell in the 记忆概览 statistics row.
class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A thin vertical separator between two [_StatCell]s.
class _StatDivider extends StatelessWidget {
  const _StatDivider({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 30, color: theme.dividerColor);
  }
}

/// The small outlined 「即将支持」 tag (the 行为 page's tag).
class _ComingSoonTag extends StatelessWidget {
  const _ComingSoonTag();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Text(
        '即将支持',
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 10.5,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
