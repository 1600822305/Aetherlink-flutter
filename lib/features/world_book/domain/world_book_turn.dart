import 'package:aetherlink_flutter/features/world_book/domain/world_book_activation_state.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';

/// The 世界书 entries a single request triggered (already priority-sorted),
/// plus the timer [state] that turn produced (P3; null when nothing is bound).
/// [isEmpty] turns must leave the request byte-for-byte unchanged.
class WorldBookTurn {
  const WorldBookTurn(this.triggered, {this.state});

  static const WorldBookTurn none = WorldBookTurn(<WorldBookEntry>[]);

  final List<WorldBookEntry> triggered;
  final WorldBookActivationState? state;

  bool get isEmpty => triggered.isEmpty;
}
