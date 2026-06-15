import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_controller.g.dart';

/// Tracks whether the first-time welcome page still needs to be shown.
///
/// The state is `true` for a first-time user (show the welcome page) and `false`
/// once onboarding is done. It seeds `true` and lives in memory only for M4.1 —
/// mirroring the M4.0 theme controller's "seam, not yet persisted" approach.
///
/// The original gated this on a persisted `first-time-user` flag. Persistence
/// here is a deliberate seam (see [restore]): where app preferences live
/// (shared_preferences vs a Drift settings table) is a separate decision, and
/// M4.1 adds no new dependencies — so the welcome page reappears on each cold
/// start until persistence is wired.
///
/// `keepAlive: true`: this is an app-level flag, not screen-scoped state — it
/// must survive the welcome page being disposed after navigation, so it is not
/// auto-disposed.
@Riverpod(keepAlive: true)
class OnboardingController extends _$OnboardingController {
  @override
  bool build() => true;

  /// Marks onboarding done for this session; the welcome page calls this before
  /// navigating to the chat home. In-memory only until [restore] is wired.
  void markStarted() => state = false;

  /// Seam for persistence: a later sub-stage decides where the onboarding flag
  /// is stored and calls this before the first frame so the welcome page does
  /// not reappear on restart.
  ///
  /// TODO(persistence): load the persisted flag from the chosen store and feed
  /// it here; until then this is unused and onboarding stays in-memory.
  // ignore: use_setters_to_change_properties
  void restore({required bool needsOnboarding}) => state = needsOnboarding;
}
