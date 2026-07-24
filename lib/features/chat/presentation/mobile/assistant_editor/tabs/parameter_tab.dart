import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/parameter_settings.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/widgets/parameter_editor/parameter_editor.dart';

// ─── Parameter tab ─────────────────────────────────────────────────────────

/// Wraps [ParameterEditor] in a scrollable tab body, operating on the
/// local per-assistant [ParameterSettings] instead of the global provider.
class ParameterTab extends StatelessWidget {
  const ParameterTab({
    super.key,
    required this.settings,
    required this.delegate,
  });

  final ParameterSettings settings;
  final ParameterDelegate delegate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [ParameterEditor(settings: settings, delegate: delegate)],
    );
  }
}

/// Local [ParameterDelegate] that mutates an in-memory [ParameterSettings] and
/// calls back with the new value so the dialog's `setState` can rebuild the
/// parameter tab.
class AssistantParamDelegate implements ParameterDelegate {
  AssistantParamDelegate(this._onChanged);

  final ValueChanged<ParameterSettings> _onChanged;
  ParameterSettings _ps = const ParameterSettings();

  /// Must be called once from the dialog state to sync the initial value.
  void attach(ParameterSettings initial) => _ps = initial;

  @override
  void setParameterValue(String key, Object? value) {
    final next = Map<String, dynamic>.of(_ps.values);
    next[key] = value;
    _ps = _ps.copyWith(values: next);
    _onChanged(_ps);
  }

  @override
  void setParameterEnabled(String key, bool enabled) {
    final next = Map<String, bool>.of(_ps.enabledFlags);
    next[key] = enabled;
    _ps = _ps.copyWith(enabledFlags: next);
    _onChanged(_ps);
  }

  @override
  void addCustomParameter(Map<String, dynamic> param) {
    final next = List<Map<String, dynamic>>.of(_ps.customParameters)
      ..add(param);
    _ps = _ps.copyWith(customParameters: next);
    _onChanged(_ps);
  }

  @override
  void removeCustomParameter(int index) {
    final next = List<Map<String, dynamic>>.of(_ps.customParameters);
    if (index >= 0 && index < next.length) {
      next.removeAt(index);
      _ps = _ps.copyWith(customParameters: next);
      _onChanged(_ps);
    }
  }

  @override
  void updateCustomParameter(int index, Map<String, dynamic> param) {
    final next = List<Map<String, dynamic>>.of(_ps.customParameters);
    if (index >= 0 && index < next.length) {
      next[index] = param;
      _ps = _ps.copyWith(customParameters: next);
      _onChanged(_ps);
    }
  }
}
