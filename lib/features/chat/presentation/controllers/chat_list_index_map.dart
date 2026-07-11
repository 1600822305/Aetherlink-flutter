/// Pure index arithmetic between the conversation's *row space* and the
/// message [ListView]'s *item space*, for both list orientations.
///
/// Terminology:
/// * **row index** — position in the full conversation rows (0 = oldest
///   message row, `totalRows - 1` = newest). Stable across history reveals.
/// * **list index** — the `itemBuilder` index of the (windowed) [ListView],
///   which also contains one optional *edge item* (the history-loading
///   spinner or the system-prompt bubble) at the conversation's visual top.
///
/// In the forward orientation ([reverse] = false) list index 0 is the visual
/// top (oldest visible row, after the edge item). In the reverse orientation
/// list index 0 is the visual bottom (newest row) and the edge item sits at
/// the highest list index. Centralizing the conversion here keeps every
/// call site (item builder, 对话导航, mini-map jumps, observer results)
/// orientation-agnostic.
class ChatListIndexMap {
  const ChatListIndexMap({
    required this.totalRows,
    required this.hiddenRows,
    required this.edgeCount,
    this.reverse = false,
  }) : assert(totalRows >= 0),
       assert(hiddenRows >= 0 && hiddenRows <= totalRows),
       assert(edgeCount == 0 || edgeCount == 1);

  /// Total conversation rows (hidden history included).
  final int totalRows;

  /// Leading (oldest) rows currently outside the rendered window.
  final int hiddenRows;

  /// Edge items at the conversation's visual top: the history-loading
  /// spinner *or* the system-prompt bubble (mutually exclusive, so 0 or 1).
  final int edgeCount;

  /// Whether the [ListView] renders with `reverse: true` (list index 0 at
  /// the visual bottom).
  final bool reverse;

  /// Rows actually rendered by the list.
  int get visibleRows => totalRows - hiddenRows;

  /// The [ListView]'s `itemCount`.
  int get itemCount => visibleRows + edgeCount;

  /// Whether [listIndex] is the edge item (spinner / prompt bubble).
  bool isEdge(int listIndex) {
    if (edgeCount == 0) return false;
    return reverse ? listIndex >= visibleRows : listIndex < edgeCount;
  }

  /// Row index (full-conversation space) rendered at [listIndex].
  /// Only valid when `isEdge(listIndex)` is false.
  int rowOfListIndex(int listIndex) => reverse
      ? totalRows - 1 - listIndex
      : listIndex - edgeCount + hiddenRows;

  /// List index rendering [rowIndex]. Only valid for visible rows
  /// (`rowIndex >= hiddenRows`).
  int listIndexOfRow(int rowIndex) =>
      reverse ? totalRows - 1 - rowIndex : rowIndex - hiddenRows + edgeCount;

  /// Whether [rowIndex] is the newest (visual bottom) conversation row.
  bool isNewestRow(int rowIndex) => rowIndex == totalRows - 1;
}
