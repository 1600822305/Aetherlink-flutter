import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:aetherlink_flutter/shared/widgets/auto_scroll_controller.dart';

/// Spreads the build cost of heavy message content across frames.
///
/// Entering a topic pins to the bottom, so the first frame pays for every
/// block it can reach — a single bubble stuffed with long markdown / code /
/// tables (e.g. multi-round tool calls in one message) can blow the 8.3ms
/// budget of a 120Hz frame on its own. Windowing by row count can't help
/// there; the cost has to be split *inside* the bubble.
///
/// Cheap content (cost ≤ [inlineCostThreshold]) builds inline with no
/// placeholder at all. Heavy content renders a lightweight placeholder box on
/// its first frame and is materialized by [DeferredContentScheduler] over the
/// following frames under a per-frame cost budget — newest registrations
/// first (LIFO), so the blocks near the viewport (built last when the entry
/// pin lays the window out top-to-bottom) appear first.
///
/// Once materialized the real content stays mounted forever ([_KeepAliveItem]
/// keeps the row's element tree alive), so streaming growth or rebuilds never
/// flash the placeholder again.
class DeferredContent extends StatefulWidget {
  const DeferredContent({
    required this.cost,
    required this.estimatedHeight,
    required this.builder,
    super.key,
  });

  /// Approximate build cost, in source characters. Content at or below
  /// [inlineCostThreshold] is built inline (never deferred).
  final int cost;

  /// Placeholder height while deferred. Estimation errors are corrected on
  /// materialization; while pinned to the bottom the follow controller
  /// compensates during layout.
  final double estimatedHeight;

  final WidgetBuilder builder;

  /// Content cheaper than this renders inline — small blocks never flash.
  static const int inlineCostThreshold = 1500;

  @override
  State<DeferredContent> createState() => _DeferredContentState();
}

class _DeferredContentState extends State<DeferredContent> {
  bool _materialized = false;
  DeferredContentEntry? _entry;
  double? _compensateFrom;

  @override
  void initState() {
    super.initState();
    if (widget.cost <= DeferredContent.inlineCostThreshold) {
      _materialized = true;
    } else {
      _entry = DeferredContentScheduler.instance.enqueue(
        widget.cost,
        _materialize,
      );
    }
  }

  void _materialize() {
    _entry = null;
    if (!mounted) return;
    _compensateFrom = materializationBaseline(context);
    setState(() => _materialized = true);
  }

  @override
  void dispose() {
    _entry?.cancel();
    _entry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_materialized) {
      final baseline = _compensateFrom;
      if (baseline == null) return widget.builder(context);
      return MaterializationShift(
        previousExtent: baseline,
        child: Builder(builder: widget.builder),
      );
    }
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      height: widget.estimatedHeight.clamp(48.0, 4000.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

/// Placeholder→content swaps change an item's height. When the item lies
/// entirely *above* the viewport's leading edge, that delta would shift every
/// visible row while `pixels` stays put — a visible jump mid-scroll (worst on
/// long user bubbles, whose estimated skeleton height is far off).
///
/// Returns the item's current (placeholder) extent when it lies fully above
/// the leading edge — the baseline for a [MaterializationShift] wrapper that
/// measures the real content on its first layout and compensates the scroll
/// offset by the *exact* per-item delta within the same layout pass. Items
/// visible or below the viewport need no correction (null): their growth
/// happens at/below the anchor and never moves the content above it.
double? materializationBaseline(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  final viewport = RenderAbstractViewport.maybeOf(box);
  final position = Scrollable.maybeOf(context)?.position;
  if (viewport == null || position == null || !position.hasPixels) return null;
  final revealTop = viewport.getOffsetToReveal(box, 0).offset;
  if (revealTop + box.size.height <= position.pixels) return box.size.height;
  return null;
}

/// Wraps freshly materialized content whose placeholder sat fully above the
/// viewport: on the first layout after the swap it feeds the measured extent
/// delta into the scroll position's layout-time compensation
/// ([AutoFollowScrollController.addPendingAdjustFor]), applied in the same
/// layout pass — the viewport stays anchored with no estimate-based drift
/// (a `maxScrollExtent`-delta proxy is wildly wrong mid-scroll, when the
/// list's estimated extent swings with every newly built child).
class MaterializationShift extends SingleChildRenderObjectWidget {
  const MaterializationShift({
    required this.previousExtent,
    super.child,
    super.key,
  });

  final double previousExtent;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMaterializationShift(
      previousExtent,
      Scrollable.maybeOf(context)?.position,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    // One-shot: the baseline is only meaningful for the first layout after
    // the swap — never re-arm on rebuilds.
  }
}

class _RenderMaterializationShift extends RenderProxyBox {
  _RenderMaterializationShift(this._previousExtent, this._position);

  double? _previousExtent;
  final ScrollPosition? _position;

  @override
  void performLayout() {
    super.performLayout();
    final baseline = _previousExtent;
    if (baseline == null) return;
    _previousExtent = null;
    final position = _position;
    if (position == null) return;
    final delta = size.height - baseline;
    if (delta.abs() > 0.5) {
      AutoFollowScrollController.addPendingAdjustFor(position, delta);
    }
  }
}

/// Cancellable handle for a deferred materialization.
class DeferredContentEntry {
  DeferredContentEntry(this.cost, this._run);

  final int cost;
  final VoidCallback _run;
  bool _canceled = false;

  void cancel() => _canceled = true;
}

/// Materializes queued [DeferredContent] under a per-frame cost budget.
///
/// Each pump (post-frame) pops entries LIFO until the budget is spent; their
/// `setState`s schedule the next frame, whose post-frame callback pumps again
/// — so heavy blocks land one small batch per frame instead of all at once.
class DeferredContentScheduler {
  DeferredContentScheduler._();

  static final DeferredContentScheduler instance = DeferredContentScheduler._();

  /// Cost units (≈ source characters) materialized per frame. One ~3000-char
  /// markdown chunk parses + lays out in a few ms on-device; two per frame
  /// keeps the pump comfortably inside a 120Hz budget even mid-scroll.
  static const int _frameBudget = 6000;

  /// Reduced budget while the message list is actively scrolling — the frame
  /// budget belongs to the scroll first; queued content catches up at full
  /// speed as soon as the scroll ends.
  static const int _scrollingFrameBudget = 2000;

  final List<DeferredContentEntry> _stack = [];
  bool _pumpScheduled = false;
  bool _scrolling = false;

  /// Live scroll state of the hosting list. While true the pump runs under
  /// [_scrollingFrameBudget]; flipping back to false resumes any queued work.
  void setScrolling(bool value) {
    if (_scrolling == value) return;
    _scrolling = value;
    if (!value && _stack.isNotEmpty) _schedulePump();
  }

  DeferredContentEntry enqueue(int cost, VoidCallback run) {
    final entry = DeferredContentEntry(cost, run);
    _stack.add(entry);
    _schedulePump();
    return entry;
  }

  void _schedulePump() {
    if (_pumpScheduled) return;
    _pumpScheduled = true;
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      _pumpScheduled = false;
      _pump();
    });
    // A frame may not be scheduled (list idle after the entry settles).
    binding.scheduleFrame();
  }

  void _pump() {
    final budget = _scrolling ? _scrollingFrameBudget : _frameBudget;
    var used = 0;
    while (_stack.isNotEmpty && used < budget) {
      final entry = _stack.removeLast();
      if (entry._canceled) continue;
      used += entry.cost < 1 ? 1 : entry.cost;
      entry._run();
    }
    if (_stack.isNotEmpty) _schedulePump();
  }
}
