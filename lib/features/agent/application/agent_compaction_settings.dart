// 上下文压缩的 App 级设置（压缩设置页 v1）：自动压缩总开关、触发比例、
// 保留量、microcompact 开关与阈值。全部有默认值 = 当前行为不变。
//
// 持久化走 appSettingsStore 单键 JSON（同 hooks 设置的模式）；encode/
// decode 是纯函数便于单测，坏数据逐字段回退默认值。引擎在任务启动时
// 经 task runner 读本 provider 填 AgentBudget，重放侧经 AgentLlmContext
// 拿到与引擎一致的 microcompact 生效值（两侧视图必须一致）。

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_compaction_trigger.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_microcompact.dart';

/// Settings-store key（单键 JSON 存整个设置对象）。
const String kAgentCompactionSettingsKey = 'agent_compaction_settings';

/// 字符回退触发阈值的基准（ratio=0.92 时为 120000，与 AgentBudget
/// 构造默认值一致）；档位比例变化时按比例缩放，保持 token 路径与
/// 字符回退路径的触发时机同步。
const int _kFallbackTriggerBaseChars = 120000;

/// 上下文压缩设置（不可变数据类）。
class AgentCompactionSettings {
  const AgentCompactionSettings({
    this.autoCompactEnabled = true,
    this.microCompactEnabled = true,
    this.triggerRatio = kCompactionTriggerRatio,
    this.keepChars = 40000,
    this.microCompactTriggerChars = kMicroCompactTriggerChars,
  });

  /// 自动压缩总开关：关掉后阈值不再自动触发（预警照发、手动压缩不受影响）。
  final bool autoCompactEnabled;

  /// microcompact（不调 LLM 的旧工具输出占位清除）开关。
  final bool microCompactEnabled;

  /// 有效窗口的自动压缩触发比例（UI 用档位 85%/90%/92%/95%）。
  final double triggerRatio;

  /// 压缩后保留给尾部近期事件的字符预算（档位 20k/40k/60k）。
  final int keepChars;

  /// microcompact 触发阈值（字符，档位 60k/80k/100k）。
  final int microCompactTriggerChars;

  /// 字符回退路径的触发阈值：随触发比例同步缩放（默认比例下 = 120000，
  /// 与既有 AgentBudget 默认值一致）。
  int get compactionTriggerChars =>
      (_kFallbackTriggerBaseChars * triggerRatio / kCompactionTriggerRatio)
          .round();

  AgentCompactionSettings copyWith({
    bool? autoCompactEnabled,
    bool? microCompactEnabled,
    double? triggerRatio,
    int? keepChars,
    int? microCompactTriggerChars,
  }) =>
      AgentCompactionSettings(
        autoCompactEnabled: autoCompactEnabled ?? this.autoCompactEnabled,
        microCompactEnabled: microCompactEnabled ?? this.microCompactEnabled,
        triggerRatio: triggerRatio ?? this.triggerRatio,
        keepChars: keepChars ?? this.keepChars,
        microCompactTriggerChars:
            microCompactTriggerChars ?? this.microCompactTriggerChars,
      );

  @override
  bool operator ==(Object other) =>
      other is AgentCompactionSettings &&
      other.autoCompactEnabled == autoCompactEnabled &&
      other.microCompactEnabled == microCompactEnabled &&
      other.triggerRatio == triggerRatio &&
      other.keepChars == keepChars &&
      other.microCompactTriggerChars == microCompactTriggerChars;

  @override
  int get hashCode => Object.hash(autoCompactEnabled, microCompactEnabled,
      triggerRatio, keepChars, microCompactTriggerChars);
}

/// 编码：设置 → JSON 字符串。
String encodeAgentCompactionSettings(AgentCompactionSettings settings) =>
    jsonEncode({
      'autoCompactEnabled': settings.autoCompactEnabled,
      'microCompactEnabled': settings.microCompactEnabled,
      'triggerRatio': settings.triggerRatio,
      'keepChars': settings.keepChars,
      'microCompactTriggerChars': settings.microCompactTriggerChars,
    });

/// 解码：缺失/坏数据逐字段回退默认值（默认不改变现有行为）。
AgentCompactionSettings decodeAgentCompactionSettings(String? raw) {
  const fallback = AgentCompactionSettings();
  if (raw == null || raw.isEmpty) return fallback;
  try {
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) return fallback;
    return AgentCompactionSettings(
      autoCompactEnabled: json['autoCompactEnabled'] is bool
          ? json['autoCompactEnabled'] as bool
          : fallback.autoCompactEnabled,
      microCompactEnabled: json['microCompactEnabled'] is bool
          ? json['microCompactEnabled'] as bool
          : fallback.microCompactEnabled,
      triggerRatio: json['triggerRatio'] is num &&
              (json['triggerRatio'] as num) > 0 &&
              (json['triggerRatio'] as num) <= 1
          ? (json['triggerRatio'] as num).toDouble()
          : fallback.triggerRatio,
      keepChars: json['keepChars'] is int && (json['keepChars'] as int) > 0
          ? json['keepChars'] as int
          : fallback.keepChars,
      microCompactTriggerChars: json['microCompactTriggerChars'] is int &&
              (json['microCompactTriggerChars'] as int) > 0
          ? json['microCompactTriggerChars'] as int
          : fallback.microCompactTriggerChars,
    );
  } catch (_) {
    return fallback;
  }
}

final agentCompactionSettingsProvider = NotifierProvider<
    AgentCompactionSettingsNotifier,
    AgentCompactionSettings>(AgentCompactionSettingsNotifier.new);

class AgentCompactionSettingsNotifier
    extends Notifier<AgentCompactionSettings> {
  /// 异步加载完成前不写库，避免加载期间的写入覆盖存量（同 hooks 设置）。
  bool _loaded = false;
  AgentCompactionSettings? _pendingWrite;

  @override
  AgentCompactionSettings build() {
    ref
        .read(appSettingsStoreProvider)
        .getSetting(kAgentCompactionSettingsKey)
        .then((raw) {
      final pending = _pendingWrite;
      _loaded = true;
      if (pending != null) {
        state = pending;
        _persist();
      } else {
        state = decodeAgentCompactionSettings(raw);
      }
    });
    return const AgentCompactionSettings();
  }

  void set(AgentCompactionSettings value) {
    if (!_loaded) {
      _pendingWrite = value;
      state = value;
      return;
    }
    state = value;
    _persist();
  }

  void _persist() {
    ref.read(appSettingsStoreProvider).saveSetting(
        kAgentCompactionSettingsKey, encodeAgentCompactionSettings(state));
  }
}
