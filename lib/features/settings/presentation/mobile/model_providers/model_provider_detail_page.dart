import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_model_catalog.dart';
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
  static const String _fetchLabel = '获取';
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
  bool _fetching = false;

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
                      label: ModelProviderDetailPage._fetchLabel,
                      icon: LucideIcons.download,
                      onPressed: _fetching
                          ? null
                          : () => _fetchModels(provider),
                    ),
                    const SizedBox(width: 8),
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

  /// Fetches the provider's catalog (`自动获取模型`) using the API key / base URL
  /// currently in the form (so it works before 保存), lets the user pick which
  /// models to add, then persists them onto the provider.
  Future<void> _fetchModels(ModelProvider provider) async {
    if (_fetching) return;
    setState(() => _fetching = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final catalog = ref.read(appModelCatalogProvider);
      final fetched = await catalog.listModels(
        LlmModelQuery(
          providerType: provider.providerType ?? provider.name,
          apiKey: _apiKeyController.text.trim().isEmpty
              ? null
              : _apiKeyController.text.trim(),
          baseUrl: _baseUrlController.text.trim().isEmpty
              ? null
              : _baseUrlController.text.trim(),
          extraHeaders: provider.extraHeaders,
        ),
      );
      if (!mounted) return;
      if (fetched.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('未获取到模型')));
        return;
      }
      final existingIds = {for (final m in provider.models) m.id};
      final selected = await showModalBottomSheet<List<LlmModelInfo>>(
        context: context,
        isScrollControlled: true,
        builder: (_) =>
            _FetchedModelsSheet(models: fetched, existingIds: existingIds),
      );
      if (selected == null || selected.isEmpty || !mounted) return;
      await ref
          .read(modelStoreProvider.notifier)
          .addModels(
            providerId: provider.id,
            models: [
              for (final info in selected)
                Model(
                  id: info.id,
                  name: info.name ?? info.id,
                  provider: provider.name,
                  providerType: provider.providerType,
                  description: info.description,
                  enabled: true,
                ),
            ],
          );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('已添加 ${selected.length} 个模型')),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('获取模型失败，请检查密钥与基础URL')),
      );
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
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

/// A bottom sheet listing the models fetched from a provider's catalog. Models
/// already on the provider are shown disabled (already added); the rest are
/// pre-checked. 「添加」 pops the selected [LlmModelInfo]s; cancel pops null.
class _FetchedModelsSheet extends StatefulWidget {
  const _FetchedModelsSheet({required this.models, required this.existingIds});

  final List<LlmModelInfo> models;
  final Set<String> existingIds;

  @override
  State<_FetchedModelsSheet> createState() => _FetchedModelsSheetState();
}

class _FetchedModelsSheetState extends State<_FetchedModelsSheet> {
  late final Set<String> _selected = {
    for (final m in widget.models)
      if (!widget.existingIds.contains(m.id)) m.id,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '获取到 ${widget.models.length} 个模型',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.models.length,
              itemBuilder: (context, index) {
                final model = widget.models[index];
                final already = widget.existingIds.contains(model.id);
                return CheckboxListTile(
                  value: already || _selected.contains(model.id),
                  onChanged: already
                      ? null
                      : (checked) => setState(() {
                          if (checked ?? false) {
                            _selected.add(model.id);
                          } else {
                            _selected.remove(model.id);
                          }
                        }),
                  title: Text(model.name ?? model.id),
                  subtitle: Text(already ? '${model.id} · 已添加' : model.id),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.of(context).pop([
                        for (final m in widget.models)
                          if (_selected.contains(m.id)) m,
                      ]),
                child: Text('添加 (${_selected.length})'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
