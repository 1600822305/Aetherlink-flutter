import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/chat/application/parameter_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/parameter_settings.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/parameter_metadata.dart';
import 'package:aetherlink_flutter/shared/domain/reasoning_model_detection.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/widgets/parameter_editor/custom_parameters_section.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/widgets/parameter_editor/param_inputs.dart';

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

// ─── Delegate interface ──────────────────────────────────────────────────────

/// Abstract interface for parameter mutation. Allows `ParameterEditor` to work
/// with both the global [ParameterSettingsController] and local per-assistant
/// state (e.g. in 编辑助手 Dialog).
abstract class ParameterDelegate {
  void setParameterValue(String key, Object? value);
  void setParameterEnabled(String key, bool enabled);
  void addCustomParameter(Map<String, dynamic> param);
  void removeCustomParameter(int index);
  void updateCustomParameter(int index, Map<String, dynamic> param);
}

// ─── Main widget ─────────────────────────────────────────────────────────────

/// 1:1 port of the web `ParameterEditor` component.
///
/// Renders: provider badge + param count → category-grouped bordered lists →
/// custom parameters collapsible section.
///
/// When [settings] and [delegate] are provided, the editor operates on
/// external state (e.g. per-assistant parameters) instead of the global
/// [parameterSettingsControllerProvider].
class ParameterEditor extends ConsumerStatefulWidget {
  const ParameterEditor({
    super.key,
    this.providerType,
    this.showCustomParameters = true,
    this.settings,
    this.delegate,
  });

  final ProviderType? providerType;
  final bool showCustomParameters;

  /// When non-null, the editor uses this state instead of watching the global
  /// provider. Must be paired with [delegate].
  final ParameterSettings? settings;

  /// Mutation callbacks for external state. Required when [settings] is set.
  final ParameterDelegate? delegate;

  @override
  ConsumerState<ParameterEditor> createState() => _ParameterEditorState();
}

class _ParameterEditorState extends ConsumerState<ParameterEditor> {
  @override
  Widget build(BuildContext context) {
    final ParameterSettings ps;
    final ParameterDelegate ctrl;
    if (widget.settings != null && widget.delegate != null) {
      ps = widget.settings!;
      ctrl = widget.delegate!;
    } else {
      ps = ref.watch(parameterSettingsControllerProvider);
      ctrl = ref.read(parameterSettingsControllerProvider.notifier);
    }

    // Resolve parameter scope via canonical priority chain
    // (see docs/PARAMETER_SCOPE_DESIGN.md).
    final resolvedProvider = widget.providerType ?? _resolveProviderType(ref);
    final currentModelId = _resolveModelId(ref);
    final effectiveProtocol = _resolveEffectiveProtocol(ref);

    // Determine if there's a protocol mismatch (e.g. Anthropic params shown
    // but protocol is openaiCompatible because the user is using a third-party
    // API that proxies Claude via OpenAI-compatible endpoint).
    final hasMismatch =
        resolvedProvider != effectiveProtocol &&
        resolvedProvider != ProviderType.openaiCompatible;

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

        // Protocol mismatch hint.
        if (hasMismatch)
          _ProtocolMismatchHint(
            resolvedProvider: resolvedProvider,
            effectiveProtocol: effectiveProtocol,
          ),

        // Category groups.
        for (final cat in ParameterCategory.values)
          if (grouped.containsKey(cat))
            _CategoryGroup(
              label: _categoryNames[cat.name] ?? cat.name,
              params: grouped[cat]!,
              ps: ps,
              delegate: ctrl,
              currentModelId: currentModelId,
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
          CustomParametersSection(ps: ps, delegate: ctrl),
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

  /// Resolve the parameter display scope for the current model.
  /// Delegates to the canonical [resolveParameterScope] function.
  static ProviderType _resolveProviderType(WidgetRef ref) {
    final current = ref.watch(appCurrentModelProvider).asData?.value;
    if (current == null) return ProviderType.openaiCompatible;
    return resolveParameterScope(
      modelParameterScope: current.model.parameterScope,
      providerParameterScope: current.provider.parameterScope,
      modelId: current.model.id,
      modelProviderType: current.model.providerType,
      providerProviderType: current.provider.providerType,
    );
  }

  /// Get the current model ID for dynamic option resolution.
  static String? _resolveModelId(WidgetRef ref) {
    final current = ref.watch(appCurrentModelProvider).asData?.value;
    return current?.model.id;
  }

  /// Resolve the effective API protocol (i.e. which Adapter is used to send
  /// the request). This is determined by `providerType` on the model or
  /// provider — NOT by parameterScope or model-ID heuristics.
  static ProviderType _resolveEffectiveProtocol(WidgetRef ref) {
    final current = ref.watch(appCurrentModelProvider).asData?.value;
    if (current == null) return ProviderType.openaiCompatible;
    final explicit =
        current.model.providerType ?? current.provider.providerType;
    if (explicit != null && explicit.isNotEmpty) {
      return providerTypeFromProtocolKey(explicit);
    }
    return ProviderType.openaiCompatible;
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

// ─── Protocol mismatch hint ──────────────────────────────────────────────────

/// Warning banner shown when the resolved parameter scope (what params we show)
/// differs from the effective API protocol (how params are sent). For example,
/// using Claude via an OpenAI-compatible third-party API means Anthropic-specific
/// params (cacheControl, etc.) may not be delivered correctly.
class _ProtocolMismatchHint extends StatelessWidget {
  const _ProtocolMismatchHint({
    required this.resolvedProvider,
    required this.effectiveProtocol,
  });

  final ProviderType resolvedProvider;
  final ProviderType effectiveProtocol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scopeName = _providerNames[resolvedProvider] ?? resolvedProvider.name;
    final protocolName =
        _providerNames[effectiveProtocol] ?? effectiveProtocol.name;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.triangleAlert,
            size: 14,
            color: theme.colorScheme.tertiary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '当前按 $scopeName 参数范围显示，但 API 协议为 $protocolName。'
              '部分专属参数可能无法通过当前协议正确传递。',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Category group (bordered box with dividers) ─────────────────────────────

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({
    required this.label,
    required this.params,
    required this.ps,
    required this.delegate,
    this.currentModelId,
  });

  final String label;
  final List<ParameterMeta> params;
  final ParameterSettings ps;
  final ParameterDelegate delegate;
  final String? currentModelId;

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
                  _ParameterRow(
                    meta: params[i],
                    ps: ps,
                    delegate: delegate,
                    currentModelId: currentModelId,
                  ),
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
    required this.delegate,
    this.currentModelId,
  });

  final ParameterMeta meta;
  final ParameterSettings ps;
  final ParameterDelegate delegate;
  final String? currentModelId;

  @override
  State<_ParameterRow> createState() => _ParameterRowState();
}

class _ParameterRowState extends State<_ParameterRow> {
  bool _showKey = false;

  ParameterMeta get meta => widget.meta;
  ParameterSettings get ps => widget.ps;
  ParameterDelegate get ctrl => widget.delegate;

  Object? get _currentValue =>
      ps.getParameterValue(meta.key) ?? meta.defaultValue;
  bool get _enabled => ps.isParameterEnabled(meta.key);

  /// For `reasoningEffort`, dynamically resolve options based on current model.
  /// Web: `getReasoningEffortOptions(modelId)` in ParameterEditor.
  ParameterMeta get _resolvedMeta {
    if (meta.key == 'reasoningEffort') {
      final dynamicOptions = getReasoningEffortOptions(widget.currentModelId);
      return meta.copyWith(options: dynamicOptions);
    }
    return meta;
  }

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
    final resolved = _resolvedMeta;
    if (resolved.options != null) {
      for (final o in resolved.options!) {
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
      ParameterInputType.slider => SliderInput(
        meta: meta,
        value: _toDouble(_currentValue) ?? _toDouble(meta.defaultValue) ?? 0,
        onChanged: (v) => ctrl.setParameterValue(meta.key, v),
      ),
      ParameterInputType.number => NumberInput(
        meta: meta,
        value: _toInt(_currentValue),
        onChanged: (v) => ctrl.setParameterValue(meta.key, v),
      ),
      ParameterInputType.select => SelectInput(
        meta: _resolvedMeta,
        value: _currentValue,
        onChanged: (v) => ctrl.setParameterValue(meta.key, v),
      ),
      ParameterInputType.text => TextInput(
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
                : Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
