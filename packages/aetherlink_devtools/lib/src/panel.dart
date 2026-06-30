import 'package:flutter/widgets.dart';

/// A single tab in the [DevToolsPage]. Each devtools surface (Console, Network,
/// Performance, Storage, Device…) implements this and is registered once in
/// [DevToolsRegistry]; the page renders one [TabBar] tab per registered panel.
///
/// This is the extension point that lets the later phases (Network / Performance
/// / Storage / Device) be built independently and in parallel: a new panel is a
/// new [DevToolsPanel] subclass plus one line in [DevToolsRegistry.register] —
/// no edits to the page itself, minimising merge conflicts.
abstract class DevToolsPanel {
  const DevToolsPanel();

  /// Tab label, e.g. `控制台`.
  String get title;

  /// Tab leading icon (Lucide, per ADR-0009 — kept as plain [IconData] so the
  /// package needn't depend on the icon set; the host supplies the value).
  IconData get icon;

  /// Builds the panel body shown when its tab is active.
  Widget build(BuildContext context);
}

/// The ordered set of panels the [DevToolsPage] renders. Panels register
/// themselves here (the Console panel is registered by default in the library
/// entrypoint); later phases append their own.
class DevToolsRegistry {
  DevToolsRegistry._();

  static final List<DevToolsPanel> _panels = <DevToolsPanel>[];

  /// The registered panels, in tab order.
  static List<DevToolsPanel> get panels => List.unmodifiable(_panels);

  /// Registers [panel] (idempotent per runtime type, so hot-restart / repeated
  /// wiring never duplicates a tab).
  static void register(DevToolsPanel panel) {
    _panels.removeWhere((p) => p.runtimeType == panel.runtimeType);
    _panels.add(panel);
  }
}
