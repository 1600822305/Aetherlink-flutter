// Sidebar layout dialog — compact layout with live preview.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/chat/application/sidebar_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/sidebar_settings.dart';

/// Opens the 侧边栏布局 dialog. Changes preview in real-time; 取消 reverts all.
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
  late final SettingsLayoutMode _originalSettingsLayout;
  late double _draft;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(sidebarSettingsControllerProvider);
    _originalWidth = settings.sidebarWidth;
    _originalMode = settings.sidebarDisplayMode;
    _originalSettingsLayout = settings.settingsLayoutMode;
    _draft = _originalWidth;
  }

  void _apply(double value, double maxWidth) {
    final clamped = value.clamp(kSidebarWidthMin, maxWidth).toDouble();
    setState(() => _draft = clamped);
    ref
        .read(sidebarSettingsControllerProvider.notifier)
        .previewSidebarWidth(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
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
    final settingsLayout = ref.watch(
      sidebarSettingsControllerProvider.select((s) => s.settingsLayoutMode),
    );

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      title: Text(
        '侧边栏布局',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 显示方式 ──────────────────────────────
          _SectionRow(
            label: '显示方式',
            hint: mode == SidebarDisplayMode.overlay ? '抽屉覆盖聊天页' : '抽屉推开聊天页',
            muted: muted,
          ),
          const SizedBox(height: 6),
          SegmentedButton<SidebarDisplayMode>(
            showSelectedIcon: false,
            style: _segmentedStyle(theme),
            segments: [
              for (final v in SidebarDisplayMode.values)
                ButtonSegment<SidebarDisplayMode>(
                  value: v,
                  label: Text(v.label, style: const TextStyle(fontSize: 13)),
                ),
            ],
            selected: {mode},
            onSelectionChanged: (sel) =>
                controller.setSidebarDisplayMode(sel.first),
          ),

          const SizedBox(height: 14),

          // ── 设置布局 ──────────────────────────────
          _SectionRow(
            label: '设置布局',
            hint: settingsLayout == SettingsLayoutMode.compact
                ? '手风琴展开收起'
                : '点击分组进入',
            muted: muted,
          ),
          const SizedBox(height: 6),
          SegmentedButton<SettingsLayoutMode>(
            showSelectedIcon: false,
            style: _segmentedStyle(theme),
            segments: [
              for (final v in SettingsLayoutMode.values)
                ButtonSegment<SettingsLayoutMode>(
                  value: v,
                  label: Text(v.label, style: const TextStyle(fontSize: 13)),
                ),
            ],
            selected: {settingsLayout},
            onSelectionChanged: (sel) =>
                controller.setSettingsLayoutMode(sel.first),
          ),

          const SizedBox(height: 14),

          // ── 宽度 ─────────────────────────────────
          _SectionRow(
            label: '宽度',
            hint: '${display.round()}px',
            muted: muted,
          ),
          SliderTheme(
            data: SliderThemeData(
              overlayShape: SliderComponentShape.noOverlay,
              trackHeight: 3,
            ),
            child: Slider(
              value: display,
              min: kSidebarWidthMin,
              max: maxWidth,
              onChanged: (v) => _apply(v, maxWidth),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final p in presets)
                _PresetChip(
                  label: '${p.round()}',
                  selected: display.round() == p.round(),
                  onTap: () => _apply(p, maxWidth),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            controller.previewSidebarWidth(_originalWidth);
            controller.setSidebarDisplayMode(_originalMode);
            controller.setSettingsLayoutMode(_originalSettingsLayout);
            Navigator.of(context).pop();
          },
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            controller.setSidebarWidth(display);
            Navigator.of(context).pop();
          },
          child: const Text('保存'),
        ),
      ],
    );
  }

  ButtonStyle _segmentedStyle(ThemeData theme) {
    return ButtonStyle(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }
}

/// Section header: label on the left, hint text on the right.
class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.label,
    required this.hint,
    required this.muted,
  });

  final String label;
  final String hint;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const Spacer(),
        Text(
          hint,
          style: TextStyle(fontSize: 11, color: muted),
        ),
      ],
    );
  }
}

/// Compact preset chip (smaller than ChoiceChip).
class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(6),
          border: selected
              ? Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.4))
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
