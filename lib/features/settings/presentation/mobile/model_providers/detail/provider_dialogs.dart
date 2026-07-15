import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/provider_config_utils.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:aetherlink_flutter/shared/widgets/app_select_field.dart';

/// The 编辑供应商 dialog (name + provider type). Pops `(name, type)` on save, or
/// null on cancel. Mirrors the original `handleEditProviderName`.
class EditProviderDialog extends StatefulWidget {
  const EditProviderDialog({super.key, required this.provider});

  final ModelProvider provider;

  @override
  State<EditProviderDialog> createState() => _EditProviderDialogState();
}

class _EditProviderDialogState extends State<EditProviderDialog> {
  late final TextEditingController _name;
  String? _type;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.provider.name);
    final stored = normalizeProviderType(widget.provider.providerType);
    _type = providerTypeOptions.any((o) => o.$1 == stored) ? stored : null;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _name.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('编辑供应商', style: TextStyle(fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '供应商名称',
                hintText: '例如: 我的智谱AI',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            AppSelectField<String?>(
              value: _type,
              label: '供应商类型',
              sheetTitle: '供应商类型',
              placeholder: '请选择',
              options: [
                for (final option in providerTypeOptions)
                  AppSelectOption<String?>(value: option.$1, label: option.$2),
              ],
              onChanged: (value) => setState(() => _type = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: canSave
              ? () => Navigator.of(context).pop((_name.text.trim(), _type))
              : null,
          child: const Text('保存'),
        ),
      ],
    );
  }
}

/// The 自定义获取端点 dialog. It owns the endpoint field's
/// [TextEditingController] so the controller is disposed by the framework when
/// the dialog route unmounts, not while the field is still being torn down.
class CustomEndpointDialog extends StatefulWidget {
  const CustomEndpointDialog({super.key, required this.initial});

  final String initial;

  @override
  State<CustomEndpointDialog> createState() => _CustomEndpointDialogState();
}

class _CustomEndpointDialogState extends State<CustomEndpointDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        '自定义获取端点',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '端点 URL',
              hintText: 'https://api.example.com/v1',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '用于本次「获取模型」的基础 URL，不会修改已保存的基础 URL。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('获取'),
        ),
      ],
    );
  }
}
