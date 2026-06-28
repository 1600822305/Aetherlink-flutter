import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/model_selector_dialog.dart';
import 'package:aetherlink_flutter/features/memory/application/memory_settings_controller.dart';
import 'package:aetherlink_flutter/features/memory/domain/embedding_model_key.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_settings.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

/// 记忆设置 (记忆 → 记忆设置) — the configuration sub-page governing how stored
/// memories are provided to the model: the injection mode, the embedding model
/// powering 向量检索, plus the advanced numeric knobs (token 预算 / topK / 全量阈值).
/// Everything reads and writes [MemorySettingsController] (a single JSON blob in
/// the KV store), so changes take effect on the next turn.
class MemorySettingsPage extends ConsumerWidget {
  const MemorySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final config = ref.watch(memorySettingsControllerProvider);
    final controller = ref.read(memorySettingsControllerProvider.notifier);
    final advancedEnabled = config.injectionMode != MemoryInjectionMode.off;

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
            onPressed: () => context.pop(),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: const Text('记忆设置'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          const _GroupLabel('注入方式'),
          const SizedBox(height: 6),
          _OutlinedCard(
            child: Column(
              children: [
                for (var i = 0; i < MemoryInjectionMode.values.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: theme.dividerColor),
                  _ModeRow(
                    mode: MemoryInjectionMode.values[i],
                    selected:
                        config.injectionMode == MemoryInjectionMode.values[i],
                    onTap: () =>
                        controller.setInjectionMode(MemoryInjectionMode.values[i]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _GroupLabel('嵌入模型'),
          const SizedBox(height: 6),
          _OutlinedCard(
            child: _EmbeddingModelRow(
              modelKey: config.embeddingModelKey,
              onSelect: controller.setEmbeddingModelKey,
            ),
          ),
          const SizedBox(height: 14),
          const _GroupLabel('高级参数'),
          const SizedBox(height: 6),
          Opacity(
            opacity: advancedEnabled ? 1 : 0.5,
            child: IgnorePointer(
              ignoring: !advancedEnabled,
              child: _OutlinedCard(
                child: Column(
                  children: [
                    _StepperRow(
                      icon: LucideIcons.coins,
                      accent: const Color(0xFFF59E0B),
                      label: 'token 预算',
                      description: '每轮注入记忆的 token 上限，超出按重要性截断',
                      value: config.tokenBudget,
                      min: 0,
                      max: 8000,
                      step: 100,
                      onChanged: controller.setTokenBudget,
                    ),
                    Divider(height: 1, color: theme.dividerColor),
                    _StepperRow(
                      icon: LucideIcons.listOrdered,
                      accent: const Color(0xFF06B6D4),
                      label: 'topK',
                      description: '向量检索时注入的记忆条数',
                      value: config.topK,
                      min: 1,
                      max: 50,
                      step: 1,
                      onChanged: controller.setTopK,
                    ),
                    Divider(height: 1, color: theme.dividerColor),
                    _StepperRow(
                      icon: LucideIcons.layers,
                      accent: const Color(0xFF10B981),
                      label: '全量阈值',
                      description: 'auto 模式下，条数低于此值时改为全量注入',
                      value: config.fullDumpThreshold,
                      min: 0,
                      max: 200,
                      step: 5,
                      onChanged: controller.setFullDumpThreshold,
                    ),
                    Divider(height: 1, color: theme.dividerColor),
                    _StepperRow(
                      icon: LucideIcons.trash2,
                      accent: const Color(0xFFEF4444),
                      label: '保留天数',
                      description: '整理记忆时，永久清理已删除超过此天数的记忆',
                      value: config.retentionDays,
                      min: 0,
                      max: 365,
                      step: 1,
                      onChanged: controller.setRetentionDays,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const _GroupLabel('检索排序'),
          const SizedBox(height: 6),
          _OutlinedCard(
            child: _ToggleRow(
              icon: LucideIcons.brain,
              accent: const Color(0xFF8B5CF6),
              label: '激活加权排序',
              description: '向量检索在相似度主导的基础上，叠加近因/命中/重要性加权（语义与高重要记忆不因时间衰减）；关闭则按纯余弦排序',
              value: config.activationRanking,
              onChanged: controller.setActivationRanking,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '注入方式选择「关闭」时，本轮不会注入任何记忆。向量检索（semantic / auto）会用上方所选嵌入模型把当前提问与记忆比对取 top-k；未配置嵌入模型时自动退回关键词检索。',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              height: 1.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chinese label + one-line description for each [MemoryInjectionMode].
({String label, String description}) _modeText(MemoryInjectionMode mode) {
  switch (mode) {
    case MemoryInjectionMode.auto:
      return (label: '分级 auto', description: '全局全量 + 助手向量 top-k，小集合自动转全量（推荐）');
    case MemoryInjectionMode.full:
      return (label: '全量注入', description: '把范围内全部记忆塞进 prompt，零漏召回但更耗 token');
    case MemoryInjectionMode.semantic:
      return (label: '向量检索', description: '仅注入相似度 top-k，精准省 token');
    case MemoryInjectionMode.keyword:
      return (label: '文本检索', description: '关键词匹配，不调用嵌入，纯本地');
    case MemoryInjectionMode.tool:
      return (label: '工具自取', description: '提供 search_memory 工具，由模型按需检索');
    case MemoryInjectionMode.off:
      return (label: '关闭', description: '临时关闭记忆注入');
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final MemoryInjectionMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = _modeText(mode);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      text.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                selected ? LucideIcons.circleCheck : LucideIcons.circle,
                size: 20,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Picker row for the embedding model backing 向量检索. Resolves the persisted
/// composite key to a `提供商 / 模型` display name, opens the shared model
/// selector on tap (writing the chosen pair back as a key), and offers a clear
/// action when one is set.
class _EmbeddingModelRow extends ConsumerWidget {
  const _EmbeddingModelRow({required this.modelKey, required this.onSelect});

  final String? modelKey;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final providers = ref.watch(appModelProvidersProvider).asData?.value ??
        const <ModelProvider>[];
    final pair = decodeEmbeddingModelKey(modelKey);
    String? selectedProviderId;
    String? selectedModelId;
    String displayName = '未配置';
    if (pair != null) {
      selectedProviderId = pair.$1;
      selectedModelId = pair.$2;
      for (final p in providers) {
        if (p.id != selectedProviderId) continue;
        for (final m in p.models) {
          if (m.id == selectedModelId) {
            displayName = '${p.name} / ${m.name}';
            break;
          }
        }
        break;
      }
    }
    final configured = pair != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showModelSelectorDialog(
          context,
          onSelect: (p, m) => onSelect(encodeEmbeddingModelKey(p.id, m.id)),
          selectedProviderId: selectedProviderId,
          selectedModelId: selectedModelId,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  LucideIcons.boxes,
                  size: 18,
                  color: Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '嵌入模型',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: configured
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (configured)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 32, height: 32),
                  icon: const Icon(LucideIcons.x, size: 16),
                  color: theme.colorScheme.onSurfaceVariant,
                  onPressed: () => onSelect(null),
                ),
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.icon,
    required this.accent,
    required this.label,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String description;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: accent),
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
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StepButton(
            icon: LucideIcons.minus,
            enabled: value > min,
            onTap: () => onChanged((value - step).clamp(min, max)),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          _StepButton(
            icon: LucideIcons.plus,
            enabled: value < max,
            onTap: () => onChanged((value + step).clamp(min, max)),
          ),
        ],
      ),
    );
  }
}

/// A labelled switch row matching [_StepperRow]'s layout (icon tile + title +
/// description), with a [CustomSwitch] trailing.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
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
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: accent),
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
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    height: 1.4,
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

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icon,
            size: 16,
            color: enabled
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

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
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _OutlinedCard extends StatelessWidget {
  const _OutlinedCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
