import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

/// The 供应商详情 hub third-level page, a 1:1 reproduction of
/// `src/pages/Settings/ModelProviders/index.tsx`.
///
/// Reads the persisted provider by [providerId] and renders its API config and
/// model list. The 密钥 / 基础URL inputs persist through the model store (保存
/// in the app bar); each model row can be tapped to edit, deleted, or selected
/// as the app-level current chat model. 「配置高级参数」 hops to the advanced page.
class ModelProviderDetailPage extends ConsumerStatefulWidget {
  const ModelProviderDetailPage({super.key, required this.providerId});

  final String providerId;

  static const String _title = '模型供应商';
  static const String _apiConfigTitle = 'API配置';
  static const String _apiKeyLabel = 'API密钥';
  static const String _apiKeyHint = '输入API密钥';
  static const String _baseUrlLabel = '基础URL (可选)';
  static const String _baseUrlHint = '输入基础URL，例如: https://tow.bt6.top';
  static const String _baseUrlHelper = '在URL末尾添加#可强制使用自定义格式，末尾添加/也可保持原格式';
  static const String _advancedLabel = '高级 API 配置';
  static const String _advancedButton = '配置高级参数';
  static const String _modelsTitle = '模型列表';
  static const String _manualAddLabel = '添加';
  static const String _noModels = '尚未添加任何模型';
  static const String _saveLabel = '保存';

  @override
  ConsumerState<ModelProviderDetailPage> createState() =>
      _ModelProviderDetailPageState();
}

class _ModelProviderDetailPageState
    extends ConsumerState<ModelProviderDetailPage> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  bool _obscureKey = true;
  bool _initialized = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  void _seedFrom(ModelProvider provider) {
    if (_initialized) return;
    _apiKeyController.text = provider.apiKey ?? '';
    _baseUrlController.text = provider.baseUrl ?? '';
    _initialized = true;
  }

  Future<void> _saveApiConfig(ModelProvider provider) async {
    final updated = provider.copyWith(
      apiKey: _apiKeyController.text.trim().isEmpty
          ? null
          : _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim().isEmpty
          ? null
          : _baseUrlController.text.trim(),
    );
    await ref.read(modelStoreProvider.notifier).saveProvider(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已保存')));
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
            appBar: ModelSettingsAppBar(title: ModelProviderDetailPage._title),
            body: Center(child: Text('供应商不存在')),
          );
        }
        _seedFrom(provider);
        return _buildContent(context, theme, provider);
      },
      orElse: () => const Scaffold(
        appBar: ModelSettingsAppBar(title: ModelProviderDetailPage._title),
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    ModelProvider provider,
  ) {
    final currentAsync = ref.watch(appCurrentModelProvider);
    final currentModelId = currentAsync.maybeWhen(
      data: (current) => current != null && current.provider.id == provider.id
          ? current.model.id
          : null,
      orElse: () => null,
    );

    return Scaffold(
      appBar: ModelSettingsAppBar(
        title: ModelProviderDetailPage._title,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: ElevatedButton(
              onPressed: () => _saveApiConfig(provider),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(ModelProviderDetailPage._saveLabel),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ModelSettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const ModelSectionTitle(
                  ModelProviderDetailPage._apiConfigTitle,
                ),
                const SizedBox(height: 24),
                ModelFormField(
                  label: ModelProviderDetailPage._apiKeyLabel,
                  hint: ModelProviderDetailPage._apiKeyHint,
                  controller: _apiKeyController,
                  obscureText: _obscureKey,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureKey ? LucideIcons.eyeOff : LucideIcons.eye,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  ),
                ),
                const SizedBox(height: 24),
                ModelFormField(
                  label: ModelProviderDetailPage._baseUrlLabel,
                  hint: ModelProviderDetailPage._baseUrlHint,
                  helper: ModelProviderDetailPage._baseUrlHelper,
                  controller: _baseUrlController,
                ),
                const SizedBox(height: 24),
                Text(
                  ModelProviderDetailPage._advancedLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push(AppRouter.advancedApiPath(provider.id)),
                  icon: const Icon(LucideIcons.settings, size: 16),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.secondary,
                    side: BorderSide(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  label: const Text(ModelProviderDetailPage._advancedButton),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ModelSettingsCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: ModelSectionTitle(
                        ModelProviderDetailPage._modelsTitle,
                      ),
                    ),
                    ModelTonalButton(
                      label: ModelProviderDetailPage._manualAddLabel,
                      icon: LucideIcons.plus,
                      onPressed: () =>
                          context.push(AppRouter.editModelPath(provider.id)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (provider.models.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        ModelProviderDetailPage._noModels,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  for (final model in provider.models)
                    _ModelRow(
                      model: model,
                      isCurrent: model.id == currentModelId,
                      onTap: () => context.push(
                        AppRouter.editModelPath(provider.id, modelId: model.id),
                      ),
                      onSelect: () => ref
                          .read(modelStoreProvider.notifier)
                          .selectCurrentModel(
                            providerId: provider.id,
                            modelId: model.id,
                          ),
                      onDelete: () => _deleteModel(provider, model.id),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteModel(ModelProvider provider, String modelId) async {
    final updated = provider.copyWith(
      models: [
        for (final m in provider.models)
          if (m.id != modelId) m,
      ],
    );
    await ref.read(modelStoreProvider.notifier).saveProvider(updated);
  }
}

/// A single model row in the provider's model list: the model name, a
/// current-selection radio (taps set it as the app's current chat model), an
/// edit affordance (tapping the row) and a trailing delete.
class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.model,
    required this.isCurrent,
    required this.onTap,
    required this.onSelect,
    required this.onDelete,
  });

  final Model model;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                isCurrent ? LucideIcons.circleCheck : LucideIcons.circle,
                size: 20,
                color: isCurrent
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              tooltip: '设为当前模型',
              onPressed: onSelect,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    model.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    model.id,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.trash2, size: 18),
              color: theme.colorScheme.error,
              tooltip: '删除',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
