import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:aetherlink_flutter/shared/domain/parameter_metadata.dart';
import 'package:aetherlink_flutter/shared/widgets/app_select_field.dart';

/// Slider input for range parameters (temperature, topP, …).
class SliderInput extends StatelessWidget {
  const SliderInput({
    super.key,
    required this.meta,
    required this.value,
    required this.onChanged,
  });

  final ParameterMeta meta;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final min = meta.rangeMin ?? 0;
    final max = meta.rangeMax ?? 1;
    final step = meta.rangeStep ?? 0.1;
    final divisions = ((max - min) / step).round().clamp(1, 10000);
    final clamped = value.clamp(min, max);

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      child: Slider(
        value: clamped,
        min: min,
        max: max,
        divisions: divisions,
        label: _formatSliderLabel(clamped),
        onChanged: onChanged,
      ),
    );
  }

  String _formatSliderLabel(double v) {
    final step = meta.rangeStep ?? 0.1;
    if (step >= 1) return v.toInt().toString();
    if (step < 0.01) return v.toStringAsFixed(3);
    if (step < 0.1) return v.toStringAsFixed(2);
    return v.toStringAsFixed(1);
  }
}

/// Integer input for count parameters (maxTokens, …).
class NumberInput extends StatefulWidget {
  const NumberInput({
    super.key,
    required this.meta,
    required this.value,
    required this.onChanged,
  });

  final ParameterMeta meta;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  State<NumberInput> createState() => _NumberInputState();
}

class _NumberInputState extends State<NumberInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(NumberInput old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _controller.text = widget.value?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        ),
        onChanged: (v) => widget.onChanged(int.tryParse(v)),
      ),
    );
  }
}

/// Dropdown input for enum parameters (reasoningEffort, …).
class SelectInput extends StatelessWidget {
  const SelectInput({
    super.key,
    required this.meta,
    required this.value,
    required this.onChanged,
  });

  final ParameterMeta meta;
  final Object? value;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = meta.options ?? [];
    if (options.isEmpty) return const SizedBox.shrink();

    // Web: fall back when current value is not in options.
    final resolved = _resolveValue(value, options);

    return AppSelectField<Object?>(
      value: resolved,
      borderRadius: 4,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      textStyle: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      options: [
        for (final o in options)
          AppSelectOption<Object?>(value: o.value, label: o.label),
      ],
      onChanged: onChanged,
    );
  }

  Object? _resolveValue(Object? v, List<SelectOption> opts) {
    for (final o in opts) {
      if (o.value == v) return v;
      if (o.value.toString() == v.toString()) return o.value;
    }
    return opts.isNotEmpty ? opts.first.value : null;
  }
}

/// Free-form text input.
class TextInput extends StatefulWidget {
  const TextInput({
    super.key,
    required this.meta,
    required this.value,
    required this.onChanged,
  });

  final ParameterMeta meta;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<TextInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(TextInput old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: TextField(
        controller: _controller,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          hintText: '输入...',
          hintStyle: const TextStyle(fontSize: 11),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}
