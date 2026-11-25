import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';

/// The 世界书 entries a single request triggered (already priority-sorted).
/// [isEmpty] turns must leave the request byte-for-byte unchanged.
class WorldBookTurn {
  const WorldBookTurn(this.triggered);

  static const WorldBookTurn none = WorldBookTurn(<WorldBookEntry>[]);

  final List<WorldBookEntry> triggered;

  bool get isEmpty => triggered.isEmpty;
}
