import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

/// The "添加提供商" third-level page (二级页 添加供应商 → this page), a 1:1
/// reproduction of `src/pages/Settings/ModelProviders/AddProvider.tsx`.
///
/// Pure view, zero data: typing the name and picking a type drive a live
/// preview (local UI state only — nothing is persisted). The footer 「下一步」
/// stays disabled (it would create a provider in the store, which is out of
/// scope this milestone); 「取消」 simply navigates back.
class AddProviderPage extends StatefulWidget {
  const AddProviderPage({super.key});

  static const String _title = '添加提供商';
  static const String _previewFallbackName = '新提供商';
  static const String _sectionInfo = '提供商信息';
  static const String _nameLabel = '提供商名称';
  static const String _nameHint = '例如 OpenAI';
  static const String _typeLabel = '提供商类型';
  static const String _cancelLabel = '取消';
  static const String _nextLabel = '下一步';

  @override
  State<AddProviderPage> createState() => _AddProviderPageState();
}

class _AddProviderPageState extends State<AddProviderPage> {
  final TextEditingController _nameController = TextEditingController();
  String _name = '';
  _ProviderType? _selectedType;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _avatarLetter => _selectedType == null
      ? 'P'
      : _selectedType!.label.characters.first.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const ModelSettingsAppBar(title: AddProviderPage._title),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ModelSettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary,
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1A000000), // rgba(0,0,0,0.1)
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            _avatarLetter,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontSize: 27, // 1.7rem
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _name.isEmpty
                                ? AddProviderPage._previewFallbackName
                                : _name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontSize: 24, // h5
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const ModelSectionTitle(AddProviderPage._sectionInfo),
                    const SizedBox(height: 24),
                    ModelFormField(
                      label: AddProviderPage._nameLabel,
                      hint: AddProviderPage._nameHint,
                      controller: _nameController,
                      onChanged: (value) => setState(() => _name = value),
                    ),
                    const SizedBox(height: 24),
                    _ProviderTypeField(
                      label: AddProviderPage._typeLabel,
                      value: _selectedType,
                      onChanged: (type) => setState(() => _selectedType = type),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go(AppRouter.defaultModelPath),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: const Text(AddProviderPage._cancelLabel),
                        ),
                        const SizedBox(width: 16),
                        // 下一步 creates a provider in the store — disabled this
                        // milestone (no data layer).
                        const ModelTonalButton(
                          label: AddProviderPage._nextLabel,
                          onPressed: null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled provider-type dropdown that reveals the selected type's
/// description, mirroring the original `Select` + helper text.
class _ProviderTypeField extends StatelessWidget {
  const _ProviderTypeField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final _ProviderType? value;
  final ValueChanged<_ProviderType?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<_ProviderType>(
          initialValue: value,
          isDense: true,
          isExpanded: true,
          hint: Text(
            '请选择$label',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
          ),
          items: [
            for (final type in _providerTypes)
              DropdownMenuItem<_ProviderType>(
                value: type,
                child: Text(
                  type.label,
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
                ),
              ),
          ],
          onChanged: onChanged,
        ),
        if (value != null) ...[
          const SizedBox(height: 8),
          Text(
            value!.description,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13, // 0.8rem
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// A selectable provider type, lifted verbatim from the original
/// `providerTypeOptions` (custom / google filtered out) and the inline
/// description map in `AddProvider.tsx`.
class _ProviderType {
  const _ProviderType(this.value, this.label, this.description);

  final String value;
  final String label;
  final String description;
}

const List<_ProviderType> _providerTypes = [
  _ProviderType('openai', 'OpenAI', '添加OpenAI兼容的API服务'),
  _ProviderType(
    'openai-aisdk',
    'OpenAI (AI SDK) - 流式优化',
    '添加OpenAI API服务（使用AI SDK，专为浏览器优化，解决流式响应延迟问题）',
  ),
  _ProviderType(
    'azure-openai',
    'Azure OpenAI',
    '添加Azure OpenAI API服务（需要配置endpoint和apiVersion）',
  ),
  _ProviderType('gemini', 'Gemini', '添加Google Gemini API服务'),
  _ProviderType('anthropic', 'Anthropic', '添加Anthropic Claude API服务'),
  _ProviderType('grok', 'xAI (Grok)', '添加xAI (Grok) API服务'),
  _ProviderType('deepseek', 'DeepSeek', '添加DeepSeek API服务（使用OpenAI兼容格式）'),
  _ProviderType('zhipu', '智谱AI', '添加智谱AI (GLM) API服务（使用OpenAI兼容格式）'),
  _ProviderType(
    'siliconflow',
    '硅基流动 (SiliconFlow)',
    '添加硅基流动 (SiliconFlow) API服务',
  ),
  _ProviderType('volcengine', '火山引擎', '添加火山引擎 (豆包/DeepSeek) API服务'),
  _ProviderType('minimax', 'MiniMax', '添加自定义API服务'),
  _ProviderType('dashscope', '阿里云百炼 (DashScope)', '添加自定义API服务'),
];
