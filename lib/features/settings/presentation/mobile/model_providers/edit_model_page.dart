import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/shared/widgets/app_select_field.dart';
import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_checks.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_enricher.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_registry.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:aetherlink_flutter/shared/domain/model_type.dart';
import 'package:aetherlink_flutter/shared/domain/parameter_metadata.dart';

/// The "编辑模型" third-level page, a 1:1 reproduction of
/// `src/pages/Settings/ModelProviders/EditModelPage.tsx` (whose form body is the
/// `EditModelForm.solid` component).
///
/// Reads the provider by [providerId]; when [modelId] is given the form is
/// seeded from that model (edit), otherwise it starts blank (add). 保存 upserts
/// the model into the provider's `models` and persists through the model store.
/// The model-type chips show auto-detected capabilities (preset registry →
/// regex inference); turning off 自动检测 lets the user override them, which is
/// persisted as `modelTypes`.
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
  static const String _typeHelperManual = '手动选择模型支持的能力（覆盖自动检测）';

  @override
  ConsumerState<EditModelPage> createState() => _EditModelPageState();
}

class _EditModelPageState extends ConsumerState<EditModelPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _modelIdController = TextEditingController();
  bool _initialized = false;
  String? _parameterScope;

  /// When true the model types follow [_detectedTypes] (registry/inference);
  /// when false the user controls [_selectedTypes] manually.
  bool _autoDetect = true;
  Set<ModelType> _detectedTypes = {};
  Set<ModelType> _selectedTypes = {};

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
    if (id != null) {
      for (final model in provider.models) {
        if (model.id == id) {
          _nameController.text = model.name;
          _modelIdController.text = model.id;
          _parameterScope = model.parameterScope;
          final types = model.modelTypes;
          if (types != null && types.isNotEmpty) {
            _autoDetect = false;
            _selectedTypes = types.toSet();
          }
          break;
        }
      }
    }
    _recomputeDetected();
  }

  /// Re-detects capabilities for the current model id (preset registry → regex
  /// inference) and refreshes the advisory chips.
  Future<void> _recomputeDetected() async {
    final id = _modelIdController.text.trim();
    if (id.isEmpty) {
      if (mounted) setState(() => _detectedTypes = {});
      return;
    }
    await ModelRegistry.instance.ensureLoaded();
    final caps = detectCapabilities(id);
    if (!mounted) return;
    setState(() => _detectedTypes = capabilitiesToModelTypes(caps));
  }

  void _onModelIdChanged() {
    setState(() {});
    _recomputeDetected();
  }

  void _toggleType(ModelType type) {
    setState(() {
      if (_selectedTypes.contains(type)) {
        _selectedTypes.remove(type);
      } else {
        _selectedTypes.add(type);
      }
    });
  }

  void _toggleAutoDetect(bool value) {
    setState(() {
      _autoDetect = value;
      // Switching to manual seeds the selection from the current detection so
      // the user edits from a sensible starting point.
      if (!value && _selectedTypes.isEmpty) {
        _selectedTypes = {..._detectedTypes};
      }
    });
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
    // Auto-detect → clear types/capabilities so enrichment re-detects from the
    // (possibly changed) id. Manual → persist the user's chosen types as the
    // override layer (runtime checks read modelTypes first).
    final manualTypes = _autoDetect ? null : _selectedTypes.toList();
    final model = base.copyWith(
      id: newId,
      name: name,
      provider: provider.name,
      providerType: provider.providerType,
      parameterScope: _parameterScope,
      modelTypes: manualTypes,
      capabilities: null,
    );
    // Fill capabilities once (preset registry → regex inference). Models that
    // carry an explicit type selection are preserved as-is by the enricher.
    final enriched = await enrichModel(model);
    final updated = provider.copyWith(models: [...existing, enriched]);
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
            onChanged: (_) => _onModelIdChanged(),
          ),
          const SizedBox(height: 14),
          _ParameterScopeField(
            value: _parameterScope,
            modelId: _modelIdController.text.trim(),
            onChanged: (v) => setState(() => _parameterScope = v),
          ),
          const SizedBox(height: 14),
          _ModelTypeSection(
            theme: theme,
            autoDetect: _autoDetect,
            detectedTypes: _detectedTypes,
            selectedTypes: _selectedTypes,
            onToggleAuto: _toggleAutoDetect,
            onToggleType: _toggleType,
          ),
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

/// Display labels for each [ModelType] chip.
const Map<ModelType, String> _modelTypeLabels = {
  ModelType.chat: '聊天',
  ModelType.vision: '视觉',
  ModelType.audio: '语音',
  ModelType.imageGen: '图像生成',
  ModelType.videoGen: '视频生成',
  ModelType.transcription: '转录',
  ModelType.translation: '翻译',
  ModelType.reasoning: '推理',
  ModelType.functionCalling: '函数调用',
  ModelType.webSearch: '网络搜索',
  ModelType.tool: '工具使用',
  ModelType.codeGen: '代码生成',
  ModelType.embedding: '嵌入向量',
  ModelType.rerank: '重排序',
};

/// Grouped chip layout (label → ordered types).
const List<({String label, List<ModelType> types})> _modelTypeGroups = [
  (label: '基础功能', types: [ModelType.chat]),
  (label: '输入能力', types: [ModelType.vision, ModelType.audio]),
  (
    label: '输出能力',
    types: [ModelType.imageGen, ModelType.videoGen, ModelType.transcription, ModelType.translation],
  ),
  (
    label: '高级功能',
    types: [
      ModelType.reasoning,
      ModelType.functionCalling,
      ModelType.webSearch,
      ModelType.tool,
      ModelType.codeGen,
    ],
  ),
  (label: '数据处理', types: [ModelType.embedding, ModelType.rerank]),
];

/// Model type section — grouped chips with a working auto-detect toggle.
///
/// In auto mode the active chips mirror [detectedTypes] (registry/inference,
/// read-only). Turning auto off lets the user toggle [selectedTypes] manually,
/// which become the persisted override.
class _ModelTypeSection extends StatelessWidget {
  const _ModelTypeSection({
    required this.theme,
    required this.autoDetect,
    required this.detectedTypes,
    required this.selectedTypes,
    required this.onToggleAuto,
    required this.onToggleType,
  });

  final ThemeData theme;
  final bool autoDetect;
  final Set<ModelType> detectedTypes;
  final Set<ModelType> selectedTypes;
  final ValueChanged<bool> onToggleAuto;
  final ValueChanged<ModelType> onToggleType;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final active = autoDetect ? detectedTypes : selectedTypes;

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
            CustomSwitch(value: autoDetect, onChanged: onToggleAuto),
          ],
        ),
        const SizedBox(height: 8),
        for (final group in _modelTypeGroups) ...[
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
                _TypeChip(
                  theme: theme,
                  label: _modelTypeLabels[type] ?? type.name,
                  selected: active.contains(type),
                  enabled: !autoDetect,
                  onTap: autoDetect ? null : () => onToggleType(type),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Text(
          autoDetect ? EditModelPage._typeHelperAuto : EditModelPage._typeHelperManual,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// A single capability chip. Highlighted when [selected]; tappable only when
/// [enabled] (manual mode).
class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.theme,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final ThemeData theme;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final Color bg;
    final Color fg;
    final Color border;
    if (selected) {
      bg = scheme.primary.withValues(alpha: enabled ? 0.14 : 0.10);
      fg = scheme.primary;
      border = scheme.primary.withValues(alpha: 0.5);
    } else {
      bg = scheme.onSurface.withValues(alpha: 0.05);
      fg = enabled ? scheme.onSurfaceVariant : theme.disabledColor;
      border = theme.dividerColor;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 12, color: fg),
        ),
      ),
    );
  }
}
