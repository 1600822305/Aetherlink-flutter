import 'dart:math';

final Random _random = Random();

/// Generates a reasonably-unique id without a third-party dependency.
///
/// Combines a microsecond timestamp with random entropy (both base-36) so ids
/// minted within the same microsecond still differ. Format:
/// `<prefix>-<microseconds>-<random>`.
String generateId([String prefix = 'id']) {
  final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final entropy = _random.nextInt(1 << 32).toRadixString(36);
  return '$prefix-$timestamp-$entropy';
}
