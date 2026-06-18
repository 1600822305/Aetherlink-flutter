// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'input_modes_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The active input-box session mode, or `null` for none.
///
/// Mutually exclusive and held purely in memory — toggling one on turns any
/// other off, and a full restart resets to `null`. This deliberately mirrors
/// the web, where these live in a component `useState<ExclusiveMode>(null)`
/// (not persisted), and follows the same session-only policy as the sidebar
/// tab. The MCP 工具 switch is the original's persisted toggle and is **not**
/// one of these modes.

@ProviderFor(InputModeController)
final inputModeControllerProvider = InputModeControllerProvider._();

/// The active input-box session mode, or `null` for none.
///
/// Mutually exclusive and held purely in memory — toggling one on turns any
/// other off, and a full restart resets to `null`. This deliberately mirrors
/// the web, where these live in a component `useState<ExclusiveMode>(null)`
/// (not persisted), and follows the same session-only policy as the sidebar
/// tab. The MCP 工具 switch is the original's persisted toggle and is **not**
/// one of these modes.
final class InputModeControllerProvider
    extends $NotifierProvider<InputModeController, InputMode?> {
  /// The active input-box session mode, or `null` for none.
  ///
  /// Mutually exclusive and held purely in memory — toggling one on turns any
  /// other off, and a full restart resets to `null`. This deliberately mirrors
  /// the web, where these live in a component `useState<ExclusiveMode>(null)`
  /// (not persisted), and follows the same session-only policy as the sidebar
  /// tab. The MCP 工具 switch is the original's persisted toggle and is **not**
  /// one of these modes.
  InputModeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inputModeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inputModeControllerHash();

  @$internal
  @override
  InputModeController create() => InputModeController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InputMode? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InputMode?>(value),
    );
  }
}

String _$inputModeControllerHash() =>
    r'0b702a4e19eb9bf4fc35ca85099f5e0dd7e0c29d';

/// The active input-box session mode, or `null` for none.
///
/// Mutually exclusive and held purely in memory — toggling one on turns any
/// other off, and a full restart resets to `null`. This deliberately mirrors
/// the web, where these live in a component `useState<ExclusiveMode>(null)`
/// (not persisted), and follows the same session-only policy as the sidebar
/// tab. The MCP 工具 switch is the original's persisted toggle and is **not**
/// one of these modes.

abstract class _$InputModeController extends $Notifier<InputMode?> {
  InputMode? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<InputMode?, InputMode?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<InputMode?, InputMode?>,
              InputMode?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The standalone 清空内容 button's two-step confirm latch — the port of the web
/// `clearConfirmMode` `useState` shared by `ButtonToolbar` / `ToolsMenu`.
///
/// `true` while the button is armed: the first tap arms it (the glyph swaps to a
/// red `AlertTriangle` and the label to 确认清空) and a second tap within 3 seconds
/// performs the clear; otherwise it disarms itself. Held in memory only — a
/// restart leaves it disarmed. The 扩展 menu runs its own independent confirm
/// (sheet-local) so opening the menu never arms the toolbar button.

@ProviderFor(InputClearConfirm)
final inputClearConfirmProvider = InputClearConfirmProvider._();

/// The standalone 清空内容 button's two-step confirm latch — the port of the web
/// `clearConfirmMode` `useState` shared by `ButtonToolbar` / `ToolsMenu`.
///
/// `true` while the button is armed: the first tap arms it (the glyph swaps to a
/// red `AlertTriangle` and the label to 确认清空) and a second tap within 3 seconds
/// performs the clear; otherwise it disarms itself. Held in memory only — a
/// restart leaves it disarmed. The 扩展 menu runs its own independent confirm
/// (sheet-local) so opening the menu never arms the toolbar button.
final class InputClearConfirmProvider
    extends $NotifierProvider<InputClearConfirm, bool> {
  /// The standalone 清空内容 button's two-step confirm latch — the port of the web
  /// `clearConfirmMode` `useState` shared by `ButtonToolbar` / `ToolsMenu`.
  ///
  /// `true` while the button is armed: the first tap arms it (the glyph swaps to a
  /// red `AlertTriangle` and the label to 确认清空) and a second tap within 3 seconds
  /// performs the clear; otherwise it disarms itself. Held in memory only — a
  /// restart leaves it disarmed. The 扩展 menu runs its own independent confirm
  /// (sheet-local) so opening the menu never arms the toolbar button.
  InputClearConfirmProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inputClearConfirmProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inputClearConfirmHash();

  @$internal
  @override
  InputClearConfirm create() => InputClearConfirm();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$inputClearConfirmHash() => r'd69e2c4c21b296ae2df298a25640c52a95b6d662';

/// The standalone 清空内容 button's two-step confirm latch — the port of the web
/// `clearConfirmMode` `useState` shared by `ButtonToolbar` / `ToolsMenu`.
///
/// `true` while the button is armed: the first tap arms it (the glyph swaps to a
/// red `AlertTriangle` and the label to 确认清空) and a second tap within 3 seconds
/// performs the clear; otherwise it disarms itself. Held in memory only — a
/// restart leaves it disarmed. The 扩展 menu runs its own independent confirm
/// (sheet-local) so opening the menu never arms the toolbar button.

abstract class _$InputClearConfirm extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
