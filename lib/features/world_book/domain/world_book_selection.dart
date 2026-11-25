import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_activation.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';

/// Timer-free activation (世界书注入 P2): an entry triggers when it is enabled,
/// has content and is either constant or matches a keyword within its
/// `scanDepth` newest [scanTexts]. `sticky` / `cooldown` / `delay` are not
/// evaluated yet (P3), so a matching entry always triggers.
///
/// [scanTexts] are the conversation's user / assistant texts, oldest first, one
/// per rendered view. Result order matches [WorldBookActivation.evaluate]:
/// priority descending, then book order, then entry order.
List<WorldBookEntry> selectTriggeredWorldBookEntries({
  required List<WorldBook> books,
  required List<String> scanTexts,
}) {
  final texts = [
    for (final text in scanTexts)
      if (text.trim().isNotEmpty) text.trim(),
  ];
  final contextCache = <int, String>{};
  String contextFor(int depth) => contextCache.putIfAbsent(depth, () {
    final start = texts.length > depth ? texts.length - depth : 0;
    return texts.sublist(start).join('\n');
  });

  final triggered = <({WorldBookEntry entry, int seq})>[];
  var seq = 0;
  for (final book in books) {
    if (!book.enabled) continue;
    for (final entry in book.entries) {
      final order = seq++;
      if (!entry.enabled || entry.content.trim().isEmpty) continue;
      final depth = entry.scanDepth.clamp(1, WorldBookEntry.kMaxDepth);
      if (WorldBookActivation.matches(entry, contextFor(depth))) {
        triggered.add((entry: entry, seq: order));
      }
    }
  }
  triggered.sort((a, b) {
    final priority = b.entry.priority.compareTo(a.entry.priority);
    return priority != 0 ? priority : a.seq.compareTo(b.seq);
  });
  return [for (final item in triggered) item.entry];
}
