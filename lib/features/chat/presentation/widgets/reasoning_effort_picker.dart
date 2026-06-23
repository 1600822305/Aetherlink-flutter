import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/chat/application/parameter_settings_controller.dart';
import 'package:aetherlink_flutter/shared/domain/parameter_metadata.dart';
import 'package:aetherlink_flutter/shared/domain/reasoning_model_detection.dart';

/// Shows the reasoning-effort picker bottom sheet and writes the selected level
/// back to [parameterSettingsControllerProvider].
void showReasoningEffortPicker(BuildContext context, WidgetRef ref) {
  final params = ref.read(parameterSettingsControllerProvider);
  final currentValue =
      (params.getParameterValue('reasoningEffort') as String?) ?? 'medium';
  final modelId = ref.read(appCurrentModelProvider).asData?.value?.model.id;
  final options = getReasoningEffortOptions(modelId);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _ReasoningEffortPicker(
      currentValue: currentValue,
      options: options,
      onChanged: (value) {
        final notifier =
            ref.read(parameterSettingsControllerProvider.notifier);
        notifier.setParameterValue('reasoningEffort', value);
        notifier.setParameterEnabled(
          'reasoningEffort',
          value != 'none' && value != 'off',
        );
      },
    ),
  );
}

/// Whether reasoning effort is currently active (enabled and not off/none).
bool isReasoningEffortActive(WidgetRef ref) {
  final params = ref.read(parameterSettingsControllerProvider);
  final value =
      (params.getParameterValue('reasoningEffort') as String?) ?? 'medium';
  final enabled = params.isParameterEnabled('reasoningEffort');
  return enabled && value != 'none' && value != 'off';
}

// ─── Bottom-sheet picker ─────────────────────────────────────────────────────

class _ReasoningEffortPicker extends StatefulWidget {
  const _ReasoningEffortPicker({
    required this.currentValue,
    required this.options,
    required this.onChanged,
  });

  final String currentValue;
  final List<SelectOption> options;
  final ValueChanged<String> onChanged;

  @override
  State<_ReasoningEffortPicker> createState() => _ReasoningEffortPickerState();
}

class _ReasoningEffortPickerState extends State<_ReasoningEffortPicker> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _indexOfValue(widget.currentValue);
  }

  int _indexOfValue(Object value) {
    final v = value.toString();
    for (var i = 0; i < widget.options.length; i++) {
      if (widget.options[i].value == v) return i;
    }
    return 0;
  }

  void _select(int index) {
    setState(() => _selectedIndex = index);
    widget.onChanged(widget.options[index].value.toString());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = widget.options;
    final selected = options[_selectedIndex];
    final maxIndex = options.length - 1;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text('思考程度', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '调节模型的推理深度，更高程度会消耗更多 Token',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Current level icon + label
            _ReasoningIcon(
              value: selected.value.toString(),
              color: (selected.value == 'none' || selected.value == 'off')
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.primary,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              selected.label,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),

            // Slider
            if (maxIndex > 0)
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 10),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 18),
                  tickMarkShape: const RoundSliderTickMarkShape(
                    tickMarkRadius: 3,
                  ),
                  activeTickMarkColor: theme.colorScheme.primary,
                  inactiveTickMarkColor:
                      theme.colorScheme.outlineVariant,
                ),
                child: Slider(
                  value: _selectedIndex.toDouble(),
                  min: 0,
                  max: maxIndex.toDouble(),
                  divisions: maxIndex,
                  onChanged: (v) => _select(v.round()),
                ),
              ),
            const SizedBox(height: 12),

            // Scale row
            _ReasoningScale(
              options: options,
              selectedIndex: _selectedIndex,
              onSelect: _select,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Scale (clickable level indicators) ──────────────────────────────────────

class _ReasoningScale extends StatelessWidget {
  const _ReasoningScale({
    required this.options,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<SelectOption> options;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        for (var i = 0; i < options.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              behavior: HitTestBehavior.opaque,
              child: _ScaleTick(
                label: options[i].label,
                selected: i == selectedIndex,
                theme: theme,
              ),
            ),
          ),
      ],
    );
  }
}

class _ScaleTick extends StatelessWidget {
  const _ScaleTick({
    required this.label,
    required this.selected,
    required this.theme,
  });

  final String label;
  final bool selected;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant;
    final textColor = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? color : Colors.transparent,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: selected ? 20 : 16,
            height: selected ? 6 : 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontSize: 10,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Icon helper ─────────────────────────────────────────────────────────────

class _ReasoningIcon extends StatelessWidget {
  const _ReasoningIcon({
    required this.value,
    required this.color,
    this.size = 24,
  });

  final String value;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(_iconFor(value), size: size, color: color);
  }

  static IconData _iconFor(String value) {
    switch (value) {
      case 'none':
      case 'off':
        return LucideIcons.lightbulbOff;
      case 'auto':
      case 'default':
        return LucideIcons.lightbulb;
      case 'minimal':
      case 'low':
        return LucideIcons.brain;
      case 'medium':
        return LucideIcons.brainCircuit;
      case 'high':
      case 'xhigh':
        return LucideIcons.sparkles;
      default:
        return LucideIcons.lightbulb;
    }
  }
}
