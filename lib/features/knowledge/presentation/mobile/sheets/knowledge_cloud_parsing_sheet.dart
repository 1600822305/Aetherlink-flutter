import 'package:flutter/material.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_file_processor.dart';
import 'package:aetherlink_flutter/features/knowledge/presentation/mobile/widgets/knowledge_common.dart';

/// 云端解析设置面板（§5.2）：解析方式下拉 + 对应服务的 API Key。
class KnowledgeCloudParsingSheet extends StatefulWidget {
  const KnowledgeCloudParsingSheet({
    super.key,
    required this.initialProcessor,
    required this.initialKeys,
  });

  final KnowledgeFileProcessor? initialProcessor;
  final Map<KnowledgeFileProcessor, String> initialKeys;

  @override
  State<KnowledgeCloudParsingSheet> createState() =>
      _KnowledgeCloudParsingSheetState();
}

class _KnowledgeCloudParsingSheetState
    extends State<KnowledgeCloudParsingSheet> {
  late KnowledgeFileProcessor? _selected = widget.initialProcessor;
  late final Map<KnowledgeFileProcessor, TextEditingController>
  _keyControllers = {
    for (final p in KnowledgeFileProcessor.values)
      p: TextEditingController(text: widget.initialKeys[p] ?? ''),
  };

  @override
  void dispose() {
    for (final c in _keyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return KnowledgeSheetScaffold(
      title: '云端解析设置',
      confirmLabel: '保存',
      onConfirm: () => Navigator.of(context).pop((
        processor: _selected,
        key: _selected == null ? '' : _keyControllers[_selected]!.text,
      )),
      children: [
        DropdownButtonFormField<KnowledgeFileProcessor?>(
          initialValue: selected,
          decoration: const InputDecoration(labelText: 'PDF / DOCX 解析方式'),
          items: [
            const DropdownMenuItem<KnowledgeFileProcessor?>(
              value: null,
              child: Text('本地解析（默认，不上传）'),
            ),
            for (final p in KnowledgeFileProcessor.values)
              DropdownMenuItem<KnowledgeFileProcessor?>(
                value: p,
                child: Text(p.label),
              ),
          ],
          onChanged: (value) => setState(() => _selected = value),
        ),
        if (selected != null) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _keyControllers[selected]!,
            obscureText: true,
            decoration: InputDecoration(labelText: '${selected.label} API Key'),
          ),
          const SizedBox(height: 12),
          Text(
            '启用后本库的 PDF / DOCX 会上传到 ${selected.label} '
            '解析为 Markdown（注意隐私与费用）；解析结果作为权威快照'
            '落库，重建索引不会重复调用云端。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
