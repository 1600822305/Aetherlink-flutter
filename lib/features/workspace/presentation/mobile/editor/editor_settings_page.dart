// 编辑器设置页（编辑器头部三点菜单进入）：默认字体大小 / Tab 缩进宽度 /
// 软换行，全部持久化于 [editorSettingsProvider]，视觉对齐项目设置页。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/shared/widgets/editor_zoom_pill.dart';

/// 打开编辑器设置页。
Future<void> showEditorSettingsPage(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const EditorSettingsPage()),
  );
}

class EditorSettingsPage extends ConsumerWidget {
  const EditorSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(editorSettingsProvider);
    void update(EditorSettings next) =>
        ref.read(editorSettingsProvider.notifier).update(next);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        centerTitle: false,
        titleSpacing: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        leadingWidth: 44,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: const Icon(LucideIcons.arrowLeft, size: 24),
            color: theme.colorScheme.primary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: const Text('编辑器设置'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          12 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FontSizeRow(
                  value: settings.fontSize,
                  onChanged: (v) => update(settings.copyWith(fontSize: v)),
                ),
                Divider(height: 1, indent: 16, color: theme.dividerColor),
                _TabWidthRow(
                  value: settings.tabWidth,
                  onChanged: (v) => update(settings.copyWith(tabWidth: v)),
                ),
                Divider(height: 1, indent: 16, color: theme.dividerColor),
                SwitchListTile(
                  title: const Text('软换行'),
                  subtitle: const Text('编辑态长行自动换行（换行模式下无行号栏）'),
                  value: settings.softWrap,
                  onChanged: (v) => update(settings.copyWith(softWrap: v)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 默认字体大小：滑杆 + 当前值，新打开的文件按此初始化（双指缩放仍可
/// 临时调整单个文件）。
class _FontSizeRow extends StatelessWidget {
  const _FontSizeRow({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('默认字体大小', style: theme.textTheme.bodyLarge),
              ),
              Text(
                '${value.round()}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Text(
            '新打开文件的初始字号，双指缩放仍可临时调整',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Slider(
            value: value.clamp(kEditorMinFontSize, kEditorMaxFontSize),
            min: kEditorMinFontSize,
            max: kEditorMaxFontSize,
            divisions: (kEditorMaxFontSize - kEditorMinFontSize).round(),
            onChanged: (v) => onChanged(v.roundToDouble()),
          ),
        ],
      ),
    );
  }
}

/// Tab 缩进宽度：2 / 4 / 8 空格分段选择。
class _TabWidthRow extends StatelessWidget {
  const _TabWidthRow({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tab 缩进宽度', style: theme.textTheme.bodyLarge),
                Text(
                  'Tab 键 / 块缩进插入的空格数',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SegmentedButton<int>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
            segments: const [
              ButtonSegment(value: 2, label: Text('2')),
              ButtonSegment(value: 4, label: Text('4')),
              ButtonSegment(value: 8, label: Text('8')),
            ],
            selected: {value},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ],
      ),
    );
  }
}

/// 设置页同款卡片：圆角 16 + 描边 + 软阴影。
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  static const double _radius = 16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: theme.dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}
