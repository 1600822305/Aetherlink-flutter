import 'package:flutter/services.dart';

import 'package:aetherlink_flutter/shared/domain/behavior_settings.dart';

/// Global haptic-feedback service (port of the web `Haptics` singleton in
/// `src/shared/utils/hapticFeedback.ts`).
///
/// The app root keeps [_settings] in sync with the persisted
/// [BehaviorSettings.hapticFeedback] (via a listener on `appBehaviorSettings`),
/// so any widget can fire a gated haptic without threading the Riverpod
/// provider through it — matching how the web util read the store directly.
///
/// Intensities map the original (`light`/`medium`/`soft`/`drawerPulse`) onto
/// Flutter's [HapticFeedback]: light/medium impacts plus the lighter selection
/// click. Haptics are a no-op on platforms without a vibrator (desktop).
class Haptics {
  Haptics._();

  /// The app-wide instance.
  static final Haptics instance = Haptics._();

  HapticFeedbackSettings _settings = const HapticFeedbackSettings();

  /// Pushes the latest persisted config in; called from the app root.
  void updateSettings(HapticFeedbackSettings settings) => _settings = settings;

  // Primitives — always fire. Used by the in-page 测试 buttons (gated by their
  // own enabled state) and the master toggle's enable confirmation.
  Future<void> light() => HapticFeedback.lightImpact();
  Future<void> medium() => HapticFeedback.mediumImpact();
  Future<void> soft() => HapticFeedback.selectionClick();
  Future<void> drawerPulse() => HapticFeedback.mediumImpact();

  // Gated interaction points — fire only when the master switch and the
  // matching sub-toggle are both on.

  /// Switch toggled (any [CustomSwitch] change).
  Future<void> onSwitch() async {
    if (_settings.enabled && _settings.enableOnSwitch) await soft();
  }

  /// Sidebar/drawer opened.
  Future<void> onSidebar() async {
    if (_settings.enabled && _settings.enableOnSidebar) await drawerPulse();
  }

  /// List item selected (assistant / topic).
  Future<void> onListItem() async {
    if (_settings.enabled && _settings.enableOnListItem) await light();
  }

  /// Route navigation (any push).
  Future<void> onNavigation() async {
    if (_settings.enabled && _settings.enableOnNavigation) await light();
  }
}
