import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/deferred_content.dart';

/// Defers a whole message row's first build behind a skeleton bubble.
///
/// Row-count windowing and in-bubble [DeferredContent] still leave one cost
/// on the entry frame: assembling the bubble chrome + parsing its (possibly
/// many) blocks — a single multi-round tool-call message can blow the frame
/// budget alone. Heavy *terminal* rows therefore mount as a fixed-height
/// skeleton and are swapped in by [DeferredContentScheduler] over the next
/// frames (LIFO — rows near the viewport first). Streaming / cheap rows
/// build inline so live output and short chats never flash a skeleton.
/// `KeepAliveItem` keeps materialized rows alive, so this only ever happens
/// on the row's first mount (topic entry / history reveal).
class DeferredBubble extends ConsumerStatefulWidget {
  const DeferredBubble({super.key, required this.rowIds, required this.child});

  final List<String> rowIds;
  final Widget child;

  /// Rows costing at most this (≈ source characters) build inline.
  static const int _inlineCostThreshold = 2000;

  @override
  ConsumerState<DeferredBubble> createState() => _DeferredBubbleState();
}

class _DeferredBubbleState extends ConsumerState<DeferredBubble> {
  bool _materialized = false;
  DeferredContentEntry? _entry;
  double? _compensateFrom;
  double _estimatedHeight = 120;

  @override
  void initState() {
    super.initState();
    final state = ref.read(chatControllerProvider);
    var cost = 0;
    var terminal = true;
    for (final id in widget.rowIds) {
      final view = state.messageById(id);
      if (view == null) continue;
      if (view.status != MessageStatus.success &&
          view.status != MessageStatus.error) {
        terminal = false;
        break;
      }
      cost +=
          view.text.length + view.thinking.length + view.blocks.length * 300;
    }
    if (!terminal || cost <= DeferredBubble._inlineCostThreshold) {
      _materialized = true;
      return;
    }
    _estimatedHeight = (cost * 0.5).clamp(120.0, 2000.0);
    // The bubble's own build is cheap once its heavy content re-defers
    // internally (chunked markdown / code placeholders) — enqueue at a capped
    // cost so a giant bubble doesn't starve the scheduler for many frames.
    _entry = DeferredContentScheduler.instance.enqueue(
      math.min(cost, 3000),
      _materialize,
    );
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
      if (baseline == null) return widget.child;
      return MaterializationShift(
        previousExtent: baseline,
        child: widget.child,
      );
    }
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Container(
        width: double.infinity,
        height: _estimatedHeight,
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
