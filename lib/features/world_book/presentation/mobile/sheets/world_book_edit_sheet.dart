// 新建 / 重命名世界书：书名 + 描述。

import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/features/world_book/presentation/mobile/widgets/world_book_common.dart';

/// [WorldBookEditSheet] 的结果。
class WorldBookEditResult {
  const WorldBookEditResult({required this.name, required this.description});

  final String name;
  final String description;
}

class WorldBookEditSheet extends StatefulWidget {
  const WorldBookEditSheet({
    super.key,
    required this.title,
    this.initialName = '',
    this.initialDescription = '',
  });

  final String title;
  final String initialName;
  final String initialDescription;

  @override
  State<WorldBookEditSheet> createState() => _WorldBookEditSheetState();
}

class _WorldBookEditSheetState extends State<WorldBookEditSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.initialDescription,
  );

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      WorldBookEditResult(name: name, description: _description.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WorldBookSheetScaffold(
      title: widget.title,
      confirmLabel: '保存',
      onConfirm: _name.text.trim().isEmpty ? null : _submit,
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          decoration: const InputDecoration(labelText: '名称'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _description,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(labelText: '描述（可选）'),
        ),
      ],
    );
  }
}
