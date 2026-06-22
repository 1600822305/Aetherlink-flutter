import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/model_selector_dialog.dart';
import 'package:aetherlink_flutter/features/settings/application/auxiliary_model_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

/// Descriptor for one auxiliary model tab.
class _TabDescriptor {
  const _TabDescriptor({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.description,
    this.hasPrompt = false,
    this.hasToggle = false,
    this.clearable = false,
    this.footnote,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final String description;
  final bool hasPrompt;
  final bool hasToggle;
  final bool clearable;
  final String? footnote;
}

const _tabs = <_TabDescriptor>[
  _TabDescriptor(
    label: '聊天',
    icon: LucideIcons.messageCircle,
    iconColor: Color(0xFF6366F1),
    description: '主要对话使用的模型',
    footnote: '选择后同步为当前聊天模型',
  ),
  _TabDescriptor(
    label: '快速',
    icon: LucideIcons.zap,
    iconColor: Color(0xFFF59E0B),
    description: '用于需要快速响应的场景（如自动补全等）',
  ),
  _TabDescriptor(
    label: '标题',
    icon: LucideIcons.type,
    iconColor: Color(0xFF8B5CF6),
    description: '自动为新对话生成简短标题',
    hasPrompt: true,
    clearable: true,
    footnote: '未设置时使用聊天模型生成标题',
  ),
  _TabDescriptor(
    label: '建议',
    icon: LucideIcons.lightbulb,
    iconColor: Color(0xFF10B981),
    description: '为用户生成后续问题建议',
    hasPrompt: true,
    hasToggle: true,
    clearable: true,
    footnote: '未设置时不生成后续问题建议',
  ),
  _TabDescriptor(
    label: '翻译',
    icon: LucideIcons.languages,
    iconColor: Color(0xFF3B82F6),
    description: '用于消息翻译功能',
    hasPrompt: true,
    footnote: '未设置时使用聊天模型进行翻译',
  ),
  _TabDescriptor(
    label: 'OCR',
    icon: LucideIcons.eye,
    iconColor: Color(0xFFEC4899),
    description: '视觉识别，图片内容描述与文字提取',
    hasPrompt: true,
    footnote: '未设置时使用聊天模型识别图片',
  ),
  _TabDescriptor(
    label: '压缩',
    icon: LucideIcons.foldVertical,
    iconColor: Color(0xFF14B8A6),
    description: '智能压缩对话历史，节省 Token 成本',
    hasPrompt: true,
    footnote: '未设置时使用聊天模型压缩历史',
  ),
];

/// 辅助模型设置 page — 7 scrollable tabs, each for one model type.
/// Matches the AetherLink web original's tab-per-model structure.
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
    _tabController = TabController(length: _tabs.length, vsync: this);
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
        title: const Text('辅助模型设置'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _SegmentedTabBar(controller: _tabController),
        ),
      ),
      body: SafeArea(
        top: false,
        child: TabBarView(
          controller: _tabController,
          children: [
            for (var i = 0; i < _tabs.length; i++)
              _ModelConfigTab(index: i, descriptor: _tabs[i]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scrollable segmented tab bar
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
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerHeight: 0,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          labelStyle: theme.textTheme.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
          tabs: [
            for (final t in _tabs)
              Tab(
                height: 34,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t.icon, size: 15),
                    const SizedBox(width: 5),
                    Text(t.label),
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
// Per-model tab content
// ─────────────────────────────────────────────────────────────────────────────

class _ModelConfigTab extends ConsumerStatefulWidget {
  const _ModelConfigTab({required this.index, required this.descriptor});

  final int index;
  final _TabDescriptor descriptor;

  @override
  ConsumerState<_ModelConfigTab> createState() => _ModelConfigTabState();
}

class _ModelConfigTabState extends ConsumerState<_ModelConfigTab>
    with AutomaticKeepAliveClientMixin {
  TextEditingController? _promptController;
  bool _promptInitialized = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.descriptor.hasPrompt) {
      _promptController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _promptController?.dispose();
    super.dispose();
  }

  // Map tab index → state field accessors
  String? _modelKey(AuxiliaryModelState s) => switch (widget.index) {
    0 => s.chatModelKey,
    1 => s.fastModelKey,
    2 => s.titleModelKey,
    3 => s.suggestionModelKey,
    4 => s.translateModelKey,
    5 => s.ocrModelKey,
    6 => s.compressModelKey,
    _ => null,
  };

  void _onModelSelect(AuxiliaryModelController ctrl, ModelProvider p, Model m) {
    switch (widget.index) {
      case 0:
        ctrl.setChatModel(p.id, m.id);
      case 1:
        ctrl.setFastModel(p.id, m.id);
      case 2:
        ctrl.setTitleModel(p.id, m.id);
      case 3:
        ctrl.setSuggestionModel(p.id, m.id);
      case 4:
        ctrl.setTranslateModel(p.id, m.id);
      case 5:
        ctrl.setOcrModel(p.id, m.id);
      case 6:
        ctrl.setCompressModel(p.id, m.id);
    }
  }

  void _onClear(AuxiliaryModelController ctrl) {
    switch (widget.index) {
      case 2:
        ctrl.clearTitleModel();
      case 3:
        ctrl.clearSuggestionModel();
    }
  }

  String _promptValue(AuxiliaryModelState s) => switch (widget.index) {
    2 => s.titlePrompt,
    3 => s.suggestionPrompt,
    4 => s.translatePrompt,
    5 => s.ocrPrompt,
    6 => s.compressPrompt,
    _ => '',
  };

  void _onPromptChanged(AuxiliaryModelController ctrl, String value) {
    switch (widget.index) {
      case 2:
        ctrl.setTitlePrompt(value);
      case 3:
        ctrl.setSuggestionPrompt(value);
      case 4:
        ctrl.setTranslatePrompt(value);
      case 5:
        ctrl.setOcrPrompt(value);
      case 6:
        ctrl.setCompressPrompt(value);
    }
  }

  void _onPromptReset(AuxiliaryModelController ctrl) {
    switch (widget.index) {
      case 2:
        ctrl.resetTitlePrompt();
        _promptController?.text = kDefaultTitlePrompt;
      case 3:
        ctrl.resetSuggestionPrompt();
        _promptController?.text = kDefaultSuggestionPrompt;
      case 4:
        ctrl.resetTranslatePrompt();
        _promptController?.text = kDefaultTranslatePrompt;
      case 5:
        ctrl.resetOcrPrompt();
        _promptController?.text = kDefaultOcrPrompt;
      case 6:
        ctrl.resetCompressPrompt();
        _promptController?.text = kDefaultCompressPrompt;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final providers =
        ref.watch(appModelProvidersProvider).asData?.value ?? const [];
    final state = ref.watch(auxiliaryModelControllerProvider);
    final ctrl = ref.read(auxiliaryModelControllerProvider.notifier);
    final desc = widget.descriptor;

    // Sync prompt controller on first build
    if (desc.hasPrompt && !_promptInitialized && _promptController != null) {
      _promptController!.text = _promptValue(state);
      _promptInitialized = true;
    }

    final modelKey = _modelKey(state);

    // Resolve display name
    String? selectedProviderId;
    String? selectedModelId;
    String displayName = '未选择';
    if (modelKey != null && modelKey.isNotEmpty) {
      final parts = modelKey.split('\u0000');
      if (parts.length == 2) {
        selectedProviderId = parts[0];
        selectedModelId = parts[1];
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
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── Header card ──
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon + title + description header
              Container(
                padding: const EdgeInsets.all(14),
                color: theme.colorScheme.onSurface.withValues(alpha: 0.015),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: desc.iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(desc.icon, size: 20, color: desc.iconColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${desc.label}模型',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            desc.description,
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

              // Optional toggle (suggestion model)
              if (desc.hasToggle) ...[
                _ToggleRow(
                  title: '启用${desc.label}',
                  description: '开启后将使用此模型生成建议',
                  value: state.enableSuggestion,
                  onChanged: ctrl.setEnableSuggestion,
                ),
                const Divider(height: 1),
              ],

              // Model picker row
              InkWell(
                onTap: () => showModelSelectorDialog(
                  context,
                  onSelect: (p, m) => _onModelSelect(ctrl, p, m),
                  selectedProviderId: selectedProviderId,
                  selectedModelId: selectedModelId,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '选择模型',
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
              ),

              // Optional clear button
              if (desc.clearable &&
                  modelKey != null &&
                  modelKey.isNotEmpty) ...[
                const Divider(height: 1),
                InkWell(
                  onTap: () => _onClear(ctrl),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.x,
                          size: 16,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '清除选择',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Prompt card ──
        if (desc.hasPrompt && _promptController != null) ...[
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.015),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.penLine,
                        size: 18,
                        color: desc.iconColor,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${desc.label}提示词',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _promptController,
                        maxLines: 8,
                        minLines: 3,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                        ),
                        onChanged: (v) => _onPromptChanged(ctrl, v),
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
                            _onPromptReset(ctrl);
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // ── Footnote ──
        if (desc.footnote != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              desc.footnote!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Building blocks
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

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
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [child],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
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
