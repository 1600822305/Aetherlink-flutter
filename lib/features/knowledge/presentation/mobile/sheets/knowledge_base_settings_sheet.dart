import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/model_selector_dialog.dart';
import 'package:aetherlink_flutter/features/knowledge/application/knowledge_providers.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_base.dart';
import 'package:aetherlink_flutter/features/knowledge/presentation/mobile/widgets/knowledge_common.dart';
import 'package:aetherlink_flutter/features/memory/domain/embedding_model_key.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_checks.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// [KnowledgeBaseSettingsSheet] 的返回值：名称 + RAG 参数 + 检索模式 +
/// 重排模型 + 嵌入模型。
class KnowledgeBaseSettingsResult {
  const KnowledgeBaseSettingsResult({
    required this.name,
    required this.chunkSize,
    required this.chunkOverlap,
    required this.topK,
    required this.threshold,
    required this.searchMode,
    required this.rerankModelKey,
    required this.embeddingModelKey,
  });

  final String name;
  final int chunkSize;
  final int chunkOverlap;
  final int topK;
  final double? threshold;
  final KnowledgeSearchMode searchMode;
  final String? rerankModelKey;
  final String? embeddingModelKey;
}

/// 库设置面板：重命名 + RAG 参数（切块大小 / 重叠 / topK / 相似度阈值）+
/// 检索模式 + 重排序模型（功能缺口⑥，可选）。topK / 阈值用滑杆调节
/// （对齐 CS 的 Slider 设置项）。
class KnowledgeBaseSettingsSheet extends ConsumerStatefulWidget {
  const KnowledgeBaseSettingsSheet({super.key, required this.base});

  final KnowledgeBase base;

  @override
  ConsumerState<KnowledgeBaseSettingsSheet> createState() =>
      _KnowledgeBaseSettingsSheetState();
}

class _KnowledgeBaseSettingsSheetState
    extends ConsumerState<KnowledgeBaseSettingsSheet> {
  late final _nameController = TextEditingController(text: widget.base.name);
  late final _chunkSizeController = TextEditingController(
    text: '${widget.base.chunkSize}',
  );
  late final _chunkOverlapController = TextEditingController(
    text: '${widget.base.chunkOverlap}',
  );
  late int _topK = widget.base.topK.clamp(1, 50);
  late double? _threshold = widget.base.threshold;
  late KnowledgeSearchMode _searchMode = widget.base.searchMode;
  late String? _rerankModelKey = widget.base.rerankModelKey;
  late String? _embeddingModelKey = widget.base.embeddingModelKey;

  @override
  void dispose() {
    _nameController.dispose();
    _chunkSizeController.dispose();
    _chunkOverlapController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppToast.error(context, '名称不能为空');
      return;
    }
    final chunkSize = int.tryParse(_chunkSizeController.text.trim());
    final chunkOverlap = int.tryParse(_chunkOverlapController.text.trim());
    if (chunkSize == null || chunkOverlap == null) {
      AppToast.error(context, '切块大小 / 重叠需为整数');
      return;
    }
    Navigator.of(context).pop(
      KnowledgeBaseSettingsResult(
        name: name,
        chunkSize: chunkSize,
        chunkOverlap: chunkOverlap,
        topK: _topK,
        threshold: _threshold,
        searchMode: _searchMode,
        rerankModelKey: _rerankModelKey,
        embeddingModelKey: _embeddingModelKey,
      ),
    );
  }

  Future<void> _pickEmbeddingModel() async {
    final pair = decodeEmbeddingModelKey(_embeddingModelKey);
    await showModelSelectorDialog(
      context,
      selectedProviderId: pair?.$1,
      selectedModelId: pair?.$2,
      filter: isEmbeddingModel,
      onSelect: (provider, model) {
        setState(() {
          _embeddingModelKey = encodeEmbeddingModelKey(provider.id, model.id);
          // 一旦选了嵌入模型，默认切到混合检索（语义 + 关键词兜底），
          // 与建库面板和服务端 changeEmbeddingModel 的行为一致。
          if (_searchMode == KnowledgeSearchMode.keyword) {
            _searchMode = KnowledgeSearchMode.hybrid;
          }
        });
      },
    );
  }

  String _rerankModelDisplayName(List<ModelProvider> providers) {
    final pair = decodeEmbeddingModelKey(_rerankModelKey);
    if (pair == null) return '未选择（不重排）';
    for (final p in providers) {
      if (p.id != pair.$1) continue;
      for (final m in p.models) {
        if (m.id == pair.$2) return '${p.name} / ${m.name}';
      }
    }
    return '未选择（不重排）';
  }

  Future<void> _pickRerankModel() async {
    final pair = decodeEmbeddingModelKey(_rerankModelKey);
    await showModelSelectorDialog(
      context,
      selectedProviderId: pair?.$1,
      selectedModelId: pair?.$2,
      filter: isRerankModel,
      onSelect: (provider, model) {
        setState(() {
          _rerankModelKey = encodeEmbeddingModelKey(provider.id, model.id);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KnowledgeSheetScaffold(
      title: '库设置',
      confirmLabel: '保存',
      onConfirm: _submit,
      children: [
        const KnowledgeSectionHeader(title: '基本'),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: '名称'),
        ),
        const SizedBox(height: 16),
        const KnowledgeSectionHeader(title: '切块'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _chunkSizeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '切块大小',
                  helperText: '100–10000',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _chunkOverlapController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '切块重叠',
                  helperText: '需小于切块大小',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '修改切块大小 / 重叠后会自动重建整库索引（向量库会按需补嵌，'
          '未变的内容不重复调用嵌入 API）。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        const KnowledgeSectionHeader(title: '检索'),
        _SliderRow(
          label: '返回条数 topK',
          valueLabel: '$_topK',
          value: _topK.toDouble(),
          min: 1,
          max: 50,
          divisions: 49,
          onChanged: (v) => setState(() => _topK = v.round()),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                '相似度阈值',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              _threshold == null ? '不限' : _threshold!.toStringAsFixed(2),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Switch(
              value: _threshold != null,
              onChanged: (on) => setState(() => _threshold = on ? 0.7 : null),
            ),
          ],
        ),
        if (_threshold != null)
          Slider(
            value: _threshold!,
            min: 0,
            max: 1,
            divisions: 100,
            label: _threshold!.toStringAsFixed(2),
            onChanged: (v) => setState(() => _threshold = v),
          ),
        Text(
          '低于阈值的命中会被过滤；关闭则不限。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '检索模式',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        KnowledgeSearchModeSelector(
          mode: _searchMode,
          enableSemantic: _embeddingModelKey != null,
          onChanged: (m) => setState(() => _searchMode = m),
        ),
        if (_embeddingModelKey == null) ...[
          const SizedBox(height: 6),
          Text(
            '未选嵌入模型时仅支持关键词检索',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 16),
        const KnowledgeSectionHeader(title: '嵌入'),
        Text(
          '嵌入模型',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        KnowledgeEmbeddingModelField(
          modelKey: _embeddingModelKey,
          onTap: _pickEmbeddingModel,
        ),
        const SizedBox(height: 4),
        Text(
          '更换嵌入模型后会自动整库重建向量索引（旧模型的向量随之清理，'
          '全部内容需重新调用嵌入 API，注意耗时与费用）；'
          '纯关键词库选上模型后自动升级为混合检索。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '重排序模型',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: _pickRerankModel,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  LucideIcons.arrowDownUp,
                  size: 18,
                  color: _rerankModelKey != null
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _rerankModelDisplayName(
                      ref.watch(appModelProvidersProvider).asData?.value ??
                          const <ModelProvider>[],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _rerankModelKey != null
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (_rerankModelKey != null)
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 16),
                    visualDensity: VisualDensity.compact,
                    tooltip: '关闭重排',
                    onPressed: () => setState(() => _rerankModelKey = null),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '选了重排模型后，检索命中会再经 rerank API 按相关性重排；'
          '调用失败时自动保持原排序。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 带标签和当前值的滑杆行（topK 等整数参数用）。
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              valueLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: valueLabel,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// 嵌入模型选择行：展示当前模型（点击弹出模型选择器）+ 维度探测提示
/// （复用建库时的 knowledgeEmbeddingDimensionsProvider）。
class KnowledgeEmbeddingModelField extends ConsumerWidget {
  const KnowledgeEmbeddingModelField({
    super.key,
    required this.modelKey,
    required this.onTap,
  });

  final String? modelKey;
  final VoidCallback onTap;

  String _displayName(List<ModelProvider> providers) {
    final pair = decodeEmbeddingModelKey(modelKey);
    if (pair == null) return '未选择（纯关键词检索）';
    for (final p in providers) {
      if (p.id != pair.$1) continue;
      for (final m in p.models) {
        if (m.id == pair.$2) return '${p.name} / ${m.name}';
      }
    }
    return '${pair.$1} / ${pair.$2}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasModel = modelKey != null;
    final providers =
        ref.watch(appModelProvidersProvider).asData?.value ??
        const <ModelProvider>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  LucideIcons.boxes,
                  size: 18,
                  color: hasModel
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _displayName(providers),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: hasModel
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasModel) KnowledgeEmbeddingDimensionHint(modelKey: modelKey!),
      ],
    );
  }
}

/// 嵌入模型的维度探测提示（同建库面板）：选中模型后真实调一次嵌入 API 展示
/// 「向量维度：N」；探测中显示进度、失败提示不阻断保存。
class KnowledgeEmbeddingDimensionHint extends ConsumerWidget {
  const KnowledgeEmbeddingDimensionHint({super.key, required this.modelKey});

  final String modelKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(knowledgeEmbeddingDimensionsProvider(modelKey));
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final Widget child;
    if (async.isLoading) {
      child = Row(
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 6),
          Text('正在探测向量维度…', style: style),
        ],
      );
    } else {
      final dimensions = async.asData?.value;
      child = Text(
        dimensions == null ? '维度探测失败（模型可能不可用）' : '向量维度：$dimensions',
        style: dimensions == null
            ? style
            : style?.copyWith(color: theme.colorScheme.primary),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2, left: 26),
      child: child,
    );
  }
}
