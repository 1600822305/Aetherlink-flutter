import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/chat/application/parameter_settings_controller.dart';

/// The user-enabled request parameter fields (参数设置面板), each `null` when
/// its toggle is off so the gateway omits it from the request.
typedef LlmParameterFields = ({
  double? temperature,
  double? topP,
  int? topK,
  double? frequencyPenalty,
  double? presencePenalty,
  int? seed,
  List<String>? stopSequences,
  String? responseFormat,
  bool? parallelToolCalls,
  bool? logprobs,
  String? user,
  String? reasoningEffort,
  int? thinkingBudget,
  bool? includeThoughts,
  bool? cacheControl,
  String? structuredOutputMode,
  bool? webSearchEnabled,
  bool? codeExecutionEnabled,
  bool? useSearchGrounding,
  String? safetyLevel,
  bool streamOutput,
  Map<String, dynamic>? customParameters,
});

/// Reads the 参数设置 panel into the request parameter fields: only enabled
/// parameters carry a value, stop sequences are split from their
/// comma-separated storage form, and 自定义参数 are folded into one map.
LlmParameterFields readLlmParameterFields(Ref ref) {
  final ps = ref.read(parameterSettingsControllerProvider);

  T? enabled<T>(String key) {
    if (!ps.isParameterEnabled(key)) return null;
    final v = ps.getParameterValue(key);
    if (v is T) return v;
    return null;
  }

  int? enabledInt(String key) {
    if (!ps.isParameterEnabled(key)) return null;
    final v = ps.getParameterValue(key);
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  double? enabledDouble(String key) {
    if (!ps.isParameterEnabled(key)) return null;
    final v = ps.getParameterValue(key);
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return null;
  }

  // Stop sequences: stored as comma-separated string → List<String>
  List<String>? stops;
  final rawStops = enabled<String>('stopSequences');
  if (rawStops != null && rawStops.isNotEmpty) {
    stops = rawStops
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (stops.isEmpty) stops = null;
  }

  // Custom parameters
  Map<String, dynamic>? custom;
  if (ps.customParameters.isNotEmpty) {
    custom = <String, dynamic>{};
    for (final cp in ps.customParameters) {
      final name = cp['name'] as String?;
      if (name != null && name.isNotEmpty) {
        custom[name] = cp['value'];
      }
    }
    if (custom.isEmpty) custom = null;
  }

  return (
    temperature: enabledDouble('temperature'),
    topP: enabledDouble('topP'),
    topK: enabledInt('topK'),
    frequencyPenalty: enabledDouble('frequencyPenalty'),
    presencePenalty: enabledDouble('presencePenalty'),
    seed: enabledInt('seed'),
    stopSequences: stops,
    responseFormat: enabled<String>('responseFormat'),
    parallelToolCalls: enabled<bool>('parallelToolCalls'),
    logprobs: enabled<bool>('logprobs'),
    user: enabled<String>('user'),
    reasoningEffort: enabled<String>('reasoningEffort'),
    thinkingBudget: enabledInt('thinkingBudget'),
    includeThoughts: enabled<bool>('includeThoughts'),
    cacheControl: enabled<bool>('cacheControl'),
    structuredOutputMode: enabled<String>('structuredOutputMode'),
    webSearchEnabled: enabled<bool>('webSearchEnabled'),
    codeExecutionEnabled: enabled<bool>('codeExecutionEnabled'),
    useSearchGrounding: enabled<bool>('useSearchGrounding'),
    safetyLevel: enabled<String>('safetyLevel'),
    streamOutput: ps.isParameterEnabled('streamOutput')
        ? (ps.getParameterValue('streamOutput') as bool?) ?? true
        : true,
    customParameters: custom,
  );
}
