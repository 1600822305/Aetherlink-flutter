import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_view_mode_controller.g.dart';

/// Holds the settings hub's "compact ↔ detailed" view mode for the application
/// layer (the page stays a pure view — no business logic, see
/// PROJECT_STRUCTURE / ADR-0009).
///
/// `true` = compact (titles only), `false` = detailed (titles + descriptions).
/// It seeds `false` (detailed is the default, matching the original) and lives
/// in memory only for this milestone — mirroring the M4.1 onboarding
/// controller's "seam, not yet persisted" approach.
///
/// The original persisted this under the `settings-compact-mode` localStorage
/// key. Where app preferences live (shared_preferences vs a Drift settings
/// table) is a separate decision, and this milestone adds no new persistence —
/// so the mode resets to detailed on each cold start until persistence is
/// wired.
///
/// `keepAlive: true`: this is an app-level UI preference, not screen-scoped
/// state — it must survive the settings page being disposed when navigating
/// into a sub-page and back, so it is not auto-disposed.
@Riverpod(keepAlive: true)
class SettingsViewModeController extends _$SettingsViewModeController {
  @override
  bool build() => false;

  /// Flips between compact and detailed; the header toggle calls this.
  void toggle() => state = !state;
}
