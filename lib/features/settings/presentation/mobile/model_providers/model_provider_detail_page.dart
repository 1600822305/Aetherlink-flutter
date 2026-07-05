import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/detail/models_tab.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/detail/provider_config_widgets.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/detail/provider_dialogs.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/provider_config_utils.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/api_key_config.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';
import 'package:aetherlink_flutter/shared/widgets/instant_switch_tab_view.dart';

/// The 供应商详情 third-level page — a style-aligned (not pixel-1:1) port of
/// `src/pages/Settings/ModelProviders/index.tsx`, reusing the PR #44 design
/// system. The long original scroll is split into a top **Tab (配置 / 模型)**:
///
///  * AppBar: dynamic provider name + 启用 switch + 保存.
///  * Tab 配置: header block (avatar + name + `{type} API` + edit/delete),
///    single/multi-key mode, key input, multi-key entry point, base-URL
///    completion preview, Responses-API toggle (wired into the request layer)
///    and the advanced-API entry point.
///  * Tab 模型: a single (persisted) 测试 toggle that shows/hides a per-row
///    test button, search, the 自动获取 / 自定义端点 / 手动添加 tool row and the
///    grouped model list (row tap edits; per-row capability icons + test +
///    instant delete; 2-step group delete).
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
  bool _obscureKey = true;
  bool _initialized = false;
  bool _isEnabled = false;
  bool _useResponsesAPI = false;
  bool _useMultiKey = false;
  bool _kvLoaded = false;

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
    super.dispose();
  }

  void _seedFrom(ModelProvider provider) {
    if (_initialized) return;
    _apiKeyController.text = provider.apiKey ?? '';
    _baseUrlController.text = provider.baseUrl ?? '';
    _isEnabled = provider.isEnabled;
    _useResponsesAPI = provider.useResponsesAPI ?? false;
    final management = provider.keyManagement;
    _useMultiKey = management?.enabled ?? (provider.apiKeys?.isNotEmpty ?? false);
    _initialized = true;
    // keyManagement.enabled is the source of truth; the KV setting is only a
    // legacy fallback from before the flag existed.
    if (management == null) _loadKvSettings(provider.id);
  }

  Future<void> _loadKvSettings(String providerId) async {
    if (_kvLoaded) return;
    _kvLoaded = true;
    final result = await ref
        .read(appSettingsStoreProvider)
        .getSetting('useMultiKey_$providerId');
    if (!mounted) return;
    if (result != null) {
      setState(() => _useMultiKey = result == 'true');
    }
  }

  Future<void> _save(ModelProvider provider) async {
    // Re-read the latest provider state to avoid overwriting concurrent changes
    // (e.g. models added/removed by _fetchModels/_deleteModel while this page
    // was open).
    final freshAsync = ref.read(appModelProviderProvider(provider.id));
    final fresh = freshAsync.maybeWhen(data: (p) => p, orElse: () => null);
    final base = fresh ?? provider;
    final updated = base.copyWith(
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
    AppToast.success(context, '已保存');
  }

  /// Flips 单/多 Key mode. Turning multi-key **on** with an empty pool inherits
  /// the current single key as the pool's first entry; turning it **off** keeps
  /// the pool stored untouched (only `keyManagement.enabled` flips), so the
  /// keys and their stats survive a round-trip back to multi-key.
  Future<void> _setMultiKeyMode(ModelProvider provider, bool enabled) async {
    setState(() => _useMultiKey = enabled);
    final management = (provider.keyManagement ?? const KeyManagementConfig())
        .copyWith(enabled: enabled);
    var updated = provider.copyWith(keyManagement: management);
    final mainKey = _apiKeyController.text.trim();
    if (enabled &&
        (provider.apiKeys == null || provider.apiKeys!.isEmpty) &&
        mainKey.isNotEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      updated = updated.copyWith(
        apiKeys: [
          ApiKeyConfig(
            id: 'main_$now',
            key: mainKey,
            name: '主 Key',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );
    }
    await ref.read(modelStoreProvider.notifier).saveProvider(updated);
    if (!mounted) return;
    if (enabled && updated.apiKeys?.length == 1 && mainKey.isNotEmpty) {
      AppToast.success(context, '已将主 Key 导入多 Key 池');
    } else if (!enabled && (provider.apiKeys?.isNotEmpty ?? false)) {
      AppToast.success(context, '已切为单 Key，多 Key 池已保留');
    }
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
          // Pill-style segmented control matching the 语音功能 / MCP 服务器
          // settings pages: a rounded grey "track" with a white card indicator
          // (soft 1px shadow) sliding under the active tab.
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: theme.colorScheme.onSurface,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(height: 32, text: '配置'),
                Tab(height: 32, text: '模型'),
              ],
            ),
          ),
          Expanded(
            child: InstantSwitchTabView(
              controller: _tabController,
              children: [
                _buildConfigTab(context, provider),
                ModelsTab(
                  provider: provider,
                  apiKeyController: _apiKeyController,
                  baseUrlController: _baseUrlController,
                  tabController: _tabController,
                ),
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
              ProviderHeader(
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
                    onChanged: (v) => _setMultiKeyMode(provider, v),
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
                UrlPreview(
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
              ParameterScopeRow(
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
              NavRow(
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
      builder: (_) => EditProviderDialog(provider: provider),
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
}
