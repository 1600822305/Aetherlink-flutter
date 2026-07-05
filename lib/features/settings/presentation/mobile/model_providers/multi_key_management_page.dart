import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/shared/widgets/app_select_field.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';
import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/api_key_config.dart';
import 'package:aetherlink_flutter/shared/domain/api_key_manager.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

/// 多 Key 管理 sub-page — a style-aligned port of the original
/// `src/components/settings/MultiKeyManager.tsx`. Lists / adds / edits the
/// provider's `apiKeys` pool and its `keyManagement` load-balancing strategy.
/// Every mutation persists immediately (no explicit 保存 step): edits merge
/// into the latest stored pool by key id, so usage stats written by concurrent
/// requests are never clobbered, and the list re-renders from the store so the
/// stats stay live.
///
/// The request layer (`ChatController._streamInto` via `ApiKeyManager`) now
/// strategy-selects a key from this pool per request, fails over on error and
/// persists per-key usage/status back here, so the stats below reflect real
/// traffic.
class MultiKeyManagementPage extends ConsumerStatefulWidget {
  const MultiKeyManagementPage({super.key, required this.providerId});

  final String providerId;

  static const String _title = '多 Key 管理';

  @override
  ConsumerState<MultiKeyManagementPage> createState() =>
      _MultiKeyManagementPageState();
}

class _MultiKeyManagementPageState
    extends ConsumerState<MultiKeyManagementPage> {
  String? _pendingDeleteId;

  /// Ticks the cooldown countdowns shown on errored / rate-limited keys.
  Timer? _cooldownTicker;

  @override
  void initState() {
    super.initState();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    super.dispose();
  }

  /// Persists the full pool (add / delete need a list rewrite). Single-key
  /// changes go through [_saveKey] instead so concurrent stat writes merge.
  Future<void> _savePool(
    ModelProvider provider,
    List<ApiKeyConfig> keys,
  ) async {
    await ref
        .read(modelStoreProvider.notifier)
        .saveProvider(provider.copyWith(apiKeys: keys.isEmpty ? null : keys));
  }

  /// Persists one changed key, merged into the latest stored pool by id.
  Future<void> _saveKey(ModelProvider provider, ApiKeyConfig key) async {
    await ref
        .read(modelStoreProvider.notifier)
        .updateApiKeys(providerId: provider.id, keys: [key]);
  }

  Future<void> _saveManagement(
    ModelProvider provider,
    KeyManagementConfig management,
  ) async {
    await ref
        .read(modelStoreProvider.notifier)
        .saveProvider(provider.copyWith(keyManagement: management));
  }

  Future<void> _recoverKey(ModelProvider provider, ApiKeyConfig key) async {
    await _saveKey(provider, ApiKeyManager.instance.recoverKey(key));
    if (mounted) AppToast.success(context, '已恢复');
  }

  Future<void> _addOrEditKey(
    ModelProvider provider, [
    ApiKeyConfig? key,
  ]) async {
    final keys = [...?provider.apiKeys];
    final result = await showDialog<ApiKeyConfig>(
      context: context,
      builder: (_) => _KeyEditorDialog(
        providerName: provider.name,
        existing: key,
        siblings: keys,
      ),
    );
    if (result == null) return;
    setState(() => _pendingDeleteId = null);
    if (keys.any((k) => k.id == result.id)) {
      await _saveKey(provider, result);
    } else {
      await _savePool(provider, [...keys, result]);
    }
    if (mounted) AppToast.success(context, '已保存');
  }

  Future<void> _importKeys(ModelProvider provider) async {
    final existing = [...?provider.apiKeys];
    final imported = await showDialog<List<String>>(
      context: context,
      builder: (_) => _BatchImportDialog(
        existingKeys: {for (final k in existing) k.key},
      ),
    );
    if (imported == null || imported.isEmpty) return;
    setState(() => _pendingDeleteId = null);
    final now = DateTime.now().millisecondsSinceEpoch;
    final added = [
      for (var i = 0; i < imported.length; i++)
        ApiKeyConfig(
          id: '${now}_${i}_${Random().nextInt(1 << 32)}',
          key: imported[i],
          name: '导入 Key ${existing.length + i + 1}',
          createdAt: now,
          updatedAt: now,
        ),
    ];
    await _savePool(provider, [...existing, ...added]);
    if (mounted) AppToast.success(context, '已导入 ${added.length} 个 Key');
  }

  Future<void> _deleteKey(ModelProvider provider, String id) async {
    if (_pendingDeleteId == id) {
      setState(() => _pendingDeleteId = null);
      await _savePool(provider, [
        for (final k in [...?provider.apiKeys])
          if (k.id != id) k,
      ]);
      if (mounted) AppToast.success(context, '已删除');
    } else {
      setState(() => _pendingDeleteId = id);
    }
  }

  Future<void> _toggleKey(
    ModelProvider provider,
    String id,
    bool enabled,
  ) async {
    setState(() => _pendingDeleteId = null);
    final key = [...?provider.apiKeys].where((k) => k.id == id).firstOrNull;
    if (key == null) return;
    await _saveKey(
      provider,
      key.copyWith(
        isEnabled: enabled,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
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
            appBar: ModelSettingsAppBar(title: MultiKeyManagementPage._title),
            body: Center(child: Text('供应商不存在')),
          );
        }
        return _buildContent(context, provider);
      },
      orElse: () => const Scaffold(
        appBar: ModelSettingsAppBar(title: MultiKeyManagementPage._title),
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ModelProvider provider) {
    final theme = Theme.of(context);

    final keys = [...?provider.apiKeys];
    final management = provider.keyManagement ?? const KeyManagementConfig();
    final total = keys.length;
    final active = keys.where((k) => k.isEnabled && k.status == 'active').length;
    final errored = keys.where((k) => k.status == 'error').length;
    final totalReq = keys.fold<int>(
      0,
      (sum, k) => sum + k.usage.totalRequests,
    );
    final successReq = keys.fold<int>(
      0,
      (sum, k) => sum + k.usage.successfulRequests,
    );
    final successRate = totalReq == 0
        ? 0
        : (successReq * 100 / totalReq).round();

    return Scaffold(
      appBar: const ModelSettingsAppBar(title: MultiKeyManagementPage._title),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          const _InfoNotice(
            text:
                '发送时按下方策略从启用的 Key 中自动选择，连续失败会标为错误并冷却 5 分钟，'
                '冷却期过后自动恢复；以下统计会随真实请求更新，修改即时保存。',
          ),
          const SizedBox(height: 16),
          // 统计卡片
          Row(
            children: [
              _StatCard(label: '总数', value: '$total'),
              const SizedBox(width: 12),
              _StatCard(
                label: '正常',
                value: '$active',
                color: _successColor(theme),
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: '错误',
                value: '$errored',
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 12),
              _StatCard(label: '成功率', value: '$successRate%'),
            ],
          ),
          const SizedBox(height: 16),
          // 负载均衡策略
          ModelSettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const ModelSectionTitle('负载均衡策略'),
                const SizedBox(height: 16),
                AppSelectField<String>(
                  value: management.strategy,
                  sheetTitle: '负载均衡策略',
                  options: const [
                    AppSelectOption(
                      value: 'round_robin',
                      label: '轮询 (Round Robin)',
                    ),
                    AppSelectOption(value: 'priority', label: '优先级 (Priority)'),
                    AppSelectOption(
                      value: 'least_used',
                      label: '最少使用 (Least Used)',
                    ),
                    AppSelectOption(value: 'random', label: '随机 (Random)'),
                  ],
                  onChanged: (value) => _saveManagement(
                    provider,
                    management.copyWith(strategy: value),
                  ),
                ),
                const SizedBox(height: 16),
                _SliderRow(
                  label: '连续失败多少次标为错误',
                  value: management.maxFailuresBeforeDisable,
                  min: 1,
                  max: 10,
                  unit: '次',
                  onChanged: (v) => _saveManagement(
                    provider,
                    management.copyWith(maxFailuresBeforeDisable: v),
                  ),
                ),
                _SliderRow(
                  label: '错误冷却时长',
                  value: management.failureRecoveryTime,
                  min: 1,
                  max: 30,
                  unit: '分钟',
                  onChanged: (v) => _saveManagement(
                    provider,
                    management.copyWith(failureRecoveryTime: v),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '冷却后自动恢复',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    CustomSwitch(
                      value: management.enableAutoRecovery,
                      onChanged: (v) => _saveManagement(
                        provider,
                        management.copyWith(enableAutoRecovery: v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Key 列表
          ModelSettingsCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: ModelSectionTitle('API Keys ($total)')),
                    ModelTonalButton(
                      label: '导入',
                      icon: LucideIcons.clipboardPaste,
                      onPressed: () => _importKeys(provider),
                    ),
                    const SizedBox(width: 8),
                    ModelTonalButton(
                      label: '添加 Key',
                      icon: LucideIcons.plus,
                      onPressed: () => _addOrEditKey(provider),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (keys.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        '还没有配置 API Key，点击"添加 Key"开始配置。',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < keys.length; i++)
                    _KeyRow(
                      index: i,
                      config: keys[i],
                      management: management,
                      pendingDelete: _pendingDeleteId == keys[i].id,
                      onEdit: () => _addOrEditKey(provider, keys[i]),
                      onDelete: () => _deleteKey(provider, keys[i].id),
                      onToggle: (v) => _toggleKey(provider, keys[i].id, v),
                      onRecover: () => _recoverKey(provider, keys[i]),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _successColor(ThemeData theme) => theme.brightness == Brightness.dark
    ? const Color(0xFF66BB6A)
    : const Color(0xFF2E7D32);

/// A leading info banner — an info-tinted rounded box.
class _InfoNotice extends StatelessWidget {
  const _InfoNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: info.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.info, size: 16, color: info),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single stat tile (总数 / 正常 / 错误 / 成功率).
class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: ModelSettingsCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: color ?? theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled int slider row (failure threshold / cooldown minutes).
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        SizedBox(
          width: 140,
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(
            '$value $unit',
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// One API key row: name + status / priority chips, the masked key, the usage
/// line, the last error + cooldown countdown when the key is unhealthy, an
/// enable toggle and recover / edit / (2-step) delete actions.
class _KeyRow extends StatelessWidget {
  const _KeyRow({
    required this.index,
    required this.config,
    required this.management,
    required this.pendingDelete,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
    required this.onRecover,
  });

  final int index;
  final ApiKeyConfig config;
  final KeyManagementConfig management;
  final bool pendingDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRecover;

  static String _mask(String key) {
    if (key.length <= 8) return '••••••••';
    return '${key.substring(0, 4)}••••${key.substring(key.length - 4)}';
  }

  (String, Color) _statusInfo(ThemeData theme) {
    switch (config.status) {
      case 'active':
        return ('正常', _successColor(theme));
      case 'error':
        return ('错误', theme.colorScheme.error);
      case 'rate_limited':
        return ('限流', const Color(0xFFED6C02));
      case 'disabled':
        return ('禁用', const Color(0xFFED6C02));
      default:
        return ('未知', theme.colorScheme.onSurfaceVariant);
    }
  }

  /// The health line under the stats for an unhealthy key: last error, plus
  /// the cooldown countdown (or a manual-recovery hint when auto-recovery is
  /// off).
  String? _healthLine() {
    if (config.status != 'error' && config.status != 'rate_limited') {
      return null;
    }
    final remaining = ApiKeyManager.instance.cooldownRemaining(
      config,
      config: management,
    );
    final String recovery;
    if (remaining != null) {
      final minutes = (remaining.inSeconds / 60).ceil();
      recovery = '约 $minutes 分钟后自动恢复';
    } else if (config.status == 'error' && !management.enableAutoRecovery) {
      recovery = '自动恢复已关闭，需手动恢复';
    } else {
      recovery = '冷却已结束，下次发送时重试';
    }
    final error = config.lastError;
    return error == null || error.isEmpty ? recovery : '$error（$recovery）';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (statusText, statusColor) = _statusInfo(theme);
    final usage = config.usage;
    final healthLine = _healthLine();

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      config.name?.isNotEmpty == true
                          ? config.name!
                          : 'Key ${index + 1}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _Chip(label: statusText, color: statusColor, filled: true),
                    _Chip(label: '优先级: ${config.priority}'),
                  ],
                ),
              ),
              CustomSwitch(value: config.isEnabled, onChanged: onToggle),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _mask(config.key),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '请求: ${usage.totalRequests} | 成功: ${usage.successfulRequests} | '
            '失败: ${usage.failedRequests}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (healthLine != null) ...[
            const SizedBox(height: 2),
            Text(
              healthLine,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: statusColor,
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (healthLine != null)
                  IconButton(
                    icon: const Icon(LucideIcons.refreshCcw, size: 16),
                    color: _successColor(theme),
                    tooltip: '立即恢复',
                    onPressed: onRecover,
                  ),
                IconButton(
                  icon: const Icon(LucideIcons.pencil, size: 16),
                  color: theme.colorScheme.secondary,
                  tooltip: '编辑',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: Icon(
                    pendingDelete ? LucideIcons.check : LucideIcons.trash2,
                    size: 16,
                  ),
                  color: theme.colorScheme.error,
                  tooltip: pendingDelete ? '再次点击确认删除' : '删除',
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small rounded chip used for the status / priority labels.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.color, this.filled = false});

  final String label;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? c.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: filled ? 0 : 0.5)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: c,
        ),
      ),
    );
  }
}

/// The add / edit key dialog — key value (eye toggle), display name and a
/// 1..10 priority. Validates non-empty + de-duplicates against [siblings],
/// mirroring `handleSaveKey`.
class _KeyEditorDialog extends StatefulWidget {
  const _KeyEditorDialog({
    required this.providerName,
    required this.existing,
    required this.siblings,
  });

  final String providerName;
  final ApiKeyConfig? existing;
  final List<ApiKeyConfig> siblings;

  @override
  State<_KeyEditorDialog> createState() => _KeyEditorDialogState();
}

class _KeyEditorDialogState extends State<_KeyEditorDialog> {
  late final TextEditingController _key;
  late final TextEditingController _name;
  late int _priority;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _key = TextEditingController(text: widget.existing?.key ?? '');
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _priority = widget.existing?.priority ?? 5;
  }

  @override
  void dispose() {
    _key.dispose();
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _key.text.trim();
    if (value.isEmpty) {
      setState(() => _error = '请输入有效的 ${widget.providerName} API Key');
      return;
    }
    final duplicate = widget.siblings.any(
      (k) => k.key == value && k.id != widget.existing?.id,
    );
    if (duplicate) {
      setState(() => _error = '该 API Key 已存在');
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final name = _name.text.trim().isEmpty ? 'API Key $now' : _name.text.trim();
    final result = widget.existing == null
        ? ApiKeyConfig(
            id: '${now}_${Random().nextInt(1 << 32)}',
            key: value,
            name: name,
            priority: _priority,
            createdAt: now,
            updatedAt: now,
          )
        : widget.existing!.copyWith(
            key: value,
            name: name,
            priority: _priority,
            updatedAt: now,
          );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(
        widget.existing == null ? '添加 API Key' : '编辑 API Key',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _key,
              autofocus: true,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'API Key',
                border: const OutlineInputBorder(),
                errorText: _error,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? LucideIcons.eyeOff : LucideIcons.eye,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: '名称（可选）',
                hintText: '例如: 主力 Key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('优先级: $_priority', style: theme.textTheme.bodyMedium),
                Expanded(
                  child: Slider(
                    value: _priority.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '$_priority',
                    onChanged: (v) => setState(() => _priority = v.round()),
                  ),
                ),
              ],
            ),
            Text(
              '数值越小优先级越高（1-10）',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}

/// The batch import dialog: paste any number of keys separated by newlines /
/// commas / semicolons / spaces; blanks and duplicates (against the pasted
/// text and [existingKeys]) are dropped, and a live count previews how many
/// will be imported. Pops the deduplicated key list.
class _BatchImportDialog extends StatefulWidget {
  const _BatchImportDialog({required this.existingKeys});

  final Set<String> existingKeys;

  @override
  State<_BatchImportDialog> createState() => _BatchImportDialogState();
}

class _BatchImportDialogState extends State<_BatchImportDialog> {
  final TextEditingController _input = TextEditingController();
  List<String> _parsed = const [];
  int _skipped = 0;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _parse(String raw) {
    final tokens = raw
        .split(RegExp(r'[\s,;，；]+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final seen = <String>{};
    final unique = <String>[];
    var skipped = 0;
    for (final token in tokens) {
      if (widget.existingKeys.contains(token) || !seen.add(token)) {
        skipped++;
      } else {
        unique.add(token);
      }
    }
    setState(() {
      _parsed = unique;
      _skipped = skipped;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text(
        '批量导入 API Key',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _input,
              autofocus: true,
              minLines: 4,
              maxLines: 8,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                hintText: '每行一个 Key，也可用逗号 / 分号 / 空格分隔\nsk-aaa\nsk-bbb, sk-ccc',
                border: OutlineInputBorder(),
              ),
              onChanged: _parse,
            ),
            const SizedBox(height: 8),
            Text(
              _parsed.isEmpty && _skipped == 0
                  ? '粘贴后自动识别并去重'
                  : '识别到 ${_parsed.length} 个新 Key'
                        '${_skipped > 0 ? '，跳过 $_skipped 个重复/已存在' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
          onPressed: _parsed.isEmpty
              ? null
              : () => Navigator.of(context).pop(_parsed),
          child: Text('导入${_parsed.isEmpty ? '' : ' ${_parsed.length} 个'}'),
        ),
      ],
    );
  }
}
