import 'package:freezed_annotation/freezed_annotation.dart';

part 'thinking_settings.freezed.dart';
part 'thinking_settings.g.dart';

/// 思考过程显示样式 (`settings.thinkingDisplayStyle`, `ThinkingBlock.tsx`).
///
/// The original ships 17 styles; this port mirrors the practical subset
/// (`compact` / `full` / `minimal` / `bubble` / `card` / `hidden`) and drops the
/// novelty ones (timeline / inline + the 2025 "advanced" stream / dots / wave /
/// sidebar / overlay / breadcrumb / floating / terminal). `compact` is the
/// original default.
enum ThinkingDisplayStyle {
  compact('compact'),
  full('full'),
  minimal('minimal'),
  bubble('bubble'),
  card('card'),
  devin('devin'),
  hidden('hidden');

  const ThinkingDisplayStyle(this.id);

  /// The original string id persisted in `settings.thinkingDisplayStyle`.
  final String id;

  static ThinkingDisplayStyle fromId(String? id) {
    for (final v in ThinkingDisplayStyle.values) {
      if (v.id == id) return v;
    }
    // Unknown / a not-yet-ported original style falls back to the default.
    return ThinkingDisplayStyle.compact;
  }
}

/// The 思考过程设置 configuration the appearance sub-page edits and the chat
/// thinking block renders, a port of the original `settings` slice fields read
/// by `ThinkingProcessSettings.tsx` / `ThinkingBlock.tsx`.
///
/// Defaults mirror the original component fallbacks: compact display style,
/// auto-collapse on, tool-inline on.
@freezed
abstract class ThinkingSettings with _$ThinkingSettings {
  const factory ThinkingSettings({
    @Default(ThinkingDisplayStyle.compact) ThinkingDisplayStyle displayStyle,
    // 思考完成后自动折叠，原版默认开。
    @Default(true) bool thoughtAutoCollapse,
    // 思考过程内显示工具调用，原版默认开。关闭后思考阶段的工具调用独立显示在消息下方。
    @Default(true) bool thinkingToolInline,
  }) = _ThinkingSettings;

  factory ThinkingSettings.fromJson(Map<String, dynamic> json) =>
      _$ThinkingSettingsFromJson(json);
}
