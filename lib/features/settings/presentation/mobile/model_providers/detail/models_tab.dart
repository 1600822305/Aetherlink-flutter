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
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/detail/model_row.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/detail/model_toolbar_chips.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/detail/provider_dialogs.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/fetched_models_sheet.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/provider_config_utils.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_checks.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_registry.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

// =============================================================================
// Models Tab — isolated StatefulWidget so search / test / fetch setState does
// NOT rebuild the config tab or parent scaffold.
// =============================================================================

class ModelsTab extends ConsumerStatefulWidget {
  const ModelsTab({
    super.key,
    required this.provider,
    required this.apiKeyController,
    required this.baseUrlController,
    required this.tabController,
  });

  final ModelProvider provider;
  final TextEditingController apiKeyController;
  final TextEditingController baseUrlController;
  final TabController tabController;

  @override
  ConsumerState<ModelsTab> createState() => _ModelsTabState();
}

class _ModelsTabState extends ConsumerState<ModelsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  bool _showTestButtons = false;
  bool _fetching = false;
  String? _testingModelId;
  bool _kvLoaded = false;

  /// 2-step group delete: holds the group name armed by a first tap. A second
  /// tap on the same group performs the delete. Auto-disarms via [_disarmTimer].
  String? _groupPendingDelete;
  Timer? _disarmTimer;

  // groupModels cache — avoids O(n log n) recomputation every build.
  List<Model>? _cachedModelsList;
  String _cachedSearch = '';
  List<(String, List<Model>)> _cachedGroups = const [];

  @override
  void initState() {
    super.initState();
    widget.tabController.addListener(_onTabChanged);
    _loadKvSettings();
    _ensureRegistry();
  }

  /// Loads the preset capability registry so per-row capability icons can use
  /// preset-level data (matching the editor); inference still works without it.
  Future<void> _ensureRegistry() async {
    await ModelRegistry.instance.ensureLoaded();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_onTabChanged);
    _disarmTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (widget.tabController.indexIsChanging) return;
    if (_search.isNotEmpty) {
      _searchController.clear();
      setState(() => _search = '');
    }
  }

  Future<void> _loadKvSettings() async {
    if (_kvLoaded) return;
    _kvLoaded = true;
    final result = await ref
        .read(appSettingsStoreProvider)
        .getSetting('alwaysShowTestButton_${widget.provider.id}');
    if (!mounted) return;
    if (result == 'true') {
      setState(() => _showTestButtons = true);
    }
  }

  List<(String, List<Model>)> _computeGroups() {
    final provider = widget.provider;
    if (identical(provider.models, _cachedModelsList) &&
        _search == _cachedSearch) {
      return _cachedGroups;
    }
    final query = _search.trim().toLowerCase();
    final filtered = query.isEmpty
        ? provider.models
        : [
            for (final m in provider.models)
              if (m.name.toLowerCase().contains(query) ||
                  m.id.toLowerCase().contains(query))
                m,
          ];
    _cachedModelsList = provider.models;
    _cachedSearch = _search;
    _cachedGroups = groupModels<Model>(
      filtered,
      idOf: (m) => m.id,
      groupOf: (m) => m.group,
      providerId: provider.id,
    );
    return _cachedGroups;
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final theme = Theme.of(context);

    final groups = _computeGroups();
    final showTest = _showTestButtons;

    // 2 header items (toolbar, search) + body items (groups or 1 empty state).
    const headerCount = 2;
    final bodyCount = groups.isEmpty ? 1 : groups.length;

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: headerCount + bodyCount,
      itemBuilder: (context, index) {
        // ─── Toolbar row ───────────────────────────────────────────
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      CompactActionChip(
                        label: '获取',
                        icon: LucideIcons.download,
                        onPressed: _fetching
                            ? null
                            : () => _fetchModels(provider),
                      ),
                      CompactActionChip(
                        label: '端点',
                        icon: LucideIcons.link,
                        accent: theme.colorScheme.secondary,
                        onPressed: _fetching
                            ? null
                            : () => _customEndpoint(provider),
                      ),
                      CompactActionChip(
                        label: '添加',
                        icon: LucideIcons.plus,
                        onPressed: () =>
                            context.push(AppRouter.editModelPath(provider.id)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TestButtonChip(
                  active: _showTestButtons,
                  onToggle: () {
                    final next = !_showTestButtons;
                    setState(() => _showTestButtons = next);
                    ref
                        .read(appSettingsStoreProvider)
                        .saveSetting(
                          'alwaysShowTestButton_${provider.id}',
                          next.toString(),
                        );
                  },
                ),
              ],
            ),
          );
        }

        // ─── Search bar ────────────────────────────────────────────
        if (index == 1) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
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
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 0,
                  ),
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                ),
              ),
            ),
          );
        }

        // ─── Empty states ──────────────────────────────────────────
        if (provider.models.isEmpty) {
          return Padding(
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
          );
        }
        if (groups.isEmpty) {
          return Padding(
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
          );
        }

        // ─── Group card (lazy) ─────────────────────────────────────
        final gi = index - headerCount;
        final (groupName, models) = groups[gi];
        return Padding(
          padding: EdgeInsets.only(bottom: gi < groups.length - 1 ? 10 : 0),
          child: ModelSettingsCard(
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
                      onPressed: () =>
                          _deleteGroup(provider, models, groupName),
                      icon: Icon(
                        _groupPendingDelete == groupName
                            ? LucideIcons.check
                            : LucideIcons.trash2,
                        size: 14,
                      ),
                      color: theme.colorScheme.error,
                      style: _groupPendingDelete == groupName
                          ? IconButton.styleFrom(
                              backgroundColor: theme.colorScheme.error
                                  .withValues(alpha: 0.15),
                            )
                          : null,
                      tooltip: _groupPendingDelete == groupName
                          ? '再次点击确认删除整组'
                          : '删除整组',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                    ),
                  ],
                ),
                const Divider(height: 4),
                for (final model in models)
                  ModelRow(
                    model: model,
                    showTest: showTest,
                    testing: _testingModelId == model.id,
                    testDisabled: _testingModelId != null,
                    onTap: () => context.push(
                      AppRouter.editModelPath(provider.id, modelId: model.id),
                    ),
                    onTest: () => _testModel(provider, model),
                    onDelete: () => _deleteModel(provider, model.id),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Model Tab Actions
  // ---------------------------------------------------------------------------

  Future<void> _fetchModels(
    ModelProvider provider, {
    String? endpointOverride,
  }) async {
    if (_fetching) return;
    final baseUrl = endpointOverride?.trim().isNotEmpty == true
        ? endpointOverride!.trim()
        : (widget.baseUrlController.text.trim().isEmpty
              ? null
              : widget.baseUrlController.text.trim());
    final catalog = ref.read(appModelCatalogProvider);
    // Fire the request but DON'T await it here — the sheet opens immediately and
    // shows a loading state while this resolves, so there's no perceived lag.
    final modelsFuture = catalog.listModels(
      LlmModelQuery(
        providerType: provider.providerType ?? provider.name,
        apiKey: widget.apiKeyController.text.trim().isEmpty
            ? null
            : widget.apiKeyController.text.trim(),
        baseUrl: baseUrl,
        extraHeaders: provider.extraHeaders,
      ),
    );
    final existingIds = {for (final m in provider.models) m.id};
    setState(() => _fetching = true);
    try {
      final result = await showModalBottomSheet<FetchedModelsResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => FetchedModelsSheet(
          modelsFuture: modelsFuture,
          existingIds: existingIds,
          providerId: provider.id,
        ),
      );
      if (result == null || !mounted) return;
      final notifier = ref.read(modelStoreProvider.notifier);
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
      if (result.toRemove.isNotEmpty) {
        final removeIds = result.toRemove.toSet();
        final current = await ref
            .read(appModelRepositoryProvider)
            .getProvider(provider.id);
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
        AppToast.success(context, '已${msgs.join("、")} 个模型');
      }
    } catch (_) {
      if (!mounted) return;
      AppToast.error(context, '保存模型变更失败');
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Future<void> _customEndpoint(ModelProvider provider) async {
    final endpoint = await showDialog<String>(
      context: context,
      builder: (ctx) =>
          CustomEndpointDialog(initial: widget.baseUrlController.text.trim()),
    );
    if (endpoint == null || endpoint.isEmpty) return;
    await _fetchModels(provider, endpointOverride: endpoint);
  }

  Future<void> _testModel(ModelProvider provider, Model model) async {
    if (_testingModelId != null) return;
    // 非对话模型（生图/生视频/嵌入/重排）没有聊天端点，连通性测试必然失败 —
    // 直接说明而不是误报（真实生成测试会产生费用，不做）。
    if (isNonChatModel(model)) {
      AppToast.warning(context, '该模型为生成/嵌入类模型，不支持对话连通性测试');
      return;
    }
    setState(() => _testingModelId = model.id);
    try {
      final testModel = model.copyWith(
        apiKey: widget.apiKeyController.text.trim().isEmpty
            ? provider.apiKey
            : widget.apiKeyController.text.trim(),
        baseUrl: widget.baseUrlController.text.trim().isEmpty
            ? provider.baseUrl
            : widget.baseUrlController.text.trim(),
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
      if (ok) {
        AppToast.success(context, '测试成功：${model.name}');
      } else {
        AppToast.warning(context, '测试无响应');
      }
    } on TimeoutException {
      if (!mounted) return;
      AppToast.error(context, '测试超时');
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, '测试失败：$e');
    } finally {
      if (mounted) setState(() => _testingModelId = null);
    }
  }

  /// Single-model delete is immediate (no confirmation) — the undo toast is the
  /// safety net.
  Future<void> _deleteModel(ModelProvider provider, String modelId) async {
    final model = provider.models.where((m) => m.id == modelId).firstOrNull;
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
    if (!mounted || model == null) return;

    AppToast.show(
      context,
      '已删除「${model.name}」',
      type: AppToastType.success,
      duration: const Duration(seconds: 5),
      action: AppToastAction(
        label: '撤销',
        onPressed: () async {
          final current = ref.read(appModelProviderProvider(provider.id));
          final currentProvider = current.maybeWhen(
            data: (p) => p,
            orElse: () => null,
          );
          if (currentProvider == null) return;
          await ref
              .read(modelStoreProvider.notifier)
              .saveProvider(
                currentProvider.copyWith(
                  models: [...currentProvider.models, model],
                ),
              );
        },
      ),
    );
  }

  /// 2-step group delete: the first tap arms [_groupPendingDelete] (the trash
  /// icon turns into a highlighted check); a second tap on the same group
  /// removes every model in it. Auto-disarms after a few seconds.
  Future<void> _deleteGroup(
    ModelProvider provider,
    List<Model> models,
    String groupName,
  ) async {
    if (_groupPendingDelete != groupName) {
      setState(() => _groupPendingDelete = groupName);
      _disarmTimer?.cancel();
      _disarmTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _groupPendingDelete = null);
      });
      return;
    }
    _disarmTimer?.cancel();
    if (mounted) setState(() => _groupPendingDelete = null);

    final deletedModels = List<Model>.of(models);
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
    if (!mounted) return;

    AppToast.show(
      context,
      '已删除「$groupName」(${deletedModels.length} 个模型)',
      type: AppToastType.success,
      duration: const Duration(seconds: 5),
      action: AppToastAction(
        label: '撤销',
        onPressed: () async {
          final current = ref.read(appModelProviderProvider(provider.id));
          final currentProvider = current.maybeWhen(
            data: (p) => p,
            orElse: () => null,
          );
          if (currentProvider == null) return;
          await ref
              .read(modelStoreProvider.notifier)
              .saveProvider(
                currentProvider.copyWith(
                  models: [...currentProvider.models, ...deletedModels],
                ),
              );
        },
      ),
    );
  }
}
