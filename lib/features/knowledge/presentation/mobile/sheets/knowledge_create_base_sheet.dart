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

/// 嵌入模型的维度探测提示（功能缺口⑨）：选中模型后真实调一次嵌入 API，
/// 展示「向量维度：N」；探测中显示进度、失败提示不阻断创建。
class _DimensionHint extends ConsumerWidget {
  const _DimensionHint({required this.modelKey});

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
        dimensions == null ? '维度探测失败（不影响创建）' : '向量维度：$dimensions',
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

/// The choices returned by [KnowledgeCreateBaseSheet]. [embeddingModelKey] is null for
/// a pure keyword base; when set, [searchMode] is vector or hybrid.
class KnowledgeCreateBaseResult {
  const KnowledgeCreateBaseResult({
    required this.name,
    required this.embeddingModelKey,
    required this.searchMode,
  });

  final String name;
  final String? embeddingModelKey;
  final KnowledgeSearchMode searchMode;
}

/// 新建知识库面板：名称 + 可选嵌入模型 + 检索模式。未选嵌入模型时锁定关键词检索
/// （与服务端 `createBase` 的约束一致，避免建出「向量库却无从嵌入」的坏状态）。
class KnowledgeCreateBaseSheet extends ConsumerStatefulWidget {
  const KnowledgeCreateBaseSheet({super.key});

  @override
  ConsumerState<KnowledgeCreateBaseSheet> createState() =>
      _KnowledgeCreateBaseSheetState();
}

class _KnowledgeCreateBaseSheetState
    extends ConsumerState<KnowledgeCreateBaseSheet> {
  final _controller = TextEditingController();
  String? _modelKey;
  KnowledgeSearchMode _mode = KnowledgeSearchMode.keyword;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _modelDisplayName(List<ModelProvider> providers) {
    final pair = decodeEmbeddingModelKey(_modelKey);
    if (pair == null) return '未选择（纯关键词检索）';
    for (final p in providers) {
      if (p.id != pair.$1) continue;
      for (final m in p.models) {
        if (m.id == pair.$2) return '${p.name} / ${m.name}';
      }
    }
    return '未选择（纯关键词检索）';
  }

  Future<void> _pickModel() async {
    final pair = decodeEmbeddingModelKey(_modelKey);
    await showModelSelectorDialog(
      context,
      selectedProviderId: pair?.$1,
      selectedModelId: pair?.$2,
      filter: isEmbeddingModel,
      onSelect: (provider, model) {
        setState(() {
          _modelKey = encodeEmbeddingModelKey(provider.id, model.id);
          // 一旦选了嵌入模型，默认切到混合检索（语义 + 关键词兜底）。
          if (_mode == KnowledgeSearchMode.keyword) {
            _mode = KnowledgeSearchMode.hybrid;
          }
        });
      },
    );
  }

  void _clearModel() {
    setState(() {
      _modelKey = null;
      _mode = KnowledgeSearchMode.keyword;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final providers =
        ref.watch(appModelProvidersProvider).asData?.value ??
        const <ModelProvider>[];
    final hasModel = _modelKey != null;

    return KnowledgeSheetScaffold(
      title: '新建知识库',
      confirmLabel: '创建',
      onConfirm: _controller.text.trim().isEmpty
          ? null
          : () => Navigator.of(context).pop(
              KnowledgeCreateBaseResult(
                name: _controller.text.trim(),
                embeddingModelKey: _modelKey,
                searchMode: _mode,
              ),
            ),
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '名称'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Text(
          '嵌入模型',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: _pickModel,
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
                    _modelDisplayName(providers),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: hasModel
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (hasModel)
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 16),
                    visualDensity: VisualDensity.compact,
                    tooltip: '清除',
                    onPressed: _clearModel,
                  ),
              ],
            ),
          ),
        ),
        if (hasModel) _DimensionHint(modelKey: _modelKey!),
        const SizedBox(height: 12),
        Text(
          '检索模式',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        KnowledgeSearchModeSelector(
          mode: _mode,
          enableSemantic: hasModel,
          onChanged: (m) => setState(() => _mode = m),
        ),
        if (!hasModel) ...[
          const SizedBox(height: 6),
          Text(
            '未选嵌入模型时仅支持关键词检索',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
