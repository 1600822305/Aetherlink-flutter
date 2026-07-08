import 'package:flutter/material.dart';

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
    if (_materialized) return widget.builder(context);
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

  final List<DeferredContentEntry> _stack = [];
  bool _pumpScheduled = false;

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
    var used = 0;
    while (_stack.isNotEmpty && used < _frameBudget) {
      final entry = _stack.removeLast();
      if (entry._canceled) continue;
      used += entry.cost < 1 ? 1 : entry.cost;
      entry._run();
    }
    if (_stack.isNotEmpty) _schedulePump();
  }
}
