import 'package:aetherlink_flutter/features/world_book/domain/world_book_activation_state.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';

/// The 世界书 entries a single request triggered (already priority-sorted),
/// plus the timer [state] that turn produced (P3; null when nothing is bound).
/// [isEmpty] turns must leave the request byte-for-byte unchanged.
///
/// [reasons] 与 [triggered] 一一对应，是每条的激活原因（可能为空列表，例如
/// 测试里手工构造的 turn）。
class WorldBookTurn {
  const WorldBookTurn(
    this.triggered, {
    this.state,
    this.reasons = const <String>[],
  });

  static const WorldBookTurn none = WorldBookTurn(<WorldBookEntry>[]);

  final List<WorldBookEntry> triggered;
  final WorldBookActivationState? state;
  final List<String> reasons;

  /// 第 [i] 条的激活原因，没有时为空串。
  String reasonAt(int i) => i < reasons.length ? reasons[i] : '';

  bool get isEmpty => triggered.isEmpty;
}
