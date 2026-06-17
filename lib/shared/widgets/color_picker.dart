import 'package:flutter/material.dart';

/// Parses a `#RRGGBB` (or `#AARRGGBB`) string into a [Color], returning null for
/// empty or malformed input so callers can fall back to a theme default.
Color? colorFromHex(String hex) {
  var value = hex.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('#')) value = value.substring(1);
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return null;
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return null;
  return Color(parsed);
}

/// Formats a [Color] back into a lowercase `#RRGGBB` string (the form the web
/// `customBubbleColors` stored).
String hexFromColor(Color color) {
  int channel(double v) => (v * 255.0).round().clamp(0, 255);
  final r = channel(color.r).toRadixString(16).padLeft(2, '0');
  final g = channel(color.g).toRadixString(16).padLeft(2, '0');
  final b = channel(color.b).toRadixString(16).padLeft(2, '0');
  return '#$r$g$b';
}

/// The preset palette from the original `ColorPicker.tsx` `DEFAULT_PRESET_COLORS`
/// (blues, greens, oranges, purples, greys and a special row).
const List<String> kDefaultPresetColors = [
  '#1976d2', '#2196f3', '#03a9f4', '#00bcd4', //
  '#4caf50', '#8bc34a', '#cddc39', '#ffeb3b',
  '#ff9800', '#ff5722', '#f44336', '#e91e63',
  '#9c27b0', '#673ab7', '#3f51b5', '#2196f3',
  '#9e9e9e', '#607d8b', '#795548', '#424242',
  '#000000', '#ffffff', '#f5f5f5', '#e0e0e0',
];

/// A compact color picker, a port of the web `ColorPicker.tsx`: a swatch button
/// that opens a dialog with the preset palette and a hex input.
///
/// [value] is the current `#RRGGBB` color (may be empty); [onChanged] receives
/// the new hex string. Picking a preset applies and closes; editing the hex
/// applies live as soon as it is a valid 6-digit color.
class ColorPicker extends StatelessWidget {
  const ColorPicker({
    required this.value,
    required this.onChanged,
    this.size = 32,
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final double size;

  Future<void> _open(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ColorPickerDialog(value: value, onChanged: onChanged),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = colorFromHex(value);
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor, width: 2),
        ),
        child: color == null
            ? Icon(
                Icons.palette_outlined,
                size: size * 0.5,
                color: theme.colorScheme.onSurfaceVariant,
              )
            : null,
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late final TextEditingController _hexController;
  late String _current;

  @override
  void initState() {
    super.initState();
    _current = widget.value;
    _hexController = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _apply(String hex) {
    setState(() => _current = hex);
    widget.onChanged(hex);
  }

  void _onHexChanged(String text) {
    final normalized = text.startsWith('#') || text.isEmpty ? text : '#$text';
    if (RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(normalized)) {
      _apply(normalized.toLowerCase());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = colorFromHex(_current);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('选择颜色'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '预设颜色',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in kDefaultPresetColors)
                  _PresetSwatch(
                    color: colorFromHex(preset)!,
                    selected: _current.toLowerCase() == preset.toLowerCase(),
                    onTap: () {
                      widget.onChanged(preset);
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '自定义颜色',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: preview ?? theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.dividerColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _hexController,
                    onChanged: _onHexChanged,
                    maxLength: 7,
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '#000000',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('完成'),
        ),
      ],
    );
  }
}

class _PresetSwatch extends StatelessWidget {
  const _PresetSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.dividerColor,
            width: 2,
          ),
        ),
      ),
    );
  }
}
