import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
        padding: const EdgeInsets.all(16),
        children: [
          _AvatarCard(theme: theme),
          const SizedBox(height: 24),
          ModelFormField(
            label: EditModelPage._nameLabel,
            controller: _nameController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          _ProviderField(name: provider.name),
          const SizedBox(height: 24),
          ModelFormField(
            label: EditModelPage._modelIdLabel,
            helper: EditModelPage._modelIdHelper,
            controller: _modelIdController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          _ParameterScopeField(
            value: _parameterScope,
            modelId: _modelIdController.text.trim(),
            onChanged: (v) => setState(() => _parameterScope = v),
          ),
          const SizedBox(height: 24),
          _ModelTypeSection(theme: theme),
        ],
      ),
    );
  }
}

/// The avatar card: a circular fallback initial, the 模型头像 title/description
/// and a primary photo button (disabled — avatar upload needs the data layer).
class _AvatarCard extends StatelessWidget {
  const _AvatarCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ModelSettingsCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
            ),
            child: Text(
              'M',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  EditModelPage._avatarTitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  EditModelPage._avatarDesc,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const IconButton(
            icon: Icon(LucideIcons.image, size: 20),
            onPressed: null,
          ),
        ],
      ),
    );
  }
}

/// The 提供商 field — fixed to the provider this model belongs to (the model is
/// edited from within a provider), shown read-only with the original helper.
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
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        InputDecorator(
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            name,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          EditModelPage._providerHelper,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Dropdown for selecting the parameter display scope at the model level.
/// Shows the current auto-detected scope as a hint so users can see what
/// the system would pick without their override.
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
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String?>(
          initialValue: _options.any((o) => o.$1 == value) ? value : null,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          items: [
            for (final option in _options)
              DropdownMenuItem<String?>(
                value: option.$1,
                child: Text(option.$2),
              ),
          ],
          onChanged: onChanged,
        ),
        const SizedBox(height: 6),
        Text(
          '当前自动检测结果：$detectedLabel。设置后覆盖自动检测，'
          '优先级高于供应商级设置。',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The 模型类型 section: a header (label + info hint + 自动检测 switch) and the
/// grouped capability chips. The original defaults `autoDetect` on, which
/// disables the chips — matching this milestone's pure-view state.
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
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.info, size: 16, color: scheme.onSurfaceVariant),
            const Spacer(),
            Text(
              EditModelPage._autoDetectLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            // autoDetect defaults on; persisting it needs the data layer, so
            // the switch is disabled this milestone.
            const CustomSwitch(value: true, onChanged: null),
            const IconButton(
              icon: Icon(LucideIcons.settings, size: 16),
              onPressed: null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final group in _groups) ...[
          Text(
            group.label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in group.types)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Text(
                    type,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: theme.disabledColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        Text(
          EditModelPage._typeHelperAuto,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
