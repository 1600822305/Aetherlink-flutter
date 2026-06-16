import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

/// The "高级 API 配置" third-level page, a 1:1 reproduction of
/// `src/pages/Settings/ModelProviders/AdvancedAPIConfig.tsx`.
///
/// Pure view, zero data: [providerId] is received but not queried (M4.3.2).
/// Switching the Headers / Body tabs is pure UI state (allowed); every
/// data-bearing control (quick actions, the new-row inputs, 提交, and the
/// per-row delete) renders disabled. With no stored config both tabs show
/// their empty state.
class AdvancedApiConfigPage extends StatefulWidget {
  const AdvancedApiConfigPage({super.key, required this.providerId});

  final String providerId;

  static const String _title = '高级 API 配置';
  static const String _saveLabel = '保存';
  static const String _headersTab = '请求头 (Headers)';
  static const String _bodyTab = '请求体 (Body)';

  @override
  State<AdvancedApiConfigPage> createState() => _AdvancedApiConfigPageState();
}

class _AdvancedApiConfigPageState extends State<AdvancedApiConfigPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: ModelSettingsAppBar(
        title: AdvancedApiConfigPage._title,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: ElevatedButton(
              // 保存 persists the config — disabled this milestone (no data).
              onPressed: null,
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
          Material(
            color: theme.colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              indicatorColor: theme.colorScheme.primary,
              tabs: const [
                Tab(text: AdvancedApiConfigPage._headersTab),
                Tab(text: AdvancedApiConfigPage._bodyTab),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) => _tabController.index == 0
                  ? const _HeadersTab()
                  : const _BodyTab(),
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
  const _HeadersTab();

  static const String _description = '用于解决 CORS 问题或添加特殊认证头';
  static const String _quickActions = '快速操作';
  static const String _disableTimeout = '禁用 x-stainless-timeout';
  static const String _disableRetry = '禁用 x-stainless-retry-count';
  static const String _disableAll = '禁用所有 stainless 头部';
  static const String _removeHint = '设置值为 "REMOVE" 可以禁用默认的请求头';
  static const String _configured = '已配置 0 个请求头';
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
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PillButton(label: _disableTimeout),
                  _PillButton(label: _disableRetry),
                  _PillButton(label: _disableAll),
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
        _OutlinedBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _configured,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _removeHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _AddRow(
          nameLabel: _newName,
          nameHint: _newNameHint,
          valueLabel: _newValue,
          valueHint: _newValueHint,
        ),
      ],
    );
  }
}

class _BodyTab extends StatelessWidget {
  const _BodyTab();

  static const String _description =
      '添加额外的请求体参数，这些参数会合并到API请求中。支持JSON格式、数字、布尔值和字符串。';
  static const String _configured = '已配置 0 个请求体参数';
  static const String _emptyHint = '暂无自定义请求体参数，点击下方添加按钮添加参数';
  static const String _newName = '新参数名称';
  static const String _newNameHint = '例如: custom_param';
  static const String _newValue = '新参数值';
  static const String _newValueHint = '例如: {"key": "value"} 或 123 或 true';

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _configured,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _emptyHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _AddRow(
          nameLabel: _newName,
          nameHint: _newNameHint,
          valueLabel: _newValue,
          valueHint: _newValueHint,
        ),
      ],
    );
  }
}

/// A disabled pill `Button` (`borderRadius: 999`) — the original quick-action
/// chips. They mutate config, so they carry no tap handler this milestone.
class _PillButton extends StatelessWidget {
  const _PillButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: null,
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        textStyle: const TextStyle(fontSize: 13),
      ),
      child: Text(label),
    );
  }
}

/// The "添加新…" row: two disabled inputs + a disabled 提交 button.
class _AddRow extends StatelessWidget {
  const _AddRow({
    required this.nameLabel,
    required this.nameHint,
    required this.valueLabel,
    required this.valueHint,
  });

  final String nameLabel;
  final String nameHint;
  final String valueLabel;
  final String valueHint;

  static const String _submitLabel = '提交';

  @override
  Widget build(BuildContext context) {
    return _OutlinedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ModelFormField(label: nameLabel, hint: nameHint, enabled: false),
          const SizedBox(height: 16),
          ModelFormField(label: valueLabel, hint: valueHint, enabled: false),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: null,
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
