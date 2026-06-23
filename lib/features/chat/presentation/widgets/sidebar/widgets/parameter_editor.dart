import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/chat/application/parameter_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/parameter_settings.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/parameter_metadata.dart';

// ─── Constants ───────────────────────────────────────────────────────────────

/// Category label map (web: `categoryNames`).
const _categoryNames = <String, String>{
  'basic': '基础',
  'advanced': '高级',
  'reasoning': '推理',
  'tools': '工具',
};

/// Provider display names (web: `providerNames`).
const _providerNames = <ProviderType, String>{
  ProviderType.openai: 'OpenAI',
  ProviderType.anthropic: 'Claude',
  ProviderType.gemini: 'Gemini',
  ProviderType.openaiCompatible: '兼容API',
};

// ─── Main widget ─────────────────────────────────────────────────────────────

/// 1:1 port of the web `ParameterEditor` component.
///
/// Renders: provider badge + param count → category-grouped bordered lists →
/// custom parameters collapsible section.
class ParameterEditor extends ConsumerStatefulWidget {
  const ParameterEditor({
    super.key,
    this.providerType,
    this.showCustomParameters = true,
  });

  final ProviderType? providerType;
  final bool showCustomParameters;

  @override
  ConsumerState<ParameterEditor> createState() => _ParameterEditorState();
}

class _ParameterEditorState extends ConsumerState<ParameterEditor> {
  @override
  Widget build(BuildContext context) {
    final ps = ref.watch(parameterSettingsControllerProvider);
    final ctrl = ref.read(parameterSettingsControllerProvider.notifier);

    // Resolve provider type: explicit prop → current model's provider → detect
    // from model id → fallback to openaiCompatible.  Mirrors web's
    // `detectProviderFromModel(modelId)` in DynamicContextSettings.
    final resolvedProvider = widget.providerType ?? _resolveProviderType(ref);

    final allParams = getParametersForProvider(resolvedProvider);

    // Group by category, filtering by showWhen.
    final grouped = <ParameterCategory, List<ParameterMeta>>{};
    for (final p in allParams) {
      if (!_passesShowWhen(p, ps)) continue;
      (grouped[p.category] ??= []).add(p);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Provider badge + param count (web: top of ParameterEditor).
        _ProviderBadgeRow(
          providerType: resolvedProvider,
          paramCount: allParams.length,
        ),
        const SizedBox(height: 8),

        // Category groups.
        for (final cat in ParameterCategory.values)
          if (grouped.containsKey(cat))
            _CategoryGroup(
              label: _categoryNames[cat.name] ?? cat.name,
              params: grouped[cat]!,
              ps: ps,
              ctrl: ctrl,
            ),

        // Empty state.
        if (allParams.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              '无可配置参数',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),

        // Custom parameters.
        if (widget.showCustomParameters) ...[
          const SizedBox(height: 8),
          _CustomParametersSection(ps: ps, ctrl: ctrl),
        ],
      ],
    );
  }

  bool _passesShowWhen(ParameterMeta meta, ParameterSettings ps) {
    final sw = meta.showWhen;
    if (sw == null) return true;
    final depEnabled = ps.isParameterEnabled(sw.key);
    if (!depEnabled) return false;
    final depValue = ps.getParameterValue(sw.key);
    return sw.values.contains(depValue);
  }

  /// Detect provider type from current model (same as web's
  /// `detectProviderFromModel(modelId)` called in DynamicContextSettings).
  static ProviderType _resolveProviderType(WidgetRef ref) {
    final current = ref.watch(appCurrentModelProvider).asData?.value;
    if (current == null) return ProviderType.openaiCompatible;
    // Prefer explicit providerType on the provider/model, fall back to
    // heuristic detection from model id.
    final explicit = current.model.providerType ?? current.provider.providerType;
    if (explicit != null && explicit.isNotEmpty) {
      return providerTypeFromProtocolKey(explicit);
    }
    return detectProviderFromModel(current.model.id);
  }
}

// ─── Provider badge row ──────────────────────────────────────────────────────

/// Web: `<Chip label={providerNames[providerType]} /> + "N 个可用参数"`.
class _ProviderBadgeRow extends StatelessWidget {
  const _ProviderBadgeRow({
    required this.providerType,
    required this.paramCount,
  });

  final ProviderType providerType;
  final int paramCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _providerNames[providerType] ?? '兼容API',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$paramCount 个可用参数',
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─── Category group (bordered box with dividers) ─────────────────────────────

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({
    required this.label,
    required this.params,
    required this.ps,
    required this.ctrl,
  });

  final String label;
  final List<ParameterMeta> params;
  final ParameterSettings ps;
  final ParameterSettingsController ctrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Category label (web: uppercase, small, px: 1.5).
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // Bordered box containing rows with dividers.
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                for (var i = 0; i < params.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: theme.dividerColor),
                  _ParameterRow(meta: params[i], ps: ps, ctrl: ctrl),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Parameter row (1:1 with web ParameterRow) ───────────────────────────────

class _ParameterRow extends StatefulWidget {
  const _ParameterRow({
    required this.meta,
    required this.ps,
    required this.ctrl,
  });

  final ParameterMeta meta;
  final ParameterSettings ps;
  final ParameterSettingsController ctrl;

  @override
  State<_ParameterRow> createState() => _ParameterRowState();
}

class _ParameterRowState extends State<_ParameterRow> {
  bool _showKey = false;

  ParameterMeta get meta => widget.meta;
  ParameterSettings get ps => widget.ps;
  ParameterSettingsController get ctrl => widget.ctrl;

  Object? get _currentValue =>
      ps.getParameterValue(meta.key) ?? meta.defaultValue;
  bool get _enabled => ps.isParameterEnabled(meta.key);

  /// Format display value (web: `formatValue`).
  String _formatValue(Object? val) {
    if (val == null) return '默认';
    if (val is bool) return val ? '开' : '关';
    if (val is num) {
      if (meta.unit == 'tokens' && val >= 1000) {
        return '${(val / 1000).toStringAsFixed(1)}K';
      }
      return val is int ? val.toString() : (val as double).toString();
    }
    if (meta.options != null) {
      for (final o in meta.options!) {
        if (o.value == val) return o.label;
      }
    }
    return val.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Web: switch type is special — single toggle for the value, no separate
    // enable switch.
    if (meta.inputType == ParameterInputType.switchToggle) {
      return _buildSwitchRow(theme);
    }
    return _buildStandardRow(theme);
  }

  /// Switch-type parameter (web: special case in ParameterRow).
  /// Row: CustomSwitch (value) + Label + Code icon + "开"/"关" text.
  Widget _buildSwitchRow(ThemeData theme) {
    final val = _currentValue == true;
    return Container(
      color: val
          ? theme.colorScheme.primary.withValues(alpha: 0.04)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          CustomSwitch(
            value: val,
            onChanged: (v) => ctrl.setParameterValue(meta.key, v),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    _showKey ? meta.key : meta.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: val
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _CodeIconButton(
                  showKey: _showKey,
                  apiKey: meta.key,
                  onTap: () => setState(() => _showKey = !_showKey),
                ),
              ],
            ),
          ),
          Text(
            val ? '开' : '关',
            style: TextStyle(
              fontSize: 11,
              fontWeight: val ? FontWeight.w500 : FontWeight.w400,
              color: val
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Standard parameter (slider / number / select / text).
  /// Row: CustomSwitch (enable) + Label + Code icon + Current value.
  /// When enabled: input control on new line below.
  Widget _buildStandardRow(ThemeData theme) {
    return Container(
      color: _enabled
          ? theme.colorScheme.primary.withValues(alpha: 0.04)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row.
          Row(
            children: [
              CustomSwitch(
                value: _enabled,
                onChanged: (v) => ctrl.setParameterEnabled(meta.key, v),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        _showKey ? meta.key : meta.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _enabled
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _CodeIconButton(
                      showKey: _showKey,
                      apiKey: meta.key,
                      onTap: () => setState(() => _showKey = !_showKey),
                    ),
                  ],
                ),
              ),
              // Always show current value.
              Text(
                _formatValue(_currentValue),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: _enabled ? FontWeight.w500 : FontWeight.w400,
                  color: _enabled
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          // Input control (shown when enabled).
          if (_enabled)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: _buildInput(),
            ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return switch (meta.inputType) {
      ParameterInputType.slider => _SliderInput(
          meta: meta,
          value: _toDouble(_currentValue) ?? _toDouble(meta.defaultValue) ?? 0,
          onChanged: (v) => ctrl.setParameterValue(meta.key, v),
        ),
      ParameterInputType.number => _NumberInput(
          meta: meta,
          value: _toInt(_currentValue),
          onChanged: (v) => ctrl.setParameterValue(meta.key, v),
        ),
      ParameterInputType.select => _SelectInput(
          meta: meta,
          value: _currentValue,
          onChanged: (v) => ctrl.setParameterValue(meta.key, v),
        ),
      ParameterInputType.text => _TextInput(
          meta: meta,
          value: _currentValue?.toString() ?? '',
          onChanged: (v) => ctrl.setParameterValue(meta.key, v),
        ),
      ParameterInputType.switchToggle => const SizedBox.shrink(),
    };
  }

  static double? _toDouble(Object? v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return null;
  }

  static int? _toInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }
}

// ─── Code icon button (per-row API key toggle) ──────────────────────────────

class _CodeIconButton extends StatelessWidget {
  const _CodeIconButton({
    required this.showKey,
    required this.apiKey,
    required this.onTap,
  });

  final bool showKey;
  final String apiKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: showKey ? '显示中文名' : 'API: $apiKey',
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(
            LucideIcons.code,
            size: 12,
            color: showKey
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

// ─── Input widgets ───────────────────────────────────────────────────────────

class _SliderInput extends StatelessWidget {
  const _SliderInput({
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

class _NumberInput extends StatefulWidget {
  const _NumberInput({
    required this.meta,
    required this.value,
    required this.onChanged,
  });

  final ParameterMeta meta;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  State<_NumberInput> createState() => _NumberInputState();
}

class _NumberInputState extends State<_NumberInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(_NumberInput old) {
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

class _SelectInput extends StatelessWidget {
  const _SelectInput({
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

    return SizedBox(
      height: 32,
      child: DropdownButtonFormField<Object>(
        initialValue: resolved,
        isExpanded: true,
        isDense: true,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        ),
        items: [
          for (final o in options)
            DropdownMenuItem(value: o.value, child: Text(o.label)),
        ],
        onChanged: (v) => onChanged(v),
      ),
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

class _TextInput extends StatefulWidget {
  const _TextInput({
    required this.meta,
    required this.value,
    required this.onChanged,
  });

  final ParameterMeta meta;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_TextInput old) {
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

// ─── Custom parameters section (1:1 with web) ───────────────────────────────

class _CustomParametersSection extends StatefulWidget {
  const _CustomParametersSection({required this.ps, required this.ctrl});

  final ParameterSettings ps;
  final ParameterSettingsController ctrl;

  @override
  State<_CustomParametersSection> createState() =>
      _CustomParametersSectionState();
}

class _CustomParametersSectionState extends State<_CustomParametersSection> {
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
                    onUpdate: (p) => widget.ctrl.updateCustomParameter(i, p),
                    onRemove: () => widget.ctrl.removeCustomParameter(i),
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
      color: theme.colorScheme.surfaceContainerLowest
          .withValues(alpha: 0.5),
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
    widget.ctrl.addCustomParameter({
      'name': key,
      'value': _inferValue(_newValueCtrl.text),
      'enabled': true,
    });
    _newKeyCtrl.clear();
    _newValueCtrl.clear();
    setState(() {});
  }

  static Object _inferValue(String raw) {
    if (raw.isEmpty) return '';
    if (raw == 'true') return true;
    if (raw == 'false') return false;
    final n = num.tryParse(raw);
    if (n != null) return n;
    return raw;
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
    if (value != null) p['value'] = _CustomParametersSectionState._inferValue(value);
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
