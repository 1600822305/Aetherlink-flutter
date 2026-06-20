// Sidebar layout dialog (display mode + width with live preview).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/chat/application/sidebar_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/sidebar_settings.dart';

/// Opens the 侧边栏布局 dialog (显示方式 + 宽度). 显示方式切换即时预览（且持久化）；
/// 宽度拖动实时预览，保存提交、取消恢复原宽度与原显示方式。
Future<void> showSidebarLayoutDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _SidebarLayoutDialog(),
  );
}

class _SidebarLayoutDialog extends ConsumerStatefulWidget {
  const _SidebarLayoutDialog();

  @override
  ConsumerState<_SidebarLayoutDialog> createState() =>
      _SidebarLayoutDialogState();
}

class _SidebarLayoutDialogState extends ConsumerState<_SidebarLayoutDialog> {
  late final double _originalWidth;
  late final SidebarDisplayMode _originalMode;
  late double _draft;
  final TextEditingController _field = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = ref.read(sidebarSettingsControllerProvider);
    _originalWidth = settings.sidebarWidth;
    _originalMode = settings.sidebarDisplayMode;
    _draft = _originalWidth;
    _field.text = _draft.round().toString();
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _apply(double value, double maxWidth) {
    final clamped = value.clamp(kSidebarWidthMin, maxWidth).toDouble();
    setState(() => _draft = clamped);
    _field.text = clamped.round().toString();
    ref
        .read(sidebarSettingsControllerProvider.notifier)
        .previewSidebarWidth(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxWidth = safeMaxSidebarWidth(MediaQuery.sizeOf(context).width);
    final display = _draft.clamp(kSidebarWidthMin, maxWidth).toDouble();
    final presets = [
      for (final p in kSidebarWidthPresets)
        if (p <= maxWidth) p,
    ];
    final controller = ref.read(sidebarSettingsControllerProvider.notifier);
    final mode = ref.watch(
      sidebarSettingsControllerProvider.select((s) => s.sidebarDisplayMode),
    );
    return AlertDialog(
      // M2 默认对话框背景写死为白/grey[800]、不跟随主题，故显式取 surface。
      backgroundColor: theme.colorScheme.surface,
      title: const Text('侧边栏布局'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DialogSectionLabel(text: '显示方式', color: theme.colorScheme.onSurface),
          const SizedBox(height: 8),
          SegmentedButton<SidebarDisplayMode>(
            showSelectedIcon: false,
            segments: [
              for (final v in SidebarDisplayMode.values)
                ButtonSegment<SidebarDisplayMode>(
                  value: v,
                  label: Text(v.label),
                ),
            ],
            selected: {mode},
            // 即时切换（持久化），用户立刻看到覆盖/推开效果；取消时再恢复原值。
            onSelectionChanged: (sel) =>
                controller.setSidebarDisplayMode(sel.first),
          ),
          const SizedBox(height: 8),
          Text(
            '覆盖：抽屉滑入盖在聊天页上；推开：抽屉滑入时把聊天页向右推开',
            style: TextStyle(
              fontSize: 12,
              height: 1.3,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _DialogSectionLabel(text: '宽度', color: theme.colorScheme.onSurface),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '当前: ${display.round()}px',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '${kSidebarWidthMin.round()} – ${maxWidth.round()}px',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Slider(
            value: display,
            min: kSidebarWidthMin,
            max: maxWidth,
            onChanged: (v) => _apply(v, maxWidth),
          ),
          TextField(
            controller: _field,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              suffixText: 'px',
              labelText: '自定义宽度',
            ),
            onSubmitted: (raw) {
              final parsed = double.tryParse(raw.trim());
              if (parsed != null) _apply(parsed, maxWidth);
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final p in presets)
                ChoiceChip(
                  label: Text('${p.round()}'),
                  selected: display.round() == p.round(),
                  onSelected: (_) => _apply(p, maxWidth),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            // 取消恢复原宽度（预览未持久化）与原显示方式。
            controller.previewSidebarWidth(_originalWidth);
            controller.setSidebarDisplayMode(_originalMode);
            Navigator.of(context).pop();
          },
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            controller.setSidebarWidth(display);
            Navigator.of(context).pop();
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

/// 小节标题（侧边栏布局对话框内的「显示方式 / 宽度」分组标签）。
class _DialogSectionLabel extends StatelessWidget {
  const _DialogSectionLabel({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
    );
  }
}
