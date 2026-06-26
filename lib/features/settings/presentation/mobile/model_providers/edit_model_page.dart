import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/shared/widgets/app_select_field.dart';
import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:aetherlink_flutter/shared/domain/parameter_metadata.dart';

/// The "编辑模型" third-level page, a 1:1 reproduction of
/// `src/pages/Settings/ModelProviders/EditModelPage.tsx` (whose form body is the
/// `EditModelForm.solid` component).
///
/// Reads the provider by [providerId]; when [modelId] is given the form is
/// seeded from that model (edit), otherwise it starts blank (add). 保存 upserts
/// the model into the provider's `models` and persists through the model store.
/// The model-type chips stay advisory (auto-detect) this milestone.
class EditModelPage extends ConsumerStatefulWidget {
  const EditModelPage({super.key, required this.providerId, this.modelId});

  final String providerId;
  final String? modelId;

  static const String _title = '编辑模型';
  static const String _saveLabel = '保存';
  static const String _avatarTitle = '模型头像';
  static const String _avatarDesc = '为此模型设置自定义头像';
  static const String _nameLabel = '模型名称';
  static const String _providerLabel = '提供商';
  static const String _providerHelper = '选择API提供商，可以与模型ID自由组合';
  static const String _modelIdLabel = '模型ID';
  static const String _modelIdHelper = '模型的唯一标识符，例如：gpt-4、claude-3-opus';
  static const String _typeLabel = '模型类型';
  static const String _autoDetectLabel = '自动检测';
  static const String _typeHelperAuto = '根据模型ID和提供商自动检测模型类型';

  @override
  ConsumerState<EditModelPage> createState() => _EditModelPageState();
}

class _EditModelPageState extends ConsumerState<EditModelPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _modelIdController = TextEditingController();
  bool _initialized = false;
  String? _parameterScope;

  @override
  void dispose() {
    _nameController.dispose();
    _modelIdController.dispose();
    super.dispose();
  }

  void _seedFrom(ModelProvider provider) {
    if (_initialized) return;
    _initialized = true;
    final id = widget.modelId;
    if (id == null) return;
    for (final model in provider.models) {
      if (model.id == id) {
        _nameController.text = model.name;
        _modelIdController.text = model.id;
        _parameterScope = model.parameterScope;
        return;
      }
    }
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      _modelIdController.text.trim().isNotEmpty;

  Future<void> _save(ModelProvider provider) async {
    final newId = _modelIdController.text.trim();
    final name = _nameController.text.trim();
    if (newId.isEmpty || name.isEmpty) return;

    final existing = <Model>[
      for (final m in provider.models)
        if (m.id != widget.modelId && m.id != newId) m,
    ];
    Model? preserved;
    if (widget.modelId != null) {
      for (final m in provider.models) {
        if (m.id == widget.modelId) {
          preserved = m;
          break;
        }
      }
    }
    final base =
        preserved ?? Model(id: newId, name: name, provider: provider.name);
    final model = base.copyWith(
      id: newId,
      name: name,
      provider: provider.name,
      providerType: provider.providerType,
      parameterScope: _parameterScope,
    );
    final updated = provider.copyWith(models: [...existing, model]);
    await ref.read(modelStoreProvider.notifier).saveProvider(updated);
    if (!mounted) return;
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final providerAsync = ref.watch(
      appModelProviderProvider(widget.providerId),
    );

    return providerAsync.maybeWhen(
      data: (provider) {
        if (provider == null) {
          return const Scaffold(
            appBar: ModelSettingsAppBar(title: EditModelPage._title),
            body: Center(child: Text('供应商不存在')),
          );
        }
        _seedFrom(provider);
        return _buildForm(context, theme, provider);
      },
      orElse: () => const Scaffold(
        appBar: ModelSettingsAppBar(title: EditModelPage._title),
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    ThemeData theme,
    ModelProvider provider,
  ) {
    return Scaffold(
      appBar: ModelSettingsAppBar(
        title: EditModelPage._title,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: ElevatedButton(
              onPressed: _canSave ? () => _save(provider) : null,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(EditModelPage._saveLabel),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _AvatarCard(theme: theme),
          const SizedBox(height: 14),
          ModelFormField(
            label: EditModelPage._nameLabel,
            controller: _nameController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          _ProviderField(name: provider.name),
          const SizedBox(height: 14),
          _ModelIdField(
            controller: _modelIdController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          _ParameterScopeField(
            value: _parameterScope,
            modelId: _modelIdController.text.trim(),
            onChanged: (v) => setState(() => _parameterScope = v),
          ),
          const SizedBox(height: 14),
          _ModelTypeSection(theme: theme),
        ],
      ),
    );
  }
}

/// Compact avatar row with 36px circle + title inline.
class _AvatarCard extends StatelessWidget {
  const _AvatarCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ModelSettingsCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
            ),
            child: Text(
              'M',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  EditModelPage._avatarTitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  EditModelPage._avatarDesc,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.image, size: 18, color: theme.disabledColor),
        ],
      ),
    );
  }
}

/// Read-only provider field — compact single-line.
class _ProviderField extends StatelessWidget {
  const _ProviderField({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          EditModelPage._providerLabel,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        InputDecorator(
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
          ),
          child: Text(
            name,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          EditModelPage._providerHelper,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Model ID field with copy button — the key identifier field.
class _ModelIdField extends StatelessWidget {
  const _ModelIdField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          EditModelPage._modelIdLabel,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          onChanged: onChanged,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'gpt-4o / claude-3-opus / ...',
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
            suffixIcon: controller.text.trim().isNotEmpty
                ? IconButton(
                    icon: const Icon(LucideIcons.copy, size: 14),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                    tooltip: '复制 ID',
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: controller.text.trim()),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已复制模型 ID'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          EditModelPage._modelIdHelper,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Parameter scope dropdown — compact.
class _ParameterScopeField extends StatelessWidget {
  const _ParameterScopeField({
    required this.value,
    required this.modelId,
    required this.onChanged,
  });

  final String? value;
  final String modelId;
  final ValueChanged<String?> onChanged;

  static const List<(String?, String)> _options = [
    (null, '自动检测'),
    ('openai', 'OpenAI'),
    ('anthropic', 'Anthropic'),
    ('gemini', 'Gemini'),
    ('openaiCompatible', 'OpenAI 兼容'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detected = detectProviderFromModel(modelId);
    final detectedLabel = detected.name == 'openaiCompatible'
        ? 'OpenAI 兼容'
        : detected.name[0].toUpperCase() + detected.name.substring(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '参数能力范围',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        AppSelectField<String?>(
          value: _options.any((o) => o.$1 == value) ? value : null,
          sheetTitle: '参数能力范围',
          borderRadius: 12,
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          options: [
            for (final option in _options)
              AppSelectOption<String?>(value: option.$1, label: option.$2),
          ],
          onChanged: onChanged,
        ),
        const SizedBox(height: 4),
        Text(
          '自动检测：$detectedLabel · 设置后覆盖，优先于供应商级',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Model type section — compact grouped chips with auto-detect header.
class _ModelTypeSection extends StatelessWidget {
  const _ModelTypeSection({required this.theme});

  final ThemeData theme;

  static const List<({String label, List<String> types})> _groups = [
    (label: '基础功能', types: ['聊天']),
    (label: '输入能力', types: ['视觉', '语音']),
    (label: '输出能力', types: ['图像生成', '视频生成', '转录', '翻译']),
    (label: '高级功能', types: ['推理', '函数调用', '网络搜索', '工具使用', '代码生成']),
    (label: '数据处理', types: ['嵌入向量', '重排序']),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              EditModelPage._typeLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.info, size: 14, color: scheme.onSurfaceVariant),
            const Spacer(),
            Text(
              EditModelPage._autoDetectLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            const CustomSwitch(value: true, onChanged: null),
          ],
        ),
        const SizedBox(height: 8),
        for (final group in _groups) ...[
          Text(
            group.label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final type in group.types)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Text(
                    type,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: theme.disabledColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Text(
          EditModelPage._typeHelperAuto,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
