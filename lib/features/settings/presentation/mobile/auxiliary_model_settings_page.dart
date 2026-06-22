import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/model_selector_dialog.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

/// 辅助模型设置 page — a 2-tab layout (top tabs) ported from rikkahub's
/// `SettingModelPage` UI pattern, adapted to our project's card/appbar style.
///
/// Tab 1 — 模型配置: topic naming, intent analysis, vision recognition model
///   selectors with enable/disable toggles and "use current model" option.
/// Tab 2 — 提示词设置: per-feature prompt editors with reset-to-default.
///
/// This is UI-only: selectors, toggles and text fields display their local
/// state but do NOT persist or wire to any backend yet.
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
          _ModelTab(
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
          _PromptTab(
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

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — 模型配置
// ─────────────────────────────────────────────────────────────────────────────

class _ModelTab extends ConsumerWidget {
  const _ModelTab({
    required this.enableTopicNaming,
    required this.topicNamingUseCurrentModel,
    this.topicNamingProviderId,
    this.topicNamingModelId,
    required this.enableIntentAnalysis,
    required this.intentAnalysisUseCurrentModel,
    this.intentAnalysisProviderId,
    this.intentAnalysisModelId,
    required this.enableVisionRecognition,
    this.visionProviderId,
    this.visionModelId,
    required this.onToggleTopicNaming,
    required this.onToggleTopicNamingUseCurrentModel,
    required this.onSelectTopicNamingModel,
    required this.onToggleIntentAnalysis,
    required this.onToggleIntentAnalysisUseCurrentModel,
    required this.onSelectIntentAnalysisModel,
    required this.onToggleVisionRecognition,
    required this.onSelectVisionModel,
  });

  final bool enableTopicNaming;
  final bool topicNamingUseCurrentModel;
  final String? topicNamingProviderId;
  final String? topicNamingModelId;
  final bool enableIntentAnalysis;
  final bool intentAnalysisUseCurrentModel;
  final String? intentAnalysisProviderId;
  final String? intentAnalysisModelId;
  final bool enableVisionRecognition;
  final String? visionProviderId;
  final String? visionModelId;
  final ValueChanged<bool> onToggleTopicNaming;
  final ValueChanged<bool> onToggleTopicNamingUseCurrentModel;
  final void Function(ModelProvider, Model) onSelectTopicNamingModel;
  final ValueChanged<bool> onToggleIntentAnalysis;
  final ValueChanged<bool> onToggleIntentAnalysisUseCurrentModel;
  final void Function(ModelProvider, Model) onSelectIntentAnalysisModel;
  final ValueChanged<bool> onToggleVisionRecognition;
  final void Function(ModelProvider, Model) onSelectVisionModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providers =
        ref.watch(appModelProvidersProvider).asData?.value ?? const [];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── 话题命名 ──
        _SettingCard(
          icon: LucideIcons.type,
          iconColor: const Color(0xFF6366F1),
          title: '话题命名',
          description: '自动为新对话生成简短标题',
          children: [
            _SwitchRow(
              title: '自动命名',
              description: '新对话发送第一条消息后自动生成标题',
              value: enableTopicNaming,
              onChanged: onToggleTopicNaming,
            ),
            if (enableTopicNaming) ...[
              const Divider(height: 1),
              _SwitchRow(
                title: '使用当前对话模型',
                description: '关闭后可指定专门的命名模型',
                value: topicNamingUseCurrentModel,
                onChanged: onToggleTopicNamingUseCurrentModel,
              ),
              if (!topicNamingUseCurrentModel) ...[
                const Divider(height: 1),
                _ModelPickerRow(
                  label: '命名模型',
                  selectedProviderId: topicNamingProviderId,
                  selectedModelId: topicNamingModelId,
                  providers: providers,
                  onSelect: onSelectTopicNamingModel,
                ),
              ],
            ],
          ],
        ),
        const SizedBox(height: 12),

        // ── AI 意图分析 ──
        _SettingCard(
          icon: LucideIcons.lightbulb,
          iconColor: const Color(0xFFF59E0B),
          title: 'AI 意图分析',
          description: '分析用户消息意图，判断是否需要联网搜索',
          children: [
            _SwitchRow(
              title: '启用意图分析',
              description: '发送消息时自动分析是否需要搜索',
              value: enableIntentAnalysis,
              onChanged: onToggleIntentAnalysis,
            ),
            if (enableIntentAnalysis) ...[
              const Divider(height: 1),
              _SwitchRow(
                title: '使用当前对话模型',
                description: '关闭后可指定专门的分析模型',
                value: intentAnalysisUseCurrentModel,
                onChanged: onToggleIntentAnalysisUseCurrentModel,
              ),
              if (!intentAnalysisUseCurrentModel) ...[
                const Divider(height: 1),
                _ModelPickerRow(
                  label: '分析模型',
                  selectedProviderId: intentAnalysisProviderId,
                  selectedModelId: intentAnalysisModelId,
                  providers: providers,
                  onSelect: onSelectIntentAnalysisModel,
                ),
              ],
            ],
          ],
        ),
        const SizedBox(height: 12),

        // ── 视觉识别 ──
        _SettingCard(
          icon: LucideIcons.eye,
          iconColor: const Color(0xFF10B981),
          title: '视觉识别',
          description: '发送图片给不支持视觉的模型时，自动用视觉模型分析图片内容',
          children: [
            _SwitchRow(
              title: '启用视觉识别',
              description: '自动识别并描述图片内容提供给当前模型',
              value: enableVisionRecognition,
              onChanged: onToggleVisionRecognition,
            ),
            if (enableVisionRecognition) ...[
              const Divider(height: 1),
              _ModelPickerRow(
                label: '视觉模型',
                selectedProviderId: visionProviderId,
                selectedModelId: visionModelId,
                providers: providers,
                onSelect: onSelectVisionModel,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // ── 底部说明 ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _footnote(context, '话题命名', '新对话的第一条消息后自动调用模型生成标题'),
              const SizedBox(height: 4),
              _footnote(context, '意图分析', '判断用户是否需要联网搜索，仅在搜索功能启用时生效'),
              const SizedBox(height: 4),
              _footnote(
                context,
                '视觉识别',
                '仅当当前对话模型不支持图片时触发；分析结果只注入本次请求，聊天记录仍保留原图',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _footnote(BuildContext context, String label, String desc) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label — ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: desc),
        ],
      ),
      style: theme.textTheme.bodySmall?.copyWith(
        fontSize: 12,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — 提示词设置
// ─────────────────────────────────────────────────────────────────────────────

class _PromptTab extends StatelessWidget {
  const _PromptTab({
    required this.topicPromptController,
    required this.intentPromptController,
    required this.visionPromptController,
    required this.onResetTopicPrompt,
    required this.onResetIntentPrompt,
    required this.onResetVisionPrompt,
  });

  final TextEditingController topicPromptController;
  final TextEditingController intentPromptController;
  final TextEditingController visionPromptController;
  final VoidCallback onResetTopicPrompt;
  final VoidCallback onResetIntentPrompt;
  final VoidCallback onResetVisionPrompt;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _PromptCard(
          icon: LucideIcons.type,
          iconColor: const Color(0xFF6366F1),
          title: '话题命名提示词',
          description: '用于指导模型如何生成对话标题',
          controller: topicPromptController,
          onReset: onResetTopicPrompt,
        ),
        const SizedBox(height: 12),
        _PromptCard(
          icon: LucideIcons.lightbulb,
          iconColor: const Color(0xFFF59E0B),
          title: '意图分析提示词',
          description: '用于指导模型如何判断用户意图',
          controller: intentPromptController,
          onReset: onResetIntentPrompt,
        ),
        const SizedBox(height: 12),
        _PromptCard(
          icon: LucideIcons.eye,
          iconColor: const Color(0xFF10B981),
          title: '视觉识别提示词',
          description: '用于指导视觉模型如何描述图片内容',
          controller: visionPromptController,
          onReset: onResetVisionPrompt,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared card components
// ─────────────────────────────────────────────────────────────────────────────

/// A bordered card with a colored-icon header, used for both tab 1 sections.
class _SettingCard extends StatelessWidget {
  const _SettingCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.children,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final List<Widget> children;

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
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            color: theme.colorScheme.onSurface.withValues(alpha: 0.015),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
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
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

/// A row with title + description on the left, a custom switch on the right.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12.5,
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
      ),
    );
  }
}

/// A row that shows the currently selected model and a button to pick a new one
/// via the full-screen model selector dialog.
class _ModelPickerRow extends StatelessWidget {
  const _ModelPickerRow({
    required this.label,
    this.selectedProviderId,
    this.selectedModelId,
    required this.providers,
    required this.onSelect,
  });

  final String label;
  final String? selectedProviderId;
  final String? selectedModelId;
  final List<ModelProvider> providers;
  final void Function(ModelProvider, Model) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Resolve the selected model name.
    String displayName = '未选择';
    if (selectedProviderId != null && selectedModelId != null) {
      for (final p in providers) {
        if (p.id == selectedProviderId) {
          for (final m in p.models) {
            if (m.id == selectedModelId) {
              displayName = '${p.name} / ${m.name}';
              break;
            }
          }
          break;
        }
      }
    }

    return InkWell(
      onTap: () => showModelSelectorDialog(
        context,
        onSelect: onSelect,
        selectedProviderId: selectedProviderId,
        selectedModelId: selectedModelId,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                displayName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// A card with a prompt editor and a reset button, used in Tab 2.
class _PromptCard extends StatefulWidget {
  const _PromptCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.controller,
    required this.onReset,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final TextEditingController controller;
  final VoidCallback onReset;

  @override
  State<_PromptCard> createState() => _PromptCardState();
}

class _PromptCardState extends State<_PromptCard> {
  bool _expanded = false;

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
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tappable header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.all(14),
              color: theme.colorScheme.onSurface.withValues(alpha: 0.015),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: widget.iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon, size: 18, color: widget.iconColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12.5,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: widget.controller,
                    maxLines: 8,
                    minLines: 3,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '输入自定义提示词...',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ModelTonalButton(
                      label: '恢复默认',
                      icon: LucideIcons.rotateCcw,
                      onPressed: () {
                        widget.onReset();
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
