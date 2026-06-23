import 'dart:math' as math;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/json_kv_notifier.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/sidebar_settings.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';

part 'sidebar_settings_controller.g.dart';

/// Storage key for the persisted 侧边栏设置 (a single JSON blob, the Flutter
/// equivalent of the web's `localStorage` `appSettings` + `settings` slice).
const String kSidebarSettingsKey = 'sidebarSettings';

/// 侧边栏宽度下限 (px) — `SIDEBAR_WIDTH_MIN` in `sidebarOptimization.ts`.
const double kSidebarWidthMin = 340;

/// 侧边栏宽度上限 (px) — `SIDEBAR_WIDTH_MAX`.
const double kSidebarWidthMax = 800;

/// 移动端宽度上限 (px) — `SIDEBAR_MOBILE_MAX`.
const double kSidebarMobileMax = 400;

/// 桌面端预留给主区的安全边距 (px) — `SIDEBAR_VIEWPORT_SAFE_MARGIN`.
const double kSidebarViewportSafeMargin = 120;

/// 触发"移动端"上限的断点 (px) — `SIDEBAR_MOBILE_BREAKPOINT`.
const double kSidebarMobileBreakpoint = 900;

/// 宽度快捷预设，过滤掉超过当前安全上限的项 — `SidebarWidthDialog` `presets`.
const List<double> kSidebarWidthPresets = [340, 400, 500, 600];

/// The largest sidebar width that fits [screenWidth], a port of
/// `getSafeMaxSidebarWidth`: phones (narrow) cap at [kSidebarMobileMax], wider
/// screens leave [kSidebarViewportSafeMargin] for the chat area.
double safeMaxSidebarWidth(double screenWidth) {
  if (screenWidth < kSidebarMobileBreakpoint) return kSidebarMobileMax;
  final viewportLimit = screenWidth - kSidebarViewportSafeMargin;
  return math.max(kSidebarWidthMin, math.min(kSidebarWidthMax, viewportLimit));
}

/// Holds the 设置 tab (侧边栏快捷设置面板) configuration so the sidebar stays a pure
/// view and the chat view can react to the wired-up toggles.
///
/// `keepAlive: true`: an app-level preference shared by the sidebar, the drawer
/// width and the chat view. Hydrated from the Drift key/value store on first
/// build and written through on every change (the port of the web
/// `dexieStorage.saveSetting` / `localStorage` `appSettings`), so it survives a
/// full restart.
@Riverpod(keepAlive: true)
class SidebarSettingsController extends _$SidebarSettingsController
    with JsonKvNotifier<SidebarSettings> {
  @override
  ChatRepository get kvStore => ref.read(chatRepositoryProvider);

  @override
  String get storageKey => kSidebarSettingsKey;

  @override
  SidebarSettings fromStored(Map<String, dynamic> json) =>
      SidebarSettings.fromJson(json);

  @override
  Map<String, dynamic> toStored(SidebarSettings value) => value.toJson();

  @override
  SidebarSettings build() => hydrate(const SidebarSettings());

  // ── 常规设置 ────────────────────────────────────────────────────────────
  /// Toggles 消息分割线 (wired: [_MessageListView] draws a divider between bubbles).
  void setShowMessageDivider(bool value) =>
      persist(state.copyWith(showMessageDivider: value));

  /// Toggles 代码块可复制 (wired: [CodeBlockView] hides its copy button when off).
  void setCopyableCodeBlocks(bool value) =>
      persist(state.copyWith(copyableCodeBlocks: value));

  /// Toggles 渲染用户输入 (persisted; chat-view effect 即将支持).
  void setRenderUserInputAsMarkdown(bool value) =>
      persist(state.copyWith(renderUserInputAsMarkdown: value));

  /// Toggles 自动下滑 (persisted; chat-view effect 即将支持).
  void setAutoScrollToBottom(bool value) =>
      persist(state.copyWith(autoScrollToBottom: value));

  /// Sets 消息样式 (persisted; chat-view effect 即将支持).
  void setMessageStyle(MessageStyle value) =>
      persist(state.copyWith(messageStyle: value));

  /// Sets 对话导航 (persisted; chat-view effect 即将支持).
  void setMessageNavigation(MessageNavigation value) =>
      persist(state.copyWith(messageNavigation: value));

  /// Toggles Token用量指示 (persisted; chat-view effect 即将支持).
  void setShowContextTokenIndicator(bool value) =>
      persist(state.copyWith(showContextTokenIndicator: value));

  // ── 侧边栏宽度 ──────────────────────────────────────────────────────────
  /// Live-previews 侧边栏宽度 without persisting — the dialog drives this on every
  /// drag so the drawer resizes in real time, then commits with [setSidebarWidth]
  /// on 保存 or reverts to the original value on 取消 (mirrors `SidebarWidthDialog`).
  void previewSidebarWidth(double value) =>
      state = state.copyWith(sidebarWidth: value);

  /// Commits 侧边栏宽度; the value is clamped against the live screen width by the
  /// dialog before it reaches here.
  void setSidebarWidth(double value) =>
      persist(state.copyWith(sidebarWidth: value));

  // ── 侧边栏显示方式 ──────────────────────────────────────────────────────
  /// Sets 侧边栏显示方式 (wired: [SidebarHost] switches between overlay/push).
  void setSidebarDisplayMode(SidebarDisplayMode value) =>
      persist(state.copyWith(sidebarDisplayMode: value));

  // ── 上下文设置 (已接入 ChatController) ──────────────────────────────────
  void setContextWindowSize(int value) =>
      persist(state.copyWith(contextWindowSize: value));

  void setContextCount(int value) =>
      persist(state.copyWith(contextCount: value));

  void setMaxOutputTokens(int value) =>
      persist(state.copyWith(maxOutputTokens: value));

  void setEnableMaxOutputTokens(bool value) =>
      persist(state.copyWith(enableMaxOutputTokens: value));

  // ── 输入设置 (即将支持) ───────────────────────────────────────────────────
  void setPasteLongTextAsFile(bool value) =>
      persist(state.copyWith(pasteLongTextAsFile: value));

  void setPasteLongTextThreshold(int value) =>
      persist(state.copyWith(pasteLongTextThreshold: value));

  // ── 代码块设置 ─────────────────────────────────────────────────────────
  void setCodeShowLineNumbers(bool value) =>
      persist(state.copyWith(codeShowLineNumbers: value));

  void setCodeCollapsible(bool value) =>
      persist(state.copyWith(codeCollapsible: value));

  void setCodeWrappable(bool value) =>
      persist(state.copyWith(codeWrappable: value));

  void setCodeDefaultCollapsed(bool value) =>
      persist(state.copyWith(codeDefaultCollapsed: value));

  void setCodeHighlightTheme(String value) =>
      persist(state.copyWith(codeHighlightTheme: value));

  void setCodeFontSize(int value) =>
      persist(state.copyWith(codeFontSize: value.clamp(10, 24)));

  void setMermaidEnabled(bool value) =>
      persist(state.copyWith(mermaidEnabled: value));

  // ── 数学公式设置 ─────────────────────────────────────────────────────────
  void setMathEnableSingleDollar(bool value) =>
      persist(state.copyWith(mathEnableSingleDollar: value));
}
