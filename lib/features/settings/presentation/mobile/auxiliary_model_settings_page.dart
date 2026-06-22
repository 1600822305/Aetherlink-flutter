import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/auxiliary_model_tab.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/auxiliary_prompt_tab.dart';

/// 辅助模型设置 page — a 2-tab layout (top tabs) ported from rikkahub's
/// `SettingModelPage` UI pattern, adapted to our project's card/appbar style.
///
/// Tab 1 — 模型配置  → [AuxiliaryModelTab]
/// Tab 2 — 提示词设置 → [AuxiliaryPromptTab]
///
/// This is the page shell (AppBar + segmented tab bar + state). The two tab
/// bodies live in their own files for independent reuse.
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

  // ── Tab 1: model selections (local state only) ──
  bool _enableTopicNaming = true;
  bool _topicNamingUseCurrentModel = true;
  String? _topicNamingProviderId;
  String? _topicNamingModelId;

  bool _enableIntentAnalysis = false;
  bool _intentAnalysisUseCurrentModel = true;
  String? _intentAnalysisProviderId;
  String? _intentAnalysisModelId;

  bool _enableVisionRecognition = false;
  String? _visionProviderId;
  String? _visionModelId;

  // ── Tab 2: prompt values (local state only) ──
  late final TextEditingController _topicPromptController;
  late final TextEditingController _intentPromptController;
  late final TextEditingController _visionPromptController;

  static const String _defaultTopicPrompt =
      '你是一个对话标题生成助手。请根据对话内容生成一个简短的标题（不超过20字），不需要解释。';
  static const String _defaultIntentPrompt =
      '你是一个意图分析助手。请根据用户的消息分析其意图，判断是否需要联网搜索，返回JSON格式。';
  static const String _defaultVisionPrompt =
      '请描述这张图片的内容，包括主要对象、场景、颜色和任何文字。尽可能详细地描述，以便不能看到图片的人也能理解图片内容。';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _topicPromptController = TextEditingController(text: _defaultTopicPrompt);
    _intentPromptController = TextEditingController(text: _defaultIntentPrompt);
    _visionPromptController = TextEditingController(text: _defaultVisionPrompt);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _topicPromptController.dispose();
    _intentPromptController.dispose();
    _visionPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: _buildAppBar(theme),
      body: TabBarView(
        controller: _tabController,
        children: [
          AuxiliaryModelTab(
            enableTopicNaming: _enableTopicNaming,
            topicNamingUseCurrentModel: _topicNamingUseCurrentModel,
            topicNamingProviderId: _topicNamingProviderId,
            topicNamingModelId: _topicNamingModelId,
            enableIntentAnalysis: _enableIntentAnalysis,
            intentAnalysisUseCurrentModel: _intentAnalysisUseCurrentModel,
            intentAnalysisProviderId: _intentAnalysisProviderId,
            intentAnalysisModelId: _intentAnalysisModelId,
            enableVisionRecognition: _enableVisionRecognition,
            visionProviderId: _visionProviderId,
            visionModelId: _visionModelId,
            onToggleTopicNaming: (v) => setState(() => _enableTopicNaming = v),
            onToggleTopicNamingUseCurrentModel: (v) =>
                setState(() => _topicNamingUseCurrentModel = v),
            onSelectTopicNamingModel: (p, m) => setState(() {
              _topicNamingProviderId = p.id;
              _topicNamingModelId = m.id;
            }),
            onToggleIntentAnalysis: (v) =>
                setState(() => _enableIntentAnalysis = v),
            onToggleIntentAnalysisUseCurrentModel: (v) =>
                setState(() => _intentAnalysisUseCurrentModel = v),
            onSelectIntentAnalysisModel: (p, m) => setState(() {
              _intentAnalysisProviderId = p.id;
              _intentAnalysisModelId = m.id;
            }),
            onToggleVisionRecognition: (v) =>
                setState(() => _enableVisionRecognition = v),
            onSelectVisionModel: (p, m) => setState(() {
              _visionProviderId = p.id;
              _visionModelId = m.id;
            }),
          ),
          AuxiliaryPromptTab(
            topicPromptController: _topicPromptController,
            intentPromptController: _intentPromptController,
            visionPromptController: _visionPromptController,
            onResetTopicPrompt: () =>
                _topicPromptController.text = _defaultTopicPrompt,
            onResetIntentPrompt: () =>
                _intentPromptController.text = _defaultIntentPrompt,
            onResetVisionPrompt: () =>
                _visionPromptController.text = _defaultVisionPrompt,
          ),
        ],
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
