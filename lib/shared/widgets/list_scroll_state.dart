import 'package:aetherlink_perf/aetherlink_perf.dart';
import 'package:flutter/widgets.dart';

import 'package:aetherlink_flutter/shared/widgets/deferred_content.dart';

/// Forwards a host message list's scroll start/end to [PerfMonitor] and
/// [DeferredContentScheduler]. Only the list itself (depth 0) counts: nested
/// horizontal scrollables (code blocks, tables) bubble up too and would flip
/// the state mid-scroll.
void reportHostScrolling(ScrollNotification n) {
  if (n.depth != 0) return;
  if (n is ScrollStartNotification) {
    PerfMonitor.instance.setScrolling(true);
    DeferredContentScheduler.instance.setScrolling(true);
  } else if (n is ScrollEndNotification) {
    resetHostScrolling();
  }
}

/// Clears the scrolling state. Called when a host list is disposed: a list
/// torn down mid-scroll never delivers its ScrollEnd, which would leave the
/// global scheduler stuck on its reduced budget.
void resetHostScrolling() {
  PerfMonitor.instance.setScrolling(false);
  DeferredContentScheduler.instance.setScrolling(false);
}
