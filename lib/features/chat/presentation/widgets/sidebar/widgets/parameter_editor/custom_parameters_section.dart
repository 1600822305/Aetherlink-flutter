import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/parameter_settings.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/widgets/parameter_editor/parameter_editor.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

/// Parse a raw text value into a typed custom parameter value
/// (bool / num / string).
Object _inferValue(String raw) {
  if (raw.isEmpty) return '';
  if (raw == 'true') return true;
  if (raw == 'false') return false;
  final n = num.tryParse(raw);
  if (n != null) return n;
  return raw;
}

// ─── Custom parameters section (1:1 with web) ───────────────────────────────

class CustomParametersSection extends StatefulWidget {
  const CustomParametersSection({
    super.key,
    required this.ps,
    required this.delegate,
  });

  final ParameterSettings ps;
  final ParameterDelegate delegate;

  @override
  State<CustomParametersSection> createState() =>
      _CustomParametersSectionState();
}

class _CustomParametersSectionState extends State<CustomParametersSection> {
  bool _expanded = false;
  final _newKeyCtrl = TextEditingController();
  final _newValueCtrl = TextEditingController();

  @override
  void dispose() {
    _newKeyCtrl.dispose();
    _newValueCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final params = widget.ps.customParameters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Collapsible header (web: clickable row + count chip + chevron).
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
            child: Row(
              children: [
                Text(
                  '自定义参数',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${params.length}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                const Spacer(),
                Icon(
                  _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),

        // Collapsible content.
        if (_expanded)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                // Existing custom parameters.
                for (var i = 0; i < params.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: theme.dividerColor),
                  _CustomParameterRow(
                    param: params[i],
                    onUpdate: (p) =>
                        widget.delegate.updateCustomParameter(i, p),
                    onRemove: () => widget.delegate.removeCustomParameter(i),
                  ),
                ],
                if (params.isNotEmpty)
                  Divider(height: 1, color: theme.dividerColor),
                // Add new parameter area (inline, like web).
                _buildAddArea(theme),
              ],
            ),
          ),
      ],
    );
  }

  /// Inline add-parameter area (web: key field row + value field + "添加" button).
  Widget _buildAddArea(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.5),
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          // Row 1: key field.
          SizedBox(
            height: 30,
            child: TextField(
              controller: _newKeyCtrl,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                hintText: '参数名 (如: custom_param)',
                hintStyle: const TextStyle(fontSize: 11),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 4),
          // Row 2: value field + "添加" button.
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _newValueCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      hintText: '值 (支持字符串、数字、JSON)',
                      hintStyle: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 30,
                child: OutlinedButton.icon(
                  onPressed: _newKeyCtrl.text.trim().isEmpty
                      ? null
                      : _addParameter,
                  icon: const Icon(LucideIcons.plus, size: 14),
                  label: const Text('添加', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: Size.zero,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addParameter() {
    final key = _newKeyCtrl.text.trim();
    if (key.isEmpty) return;
    widget.delegate.addCustomParameter({
      'name': key,
      'value': _inferValue(_newValueCtrl.text),
      'enabled': true,
    });
    _newKeyCtrl.clear();
    _newValueCtrl.clear();
    setState(() {});
  }
}

/// A single custom parameter row (web: switch + editable key + delete, value
/// below).
class _CustomParameterRow extends StatefulWidget {
  const _CustomParameterRow({
    required this.param,
    required this.onUpdate,
    required this.onRemove,
  });

  final Map<String, dynamic> param;
  final ValueChanged<Map<String, dynamic>> onUpdate;
  final VoidCallback onRemove;

  @override
  State<_CustomParameterRow> createState() => _CustomParameterRowState();
}

class _CustomParameterRowState extends State<_CustomParameterRow> {
  late TextEditingController _keyCtrl;
  late TextEditingController _valueCtrl;

  @override
  void initState() {
    super.initState();
    _keyCtrl = TextEditingController(
      text: widget.param['name']?.toString() ?? '',
    );
    _valueCtrl = TextEditingController(
      text: widget.param['value']?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(_CustomParameterRow old) {
    super.didUpdateWidget(old);
    final newKey = widget.param['name']?.toString() ?? '';
    final newVal = widget.param['value']?.toString() ?? '';
    if (_keyCtrl.text != newKey) _keyCtrl.text = newKey;
    if (_valueCtrl.text != newVal) _valueCtrl.text = newVal;
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  bool get _enabled => widget.param['enabled'] == true;

  void _update({String? key, String? value, bool? enabled}) {
    final p = Map<String, dynamic>.of(widget.param);
    if (key != null) p['name'] = key;
    if (value != null) {
      p['value'] = _inferValue(value);
    }
    if (enabled != null) p['enabled'] = enabled;
    widget.onUpdate(p);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: _enabled
          ? theme.colorScheme.primary.withValues(alpha: 0.04)
          : Colors.transparent,
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          // Row 1: switch + key field + delete button.
          Row(
            children: [
              CustomSwitch(
                value: _enabled,
                onChanged: (v) => _update(enabled: v),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: SizedBox(
                  height: 28,
                  child: TextField(
                    controller: _keyCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      hintText: '参数名 (如: custom_param)',
                      hintStyle: const TextStyle(fontSize: 11),
                    ),
                    onChanged: (v) => _update(key: v),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: widget.onRemove,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    LucideIcons.trash2,
                    size: 14,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
          // Row 2: value field (indented under switch).
          Padding(
            padding: const EdgeInsets.only(left: 40, top: 4),
            child: SizedBox(
              height: 28,
              child: TextField(
                controller: _valueCtrl,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  hintText: '值 (支持字符串、数字、JSON)',
                  hintStyle: const TextStyle(fontSize: 11),
                ),
                onChanged: (v) => _update(value: v),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
