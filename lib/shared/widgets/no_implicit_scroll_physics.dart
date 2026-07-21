import 'package:flutter/widgets.dart';

/// Scroll physics that opt the list out of *implicit* (non-user-intent)
/// scrolling: with [allowImplicitScrolling] false the viewport's
/// `showOnScreen` no longer moves the scroll offset, so a child grabbing
/// focus or a `SelectionArea` revealing a selection can never yank the list —
/// only user gestures and explicit controller calls scroll it.
///
/// The 千问 chat list achieves the same by overriding `requestChildFocus` /
/// `requestChildRectangleOnScreen` on its RecyclerView; this is the Flutter
/// equivalent, expressed through the physics the viewport consults.
class NoImplicitScrollPhysics extends AlwaysScrollableScrollPhysics {
  const NoImplicitScrollPhysics({super.parent});

  @override
  bool get allowImplicitScrolling => false;

  @override
  NoImplicitScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      NoImplicitScrollPhysics(parent: buildParent(ancestor));
}
