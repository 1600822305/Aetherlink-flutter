import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/model_selector/model_selector_dialog.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_base.dart';
import 'package:aetherlink_flutter/features/knowledge/presentation/mobile/sheets/knowledge_base_settings_sheet.dart';
import 'package:aetherlink_flutter/features/knowledge/presentation/mobile/widgets/knowledge_common.dart';
import 'package:aetherlink_flutter/features/memory/domain/embedding_model_key.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_checks.dart';

/// 换模型重建面板（参考 CS RestoreKnowledgeBaseDialog）：说明当前库的嵌入
/// 状况，选一个可用的嵌入模型后 pop 出模型键，由页面执行整库重建恢复。
class KnowledgeRestoreEmbeddingSheet extends ConsumerStatefulWidget {
  const KnowledgeRestoreEmbeddingSheet({super.key, required this.base});

  final KnowledgeBase base;

  @override
  ConsumerState<KnowledgeRestoreEmbeddingSheet> createState() =>
      _KnowledgeRestoreEmbeddingSheetState();
}

class _KnowledgeRestoreEmbeddingSheetState
    extends ConsumerState<KnowledgeRestoreEmbeddingSheet> {
  late String? _modelKey = widget.base.embeddingModelKey;

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
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modelKey = _modelKey;
    return KnowledgeSheetScaffold(
      title: '换模型重建',
      confirmLabel: '重建恢复',
      onConfirm: modelKey == null
          ? null
          : () => Navigator.of(context).pop(modelKey),
      children: [
        Text(
          '本库存在嵌入未完成的切块（嵌入失败或模型不可用）。选择一个可用的'
          '嵌入模型后将整库重建向量索引：旧模型的向量会被清理，全部内容需'
          '重新调用嵌入 API（注意耗时与费用）。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '嵌入模型',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        KnowledgeEmbeddingModelField(modelKey: _modelKey, onTap: _pickModel),
      ],
    );
  }
}
