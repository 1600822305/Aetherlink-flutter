import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_model_catalog.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/fetched_models_sheet.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/provider_config_utils.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:aetherlink_flutter/shared/utils/provider_icons.dart';

/// The 供应商详情 third-level page — a style-aligned (not pixel-1:1) port of
/// `src/pages/Settings/ModelProviders/index.tsx`, reusing the PR #44 design
/// system. The long original scroll is split into a top **Tab (配置 / 模型)**:
///
///  * AppBar: dynamic provider name + 启用 switch + 保存.
///  * Tab 配置: header block (avatar + name + `{type} API` + edit/delete),
///    single/multi-key mode, key input, multi-key entry point, base-URL
///    completion preview, Responses-API toggle (wired into the request layer)
///    and the advanced-API entry point.
///  * Tab 模型: 测试模式 toggle + 长期显示测试按钮, search, the 自动获取 / 自定义端点 /
///    手动添加 tool row and the grouped model list (edit / delete / test per
///    row, 2-step group delete).
///
/// CORS-plugin features are intentionally dropped (no CORS concern on Flutter).
class ModelProviderDetailPage extends ConsumerStatefulWidget {
  const ModelProviderDetailPage({super.key, required this.providerId});

  final String providerId;

  @override
  ConsumerState<ModelProviderDetailPage> createState() =>
      _ModelProviderDetailPageState();
}

class _ModelProviderDetailPageState
    extends ConsumerState<ModelProviderDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool _obscureKey = true;
  bool _initialized = false;
  bool _fetching = false;
  bool _isEnabled = false;
  bool _useResponsesAPI = false;
  bool _useMultiKey = false;
  bool _testMode = false;
  bool _alwaysShowTestButton = false;
  bool _kvLoaded = false;
  String _search = '';
  String? _testingModelId;
  String? _groupPendingDelete;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _seedFrom(ModelProvider provider) {
    if (_initialized) return;
    _apiKeyController.text = provider.apiKey ?? '';
    _baseUrlController.text = provider.baseUrl ?? '';
    _isEnabled = provider.isEnabled;
    _useResponsesAPI = provider.useResponsesAPI ?? false;
    _useMultiKey = provider.apiKeys?.isNotEmpty ?? false;
    _initialized = true;
    _loadKvSettings(provider.id);
  }

  Future<void> _loadKvSettings(String providerId) async {
    if (_kvLoaded) return;
    _kvLoaded = true;
    final store = ref.read(appSettingsStoreProvider);
    final results = await Future.wait([
      store.getSetting('alwaysShowTestButton_$providerId'),
      store.getSetting('useMultiKey_$providerId'),
    ]);
    if (!mounted) return;
    setState(() {
      _alwaysShowTestButton = results[0] == 'true';
      // KV store takes precedence over data-derived value
      if (results[1] != null) {
        _useMultiKey = results[1] == 'true';
      }
    });
  }

  Future<void> _save(ModelProvider provider) async {
    final updated = provider.copyWith(
      apiKey: _apiKeyController.text.trim().isEmpty
          ? null
          : _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim().isEmpty
          ? null
          : _baseUrlController.text.trim(),
      isEnabled: _isEnabled,
      useResponsesAPI: _useResponsesAPI,
    );
    await ref.read(modelStoreProvider.notifier).saveProvider(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已保存')));
  }

  /// Auto-save a single toggle field immediately.
  Future<void> _autoSaveToggle(
    ModelProvider provider, {
    bool? isEnabled,
    bool? useResponsesAPI,
  }) async {
    final updated = provider.copyWith(
      isEnabled: isEnabled ?? _isEnabled,
      useResponsesAPI: useResponsesAPI ?? _useResponsesAPI,
    );
    await ref.read(modelStoreProvider.notifier).saveProvider(updated);
  }

  @override
  Widget build(BuildContext context) {
    final providerAsync = ref.watch(
      appModelProviderProvider(widget.providerId),
    );

    return providerAsync.maybeWhen(
      data: (provider) {
        if (provider == null) {
          return const Scaffold(
            appBar: ModelSettingsAppBar(title: '模型供应商'),
            body: Center(child: Text('供应商不存在')),
          );
        }
        _seedFrom(provider);
        return _buildContent(context, provider);
      },
      orElse: () => const Scaffold(
        appBar: ModelSettingsAppBar(title: '模型供应商'),
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ModelProvider provider) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: ModelSettingsAppBar(
        title: provider.name.isEmpty ? '模型供应商' : provider.name,
        actions: [
          Center(
            child: Row(
              children: [
                CustomSwitch(
                  value: _isEnabled,
                  onChanged: (v) {
                    setState(() => _isEnabled = v);
                    _autoSaveToggle(provider, isEnabled: v);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ModelTonalButton(
                    label: '保存',
                    onPressed: () => _save(provider),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              indicatorColor: theme.colorScheme.primary,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: '配置'),
                Tab(text: '模型'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildConfigTab(context, provider),
                _buildModelsTab(context, provider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1 · 配置
  // ---------------------------------------------------------------------------

  Widget _buildConfigTab(BuildContext context, ModelProvider provider) {
    final theme = Theme.of(context);
    final isOpenAI = isOpenAIProvider(provider.providerType);
    final keyCount = provider.apiKeys?.length ?? 0;
    final canEdit = provider.isSystem != true;
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurface,
    );
    final hintStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 12,
      color: theme.colorScheme.onSurfaceVariant,
    );

    // 整个配置 Tab 收进单张卡片，内部用分隔线/小标题分段，避免卡片套卡片、
    // 减少留白；API 密钥不再「区标题 + 字段标签」重复显示。
    return ListView(
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        ModelSettingsCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _ProviderHeader(
                provider: provider,
                typeLabel: _typeLabel(provider.providerType),
                onEdit: canEdit ? () => _editProvider(provider) : null,
                onDelete: canEdit ? () => _confirmDelete(provider) : null,
              ),
              const Divider(height: 24),

              // API Key 管理模式（单 / 多 Key 切换）
              Row(
                children: [
                  Text('API Key 管理模式', style: labelStyle),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: _useMultiKey
                        ? '多个 API Key 按策略自动负载均衡与故障转移'
                        : '使用单个 API Key（传统方式）',
                    child: Icon(
                      LucideIcons.info,
                      size: 15,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(_useMultiKey ? '多 Key' : '单 Key', style: hintStyle),
                  const SizedBox(width: 8),
                  CustomSwitch(
                    value: _useMultiKey,
                    onChanged: (v) {
                      setState(() => _useMultiKey = v);
                      ref
                          .read(appSettingsStoreProvider)
                          .saveSetting(
                            'useMultiKey_${provider.id}',
                            v.toString(),
                          );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_useMultiKey) ...[
                SizedBox(
                  width: double.infinity,
                  child: ModelTonalButton(
                    label: '管理多 Key（$keyCount 个密钥）',
                    icon: LucideIcons.keyRound,
                    onPressed: () =>
                        context.push(AppRouter.multiKeyPath(provider.id)),
                  ),
                ),
                const SizedBox(height: 6),
                Text('按策略（轮询/优先级/最少使用/随机）自动选 Key，失败自动切换并冷却。', style: hintStyle),
              ] else
                ModelFormField(
                  label: 'API 密钥',
                  hint: '输入 API 密钥',
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

              const SizedBox(height: 16),
              // 基础 URL
              ModelFormField(
                label: '基础 URL (可选)',
                hint: '输入基础URL，例如: https://api.openai.com',
                helper: '在URL末尾添加#可强制使用自定义格式，末尾添加/也可保持原格式',
                controller: _baseUrlController,
                onChanged: (_) => setState(() {}),
              ),
              if (isOpenAI && _baseUrlController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                _UrlPreview(
                  url: getCompleteApiUrl(
                    _baseUrlController.text,
                    provider.providerType,
                    useResponsesAPI: _useResponsesAPI,
                  ),
                ),
              ],

              // Responses API（仅 OpenAI 类）
              if (isOpenAI) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Responses API', style: labelStyle),
                    const Spacer(),
                    CustomSwitch(
                      value: _useResponsesAPI,
                      onChanged: (v) {
                        setState(() => _useResponsesAPI = v);
                        _autoSaveToggle(provider, useResponsesAPI: v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '使用 /responses 端点替代 /chat/completions（仅官方 OpenAI 建议开启）。',
                  style: hintStyle,
                ),
              ],

              const Divider(height: 24),
              // 参数能力范围
              _ParameterScopeRow(
                value: provider.parameterScope,
                labelStyle: labelStyle!,
                hintStyle: hintStyle!,
                onChanged: (v) async {
                  final updated = provider.copyWith(parameterScope: v);
                  await ref
                      .read(modelStoreProvider.notifier)
                      .saveProvider(updated);
                },
              ),

              const Divider(height: 24),
              // 高级 API 配置入口
              _NavRow(
                icon: LucideIcons.settings,
                title: '高级 API 配置',
                subtitle: '额外请求头与请求体（聊天与模型获取均生效）',
                onTap: () =>
                    context.push(AppRouter.advancedApiPath(provider.id)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2 · 模型
  // ---------------------------------------------------------------------------

  Widget _buildModelsTab(BuildContext context, ModelProvider provider) {
    final theme = Theme.of(context);
    final currentAsync = ref.watch(appCurrentModelProvider);
    final currentModelId = currentAsync.maybeWhen(
      data: (current) => current != null && current.provider.id == provider.id
          ? current.model.id
          : null,
      orElse: () => null,
    );

    final query = _search.trim().toLowerCase();
    final filtered = query.isEmpty
        ? provider.models
        : [
            for (final m in provider.models)
              if (m.name.toLowerCase().contains(query) ||
                  m.id.toLowerCase().contains(query))
                m,
          ];
    final groups = groupModels<Model>(
      filtered,
      idOf: (m) => m.id,
      groupOf: (m) => m.group,
      providerId: provider.id,
    );
    final showTest = _testMode || _alwaysShowTestButton;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        // ─── Toolbar row: 自动获取 / 自定义端点 / 手动添加 ────────────
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _CompactActionChip(
                    label: '获取',
                    icon: LucideIcons.download,
                    onPressed:
                        _fetching ? null : () => _fetchModels(provider),
                  ),
                  _CompactActionChip(
                    label: '端点',
                    icon: LucideIcons.link,
                    accent: theme.colorScheme.secondary,
                    onPressed:
                        _fetching ? null : () => _customEndpoint(provider),
                  ),
                  _CompactActionChip(
                    label: '添加',
                    icon: LucideIcons.plus,
                    onPressed: () =>
                        context.push(AppRouter.editModelPath(provider.id)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Test mode: compact icon toggle
            _TestModeToggle(
              active: _testMode,
              alwaysShow: _alwaysShowTestButton,
              onToggleTestMode: () =>
                  setState(() => _testMode = !_testMode),
              onToggleAlwaysShow: (v) {
                setState(() => _alwaysShowTestButton = v);
                ref
                    .read(appSettingsStoreProvider)
                    .saveSetting(
                      'alwaysShowTestButton_${provider.id}',
                      v.toString(),
                    );
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        // ─── Search bar ─────────────────────────────────────────────
        SizedBox(
          height: 40,
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _search = v),
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: '搜索模型 (${provider.models.length})',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              prefixIcon: const Icon(LucideIcons.search, size: 16),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 36, minHeight: 0),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                      },
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 分组模型列表
        if (provider.models.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                '尚未添加任何模型',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                '没有匹配「$_search」的模型',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          for (final (groupName, models) in groups) ...[
            ModelSettingsCard(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$groupName (${models.length})',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _deleteGroup(provider, models),
                        icon: Icon(
                          _groupPendingDelete == groupName
                              ? LucideIcons.check
                              : LucideIcons.trash2,
                          size: 14,
                        ),
                        color: theme.colorScheme.error,
                        tooltip: _groupPendingDelete == groupName
                            ? '确认删除整组'
                            : '删除整组',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                      ),
                    ],
                  ),
                  const Divider(height: 4),
                  for (final model in models)
                    _ModelRow(
                      model: model,
                      isCurrent: model.id == currentModelId,
                      showTest: showTest,
                      testing: _testingModelId == model.id,
                      testDisabled: _testingModelId != null,
                      onTap: () => context.push(
                        AppRouter.editModelPath(provider.id, modelId: model.id),
                      ),
                      onSelect: () => ref
                          .read(modelStoreProvider.notifier)
                          .selectCurrentModel(
                            providerId: provider.id,
                            modelId: model.id,
                          ),
                      onTest: () => _testModel(provider, model),
                      onDelete: () => _deleteModel(provider, model.id),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  String _typeLabel(String? type) {
    for (final option in providerTypeOptions) {
      if (option.$1 == type) return option.$2;
    }
    return (type == null || type.isEmpty) ? '自定义' : type;
  }

  Future<void> _editProvider(ModelProvider provider) async {
    final result = await showDialog<(String, String?)>(
      context: context,
      builder: (_) => _EditProviderDialog(provider: provider),
    );
    if (result == null) return;
    final (name, type) = result;
    await ref
        .read(modelStoreProvider.notifier)
        .saveProvider(provider.copyWith(name: name, providerType: type));
  }

  Future<void> _confirmDelete(ModelProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '删除供应商',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(ctx).colorScheme.error,
          ),
        ),
        content: Text('确定要删除「${provider.name}」吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(modelStoreProvider.notifier).deleteProvider(provider.id);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRouter.defaultModelPath);
    }
  }

  /// Fetches the provider's catalog (`自动获取模型`) using the form's current key /
  /// base URL (so it works before 保存), lets the user pick models, then
  /// persists them. [endpointOverride] supplies the 自定义端点 base URL.
  Future<void> _fetchModels(
    ModelProvider provider, {
    String? endpointOverride,
  }) async {
    if (_fetching) return;
    setState(() => _fetching = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final baseUrl = endpointOverride?.trim().isNotEmpty == true
          ? endpointOverride!.trim()
          : (_baseUrlController.text.trim().isEmpty
                ? null
                : _baseUrlController.text.trim());
      final catalog = ref.read(appModelCatalogProvider);
      final fetched = await catalog.listModels(
        LlmModelQuery(
          providerType: provider.providerType ?? provider.name,
          apiKey: _apiKeyController.text.trim().isEmpty
              ? null
              : _apiKeyController.text.trim(),
          baseUrl: baseUrl,
          extraHeaders: provider.extraHeaders,
        ),
      );
      if (!mounted) return;
      if (fetched.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('未获取到模型')));
        return;
      }
      final existingIds = {for (final m in provider.models) m.id};
      final result = await showModalBottomSheet<FetchedModelsResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => FetchedModelsSheet(
          models: fetched,
          existingIds: existingIds,
          providerId: provider.id,
        ),
      );
      if (result == null || !mounted) return;
      final notifier = ref.read(modelStoreProvider.notifier);
      // Add newly selected models
      if (result.toAdd.isNotEmpty) {
        await notifier.addModels(
          providerId: provider.id,
          models: [
            for (final info in result.toAdd)
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
      }
      // Remove toggled-off existing models
      if (result.toRemove.isNotEmpty) {
        final removeIds = result.toRemove.toSet();
        final current = await ref.read(appModelRepositoryProvider).getProvider(provider.id);
        if (current != null) {
          await notifier.saveProvider(
            current.copyWith(
              models: [
                for (final m in current.models)
                  if (!removeIds.contains(m.id)) m,
              ],
            ),
          );
        }
      }
      if (!mounted) return;
      final msgs = <String>[];
      if (result.toAdd.isNotEmpty) msgs.add('添加 ${result.toAdd.length}');
      if (result.toRemove.isNotEmpty) msgs.add('移除 ${result.toRemove.length}');
      if (msgs.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text('已${msgs.join("、")} 个模型')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('获取模型失败，请检查密钥与基础URL')),
      );
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Future<void> _customEndpoint(ModelProvider provider) async {
    final endpoint = await showDialog<String>(
      context: context,
      builder: (ctx) =>
          _CustomEndpointDialog(initial: _baseUrlController.text.trim()),
    );
    if (endpoint == null || endpoint.isEmpty) return;
    await _fetchModels(provider, endpointOverride: endpoint);
  }

  /// One-shot connectivity test: streams a tiny "Hi" through the gateway and
  /// reports success on the first event / done, or surfaces the transport
  /// error. Uses the form's current key / base URL so it works before 保存.
  Future<void> _testModel(ModelProvider provider, Model model) async {
    if (_testingModelId != null) return;
    setState(() => _testingModelId = model.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final testModel = model.copyWith(
        apiKey: _apiKeyController.text.trim().isEmpty
            ? provider.apiKey
            : _apiKeyController.text.trim(),
        baseUrl: _baseUrlController.text.trim().isEmpty
            ? provider.baseUrl
            : _baseUrlController.text.trim(),
        providerType: provider.providerType ?? model.providerType,
        extraHeaders: model.extraHeaders ?? provider.extraHeaders,
        extraBody: model.extraBody ?? provider.extraBody,
      );
      final gateway = ref
          .read(appLlmGatewayFactoryProvider)
          .forModel(testModel);
      final request = LlmChatRequest(
        model: testModel,
        messages: const [LlmMessage(role: MessageRole.user, content: 'Hi')],
        maxTokens: 1,
        extraHeaders: provider.extraHeaders,
        extraBody: provider.extraBody,
      );
      var ok = false;
      await for (final chunk
          in gateway.streamChat(request).timeout(const Duration(seconds: 30))) {
        if (chunk is LlmTextDelta ||
            chunk is LlmReasoningDelta ||
            chunk is LlmDone) {
          ok = true;
          break;
        }
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(ok ? '测试成功：${model.name}' : '测试无响应')),
      );
    } on TimeoutException {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('测试超时')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('测试失败：$e')));
    } finally {
      if (mounted) setState(() => _testingModelId = null);
    }
  }

  Future<void> _deleteModel(ModelProvider provider, String modelId) async {
    await ref
        .read(modelStoreProvider.notifier)
        .saveProvider(
          provider.copyWith(
            models: [
              for (final m in provider.models)
                if (m.id != modelId) m,
            ],
          ),
        );
  }

  /// 2-step group delete: the first tap arms [_groupPendingDelete]; a second tap
  /// (on the same group) removes every model in it.
  Future<void> _deleteGroup(ModelProvider provider, List<Model> models) async {
    final names = groupModels<Model>(
      [models.first],
      idOf: (m) => m.id,
      groupOf: (m) => m.group,
      providerId: provider.id,
    );
    final groupName = names.first.$1;
    if (_groupPendingDelete != groupName) {
      setState(() => _groupPendingDelete = groupName);
      return;
    }
    final ids = {for (final m in models) m.id};
    await ref
        .read(modelStoreProvider.notifier)
        .saveProvider(
          provider.copyWith(
            models: [
              for (final m in provider.models)
                if (!ids.contains(m.id)) m,
            ],
          ),
        );
    if (mounted) setState(() => _groupPendingDelete = null);
  }
}

/// The header block of the 配置 Tab — rendered inline at the top of the shared
/// config card (no card of its own): a 48px brand avatar, the provider name, a
/// `{type} API` subtitle and (for non-system providers) edit-name / delete
/// icon buttons.
class _ProviderHeader extends StatelessWidget {
  const _ProviderHeader({
    required this.provider,
    required this.typeLabel,
    required this.onEdit,
    required this.onDelete,
  });

  final ModelProvider provider;
  final String typeLabel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final type = provider.providerType;
    final assetPath = getProviderIcon(
      (type != null && type.isNotEmpty) ? type : provider.id,
      isDark: isDark,
    );
    final fallback = provider.name.isNotEmpty
        ? provider.name.substring(0, 1).toUpperCase()
        : '?';

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
          ),
          child: Image.asset(
            assetPath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => Center(
              child: Text(
                fallback,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                provider.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$typeLabel API',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (onEdit != null)
          IconButton(
            icon: const Icon(LucideIcons.pencil, size: 18),
            color: theme.colorScheme.secondary,
            tooltip: '编辑名称 / 类型',
            visualDensity: VisualDensity.compact,
            onPressed: onEdit,
          ),
        if (onDelete != null)
          IconButton(
            icon: const Icon(LucideIcons.trash2, size: 18),
            color: theme.colorScheme.error,
            tooltip: '删除供应商',
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
          ),
      ],
    );
  }
}

/// A compact tappable navigation row (icon + title + subtitle + chevron) used
/// inside the config card — e.g. the 高级 API 配置 entry — so a sub-page link
/// no longer needs its own heading + helper + button stack.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// The base-URL completion preview — a tinted rounded line showing the full
/// endpoint (`getCompleteApiUrl`).
class _UrlPreview extends StatelessWidget {
  const _UrlPreview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '完整端点',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            url,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single model row: a current-selection radio, the model name / id, an
/// optional 测试 button (when test mode is on) and edit (row tap) / delete.
class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.model,
    required this.isCurrent,
    required this.showTest,
    required this.testing,
    required this.testDisabled,
    required this.onTap,
    required this.onSelect,
    required this.onTest,
    required this.onDelete,
  });

  final Model model;
  final bool isCurrent;
  final bool showTest;
  final bool testing;
  final bool testDisabled;
  final VoidCallback onTap;
  final VoidCallback onSelect;
  final VoidCallback onTest;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            GestureDetector(
              onTap: onSelect,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  isCurrent ? LucideIcons.circleCheck : LucideIcons.circle,
                  size: 18,
                  color: isCurrent
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                model.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showTest)
              _MiniIconBtn(
                icon: testing
                    ? null
                    : LucideIcons.circleCheckBig,
                loading: testing,
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF66BB6A)
                    : const Color(0xFF2E7D32),
                tooltip: '测试连接',
                onPressed: testDisabled ? null : onTest,
              ),
            _MiniIconBtn(
              icon: LucideIcons.pencil,
              color: theme.colorScheme.secondary,
              tooltip: '编辑',
              onPressed: onTap,
            ),
            _MiniIconBtn(
              icon: LucideIcons.trash2,
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

/// 28×28 icon button for model rows — no Material splash padding bloat.
class _MiniIconBtn extends StatelessWidget {
  const _MiniIconBtn({
    this.icon,
    this.loading = false,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData? icon;
  final bool loading;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: color,
            ),
          )
        : Icon(icon, size: 14, color: onPressed != null ? color : color.withValues(alpha: 0.4));
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: child,
        ),
      ),
    );
  }
}

/// Compact toolbar chip for 获取 / 端点 / 添加 actions.
class _CompactActionChip extends StatelessWidget {
  const _CompactActionChip({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.accent,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;
    final base = accent ?? theme.colorScheme.primary;
    final color = enabled ? base : theme.disabledColor;

    return Material(
      color: enabled
          ? base.withValues(alpha: 0.1)
          : theme.colorScheme.onSurface.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Test mode toggle — icon button with a popup for "长期显示" switch.
class _TestModeToggle extends StatelessWidget {
  const _TestModeToggle({
    required this.active,
    required this.alwaysShow,
    required this.onToggleTestMode,
    required this.onToggleAlwaysShow,
  });

  final bool active;
  final bool alwaysShow;
  final VoidCallback onToggleTestMode;
  final ValueChanged<bool> onToggleAlwaysShow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active
        ? theme.colorScheme.error
        : (theme.brightness == Brightness.dark
            ? const Color(0xFF66BB6A)
            : const Color(0xFF2E7D32));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color.withValues(alpha: active ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onToggleTestMode,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.flaskConical, size: 13, color: color),
                  const SizedBox(width: 4),
                  Text(
                    active ? '退出' : '测试',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Tooltip(
          message: alwaysShow ? '隐藏测试按钮' : '长期显示测试按钮',
          child: GestureDetector(
            onTap: () => onToggleAlwaysShow(!alwaysShow),
            child: Icon(
              alwaysShow ? LucideIcons.pin : LucideIcons.pinOff,
              size: 14,
              color: alwaysShow
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// The 编辑供应商 dialog (name + provider type). Pops `(name, type)` on save, or
/// null on cancel. Mirrors the original `handleEditProviderName`.
class _EditProviderDialog extends StatefulWidget {
  const _EditProviderDialog({required this.provider});

  final ModelProvider provider;

  @override
  State<_EditProviderDialog> createState() => _EditProviderDialogState();
}

class _EditProviderDialogState extends State<_EditProviderDialog> {
  late final TextEditingController _name;
  String? _type;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.provider.name);
    final stored = widget.provider.providerType;
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
            DropdownButtonFormField<String>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '供应商类型',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final option in providerTypeOptions)
                  DropdownMenuItem<String>(
                    value: option.$1,
                    child: Text(option.$2),
                  ),
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
class _CustomEndpointDialog extends StatefulWidget {
  const _CustomEndpointDialog({required this.initial});

  final String initial;

  @override
  State<_CustomEndpointDialog> createState() => _CustomEndpointDialogState();
}

class _CustomEndpointDialogState extends State<_CustomEndpointDialog> {
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

// ─── Parameter scope row ─────────────────────────────────────────────────────

/// Dropdown for selecting the parameter display scope (parameterScope) at the
/// provider level. See `docs/PARAMETER_SCOPE_DESIGN.md`.
const List<(String?, String)> _parameterScopeOptions = [
  (null, '自动检测'),
  ('openai', 'OpenAI'),
  ('anthropic', 'Anthropic'),
  ('gemini', 'Gemini'),
  ('openaiCompatible', 'OpenAI 兼容'),
];

class _ParameterScopeRow extends StatelessWidget {
  const _ParameterScopeRow({
    required this.value,
    required this.labelStyle,
    required this.hintStyle,
    required this.onChanged,
  });

  final String? value;
  final TextStyle labelStyle;
  final TextStyle hintStyle;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text('参数能力范围', style: labelStyle),
            const SizedBox(width: 6),
            Tooltip(
              message:
                  '设置后，参数编辑器将按指定的模型家族显示可用参数，\n'
                  '覆盖自动检测结果。适用于第三方 API 转发场景。',
              child: Icon(LucideIcons.info, size: 15, color: hintStyle.color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: _parameterScopeOptions.any((o) => o.$1 == value)
              ? value
              : null,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: [
            for (final option in _parameterScopeOptions)
              DropdownMenuItem<String?>(
                value: option.$1,
                child: Text(option.$2),
              ),
          ],
          onChanged: onChanged,
        ),
        const SizedBox(height: 4),
        Text('设置此供应商下所有模型的参数显示范围（模型级设置优先）', style: hintStyle),
      ],
    );
  }
}
