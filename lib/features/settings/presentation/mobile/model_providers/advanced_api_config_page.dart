import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

/// The "高级 API 配置" third-level page, a 1:1 reproduction of
/// `src/pages/Settings/ModelProviders/AdvancedAPIConfig.tsx`.
///
/// Reads the provider by [providerId] and edits its `extraHeaders` (the Headers
/// tab) and `extraBody` (the Body tab). Add/delete rows mutate local state; 保存
/// persists both maps through the model store. Body values are parsed as JSON
/// (numbers / booleans / objects); anything else is stored as a raw string.
class AdvancedApiConfigPage extends ConsumerStatefulWidget {
  const AdvancedApiConfigPage({super.key, required this.providerId});

  final String providerId;

  static const String _title = '高级 API 配置';
  static const String _saveLabel = '保存';
  static const String _headersTab = '请求头 (Headers)';
  static const String _bodyTab = '请求体 (Body)';

  @override
  ConsumerState<AdvancedApiConfigPage> createState() =>
      _AdvancedApiConfigPageState();
}

class _AdvancedApiConfigPageState extends ConsumerState<AdvancedApiConfigPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );

  final Map<String, String> _headers = {};
  final Map<String, dynamic> _body = {};
  bool _initialized = false;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _seedFrom(ModelProvider provider) {
    if (_initialized) return;
    _initialized = true;
    _headers.addAll(provider.extraHeaders ?? const {});
    _body.addAll(provider.extraBody ?? const {});
  }

  Future<void> _save(ModelProvider provider) async {
    final updated = provider.copyWith(
      extraHeaders: _headers.isEmpty
          ? null
          : Map<String, String>.from(_headers),
      extraBody: _body.isEmpty ? null : Map<String, dynamic>.from(_body),
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
            appBar: ModelSettingsAppBar(title: AdvancedApiConfigPage._title),
            body: Center(child: Text('供应商不存在')),
          );
        }
        _seedFrom(provider);
        return _buildContent(theme, provider);
      },
      orElse: () => const Scaffold(
        appBar: ModelSettingsAppBar(title: AdvancedApiConfigPage._title),
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, ModelProvider provider) {
    return Scaffold(
      appBar: ModelSettingsAppBar(
        title: AdvancedApiConfigPage._title,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: ElevatedButton(
              onPressed: () => _save(provider),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(AdvancedApiConfigPage._saveLabel),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Pill segmented control — same style as 语音功能 / MCP 服务器
          // settings: rounded grey track + white card indicator (1px shadow).
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
                Tab(height: 32, text: AdvancedApiConfigPage._headersTab),
                Tab(height: 32, text: AdvancedApiConfigPage._bodyTab),
              ],
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) => _tabController.index == 0
                  ? _HeadersTab(
                      headers: _headers,
                      onQuickAction: (name) =>
                          setState(() => _headers[name] = 'REMOVE'),
                      onAdd: (name, value) =>
                          setState(() => _headers[name] = value),
                      onDelete: (name) => setState(() => _headers.remove(name)),
                    )
                  : _BodyTab(
                      body: _body,
                      onAdd: (name, value) =>
                          setState(() => _body[name] = value),
                      onDelete: (name) => setState(() => _body.remove(name)),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A `variant="outlined"` Paper: a 16px-radius divider-bordered box (no shadow).
class _OutlinedBox extends StatelessWidget {
  const _OutlinedBox({required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _HeadersTab extends StatelessWidget {
  const _HeadersTab({
    required this.headers,
    required this.onQuickAction,
    required this.onAdd,
    required this.onDelete,
  });

  final Map<String, String> headers;
  final ValueChanged<String> onQuickAction;
  final void Function(String name, String value) onAdd;
  final ValueChanged<String> onDelete;

  static const String _description = '用于解决 CORS 问题或添加特殊认证头';
  static const String _quickActions = '快速操作';
  static const String _disableTimeout = '禁用 x-stainless-timeout';
  static const String _disableRetry = '禁用 x-stainless-retry-count';
  static const String _disableAll = '禁用所有 stainless 头部';
  static const String _removeHint = '设置值为 "REMOVE" 可以禁用默认的请求头';
  static const String _newName = '新请求头名称';
  static const String _newNameHint = '例如: x-stainless-timeout';
  static const String _newValue = '新请求头值';
  static const String _newValueHint = '例如: 30000';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          _description,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        _OutlinedBox(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _quickActions,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PillButton(
                    label: _disableTimeout,
                    onPressed: () => onQuickAction('x-stainless-timeout'),
                  ),
                  _PillButton(
                    label: _disableRetry,
                    onPressed: () => onQuickAction('x-stainless-retry-count'),
                  ),
                  _PillButton(
                    label: _disableAll,
                    onPressed: () {
                      onQuickAction('x-stainless-timeout');
                      onQuickAction('x-stainless-retry-count');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _removeHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _ConfiguredList(
          title: '已配置 ${headers.length} 个请求头',
          emptyHint: _removeHint,
          entries: [
            for (final e in headers.entries) (key: e.key, value: e.value),
          ],
          onDelete: onDelete,
        ),
        const SizedBox(height: 24),
        _AddRow(
          nameLabel: _newName,
          nameHint: _newNameHint,
          valueLabel: _newValue,
          valueHint: _newValueHint,
          onSubmit: onAdd,
        ),
      ],
    );
  }
}

class _BodyTab extends StatelessWidget {
  const _BodyTab({
    required this.body,
    required this.onAdd,
    required this.onDelete,
  });

  final Map<String, dynamic> body;
  final void Function(String name, dynamic value) onAdd;
  final ValueChanged<String> onDelete;

  static const String _description =
      '添加额外的请求体参数，这些参数会合并到API请求中。支持JSON格式、数字、布尔值和字符串。';
  static const String _emptyHint = '暂无自定义请求体参数，点击下方添加按钮添加参数';
  static const String _newName = '新参数名称';
  static const String _newNameHint = '例如: custom_param';
  static const String _newValue = '新参数值';
  static const String _newValueHint = '例如: {"key": "value"} 或 123 或 true';

  /// Parses [raw] as JSON (numbers / booleans / lists / objects); falls back to
  /// the raw string when it is not valid JSON.
  static dynamic _parseValue(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          _description,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        _ConfiguredList(
          title: '已配置 ${body.length} 个请求体参数',
          emptyHint: _emptyHint,
          entries: [
            for (final e in body.entries) (key: e.key, value: '${e.value}'),
          ],
          onDelete: onDelete,
        ),
        const SizedBox(height: 24),
        _AddRow(
          nameLabel: _newName,
          nameHint: _newNameHint,
          valueLabel: _newValue,
          valueHint: _newValueHint,
          onSubmit: (name, value) => onAdd(name, _parseValue(value)),
        ),
      ],
    );
  }
}

/// The "已配置 N 个…" box: lists current entries with a per-row delete, or the
/// empty hint when there are none.
class _ConfiguredList extends StatelessWidget {
  const _ConfiguredList({
    required this.title,
    required this.emptyHint,
    required this.entries,
    required this.onDelete,
  });

  final String title;
  final String emptyHint;
  final List<({String key, String value})> entries;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _OutlinedBox(
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
          if (entries.isEmpty) ...[
            const SizedBox(height: 4),
            Text(
              emptyHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${entry.key}: ${entry.value}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.trash2, size: 18),
                      color: theme.colorScheme.error,
                      tooltip: '删除',
                      onPressed: () => onDelete(entry.key),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// A pill `Button` (`borderRadius: 999`) — the original quick-action chips.
class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        textStyle: const TextStyle(fontSize: 13),
      ),
      child: Text(label),
    );
  }
}

/// The "添加新…" row: two inputs + a 提交 button that adds the entry.
class _AddRow extends StatefulWidget {
  const _AddRow({
    required this.nameLabel,
    required this.nameHint,
    required this.valueLabel,
    required this.valueHint,
    required this.onSubmit,
  });

  final String nameLabel;
  final String nameHint;
  final String valueLabel;
  final String valueHint;
  final void Function(String name, String value) onSubmit;

  @override
  State<_AddRow> createState() => _AddRowState();
}

class _AddRowState extends State<_AddRow> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();

  static const String _submitLabel = '提交';

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _nameController.text.trim().isNotEmpty;

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    widget.onSubmit(name, _valueController.text);
    _nameController.clear();
    _valueController.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _OutlinedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ModelFormField(
            label: widget.nameLabel,
            hint: widget.nameHint,
            controller: _nameController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          ModelFormField(
            label: widget.valueLabel,
            hint: widget.valueHint,
            controller: _valueController,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text(_submitLabel),
            ),
          ),
        ],
      ),
    );
  }
}
