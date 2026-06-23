import 'package:freezed_annotation/freezed_annotation.dart';

part 'sidebar_settings.freezed.dart';
part 'sidebar_settings.g.dart';

/// 消息样式 (`settings.messageStyle`, `useSettingsManagement.ts`): `bubble` 气泡
/// 样式（默认）；`plain` 简洁样式。
enum MessageStyle {
  plain('plain', '简洁'),
  bubble('bubble', '气泡');

  const MessageStyle(this.id, this.label);

  /// The original string id persisted in `settings.messageStyle`.
  final String id;

  /// The 设置 tab dropdown label (`messageStyleOptions`).
  final String label;

  static MessageStyle fromId(String? id) {
    for (final v in MessageStyle.values) {
      if (v.id == id) return v;
    }
    return MessageStyle.bubble;
  }
}

/// 侧边栏显示方式（Flutter 特有，无 Web 对应）：`overlay` 覆盖式——抽屉滑入盖在聊天页上
/// 并加遮罩（默认，原生 Material Drawer 行为）；`push` 推开式——抽屉滑入时把聊天页整体向右
/// 推开（参考 kelivo）。内容相同，仅显示方式不同。
enum SidebarDisplayMode {
  overlay('overlay', '覆盖'),
  push('push', '推开');

  const SidebarDisplayMode(this.id, this.label);

  /// 持久化用的字符串 id（同时也是 json_serializable 默认编码的枚举名）。
  final String id;

  /// 设置项下拉的标签。
  final String label;

  static SidebarDisplayMode fromId(String? id) {
    for (final v in SidebarDisplayMode.values) {
      if (v.id == id) return v;
    }
    return SidebarDisplayMode.overlay;
  }
}

/// 对话导航 (`settings.messageNavigation`): `none` 不显示（默认）；`buttons` 显示上下
/// 按钮快速跳转。
enum MessageNavigation {
  none('none', '不显示'),
  buttons('buttons', '上下按钮');

  const MessageNavigation(this.id, this.label);

  /// The original string id persisted in `settings.messageNavigation`.
  final String id;

  /// The 设置 tab dropdown label (`messageNavigationOptions`).
  final String label;

  static MessageNavigation fromId(String? id) {
    for (final v in MessageNavigation.values) {
      if (v.id == id) return v;
    }
    return MessageNavigation.none;
  }
}

/// The 设置 tab (侧边栏快捷设置面板) configuration the sidebar edits, a port of the
/// fields read by `SettingsTab/index.tsx` + its sub-sections.
///
/// Persisted as a single JSON blob (the Flutter equivalent of the web's
/// `localStorage` `appSettings` + `settings` Redux slice). Defaults mirror the
/// web seeds (`useSettingsStorage` `DEFAULT_SETTINGS` + the `settings` slice
/// `defaults.ts`).
///
/// Scope split (confirmed with the product owner):
///   * 常规设置 7 项 + 侧边栏宽度 are fully wired (see [SidebarSettingsController]
///     consumers); `showMessageDivider` / `copyableCodeBlocks` already drive the
///     chat view, the rest persist and light up as their chat widgets land.
///   * 上下文设置 (`contextCount`, `maxOutputTokens`, `enableMaxOutputTokens`)
///     are wired — `ChatController._contextSettings()` reads them and applies
///     message trimming + `maxTokens` to every `LlmChatRequest`.
///     `contextWindowSize` is informational (displayed in sidebar subtitle).
///   * 输入行为 persists here for its composer slice. 代码块显示 settings are
///     consumed by `CodeBlockView`; Mermaid rendering is still its own slice.
///   * 数学 (单美元) is wired — `AppMarkdown` reads `mathEnableSingleDollar`
///     via Riverpod and passes it to `GptMarkdown.useDollarSignsForLatex`.
///   * 性能节流 / 虚拟化列表 / 代码编辑器主题 / 数学引擎下拉 are Web-only framework tax
///     and are intentionally dropped.
@freezed
abstract class SidebarSettings with _$SidebarSettings {
  const factory SidebarSettings({
    // ── 常规设置 (7 项) ──────────────────────────────────────────────────────
    @Default(true) bool showMessageDivider,
    @Default(true) bool copyableCodeBlocks,
    @Default(true) bool renderUserInputAsMarkdown,
    @Default(true) bool autoScrollToBottom,
    @Default(MessageStyle.bubble) MessageStyle messageStyle,
    @Default(MessageNavigation.none) MessageNavigation messageNavigation,
    @Default(true) bool showContextTokenIndicator,
    // ── 侧边栏宽度 (px) ───────────────────────────────────────────────────────
    // Flutter mobile drawer default 350 (`AppSidebar.solid.tsx`); clamped to
    // [kSidebarWidthMin, getSafeMaxSidebarWidth] when applied.
    @Default(350.0) double sidebarWidth,
    // ── 侧边栏显示方式 (Flutter 特有) ─────────────────────────────────────────
    // overlay 覆盖式（默认，原生抽屉行为）/ push 推开式（聊天页随抽屉右移）。
    @Default(SidebarDisplayMode.overlay) SidebarDisplayMode sidebarDisplayMode,
    // ── 上下文设置 (已接入 ChatController) ──────────────────────────────────
    @Default(100000) int contextWindowSize,
    @Default(20) int contextCount,
    @Default(8192) int maxOutputTokens,
    @Default(true) bool enableMaxOutputTokens,
    // ── 输入设置 (即将支持) ───────────────────────────────────────────────────
    @Default(false) bool pasteLongTextAsFile,
    @Default(1500) int pasteLongTextThreshold,
    // ── 代码块设置 ─────────────────────────────────────────────────────────
    @Default(true) bool codeShowLineNumbers,
    @Default(true) bool codeCollapsible,
    @Default(true) bool codeWrappable,
    @Default(false) bool codeDefaultCollapsed,
    @Default('auto') String codeHighlightTheme,
    @Default(13) int codeFontSize,
    @Default(true) bool mermaidEnabled,
    // ── 数学公式设置 ─────────────────────────────────────────────────────────
    // Single-dollar inline math; the engine dropdown (KaTeX/MathJax) is dropped
    // because Flutter renders natively with flutter_math_fork.
    @Default(true) bool mathEnableSingleDollar,
  }) = _SidebarSettings;

  factory SidebarSettings.fromJson(Map<String, dynamic> json) =>
      _$SidebarSettingsFromJson(json);
}
