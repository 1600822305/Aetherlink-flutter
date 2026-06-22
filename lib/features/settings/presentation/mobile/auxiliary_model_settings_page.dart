import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/auxiliary_model_tab.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/auxiliary_prompt_tab.dart';

/// 辅助模型设置 page — a 2-tab layout (top segmented tabs) with:
///
/// Tab 1 — 模型配置  → [AuxiliaryModelTab] (7 default model selectors)
/// Tab 2 — 提示词设置 → [AuxiliaryPromptTab] (5 prompt editors)
///
/// State is managed by [AuxiliaryModelController] (persisted via key/value
/// store). This page shell only provides the AppBar + segmented tab bar.
class AuxiliaryModelSettingsPage extends ConsumerStatefulWidget {
  const AuxiliaryModelSettingsPage({super.key});

  @override
  ConsumerState<AuxiliaryModelSettingsPage> createState() =>
      _AuxiliaryModelSettingsPageState();
}

class _AuxiliaryModelSettingsPageState
    extends ConsumerState<AuxiliaryModelSettingsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: _buildAppBar(theme),
      body: TabBarView(
        controller: _tabController,
        children: const [AuxiliaryModelTab(), AuxiliaryPromptTab()],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
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
      title: const Text('辅助模型设置'),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: _SegmentedTabBar(controller: _tabController),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Segmented tab bar (pill-style, matches original AetherLink tab pattern)
// ─────────────────────────────────────────────────────────────────────────────

class _SegmentedTabBar extends StatelessWidget {
  const _SegmentedTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
          color: theme.colorScheme.surface,
        ),
        padding: const EdgeInsets.all(3),
        child: TabBar(
          controller: controller,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerHeight: 0,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          labelStyle: theme.textTheme.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(
              height: 36,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.brain, size: 16),
                  SizedBox(width: 6),
                  Text('模型配置'),
                ],
              ),
            ),
            Tab(
              height: 36,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.penLine, size: 16),
                  SizedBox(width: 6),
                  Text('提示词设置'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
