import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/memory/domain/memory_settings.dart';

const int _hour = 3600000;

void main() {
  group('shouldAutoConsolidate', () {
    test('never fires when memory is disabled', () {
      const s = MemorySettings(enabled: false, autoConsolidate: true);
      expect(shouldAutoConsolidate(s, 100 * _hour), isFalse);
    });

    test('never fires when auto-consolidation is off', () {
      const s = MemorySettings(enabled: true, autoConsolidate: false);
      expect(shouldAutoConsolidate(s, 100 * _hour), isFalse);
    });

    test('fires on the first run (never consolidated)', () {
      const s = MemorySettings(enabled: true, autoConsolidate: true);
      expect(shouldAutoConsolidate(s, 100 * _hour), isTrue);
    });

    test('waits until the interval has elapsed since the last run', () {
      const s = MemorySettings(
        enabled: true,
        autoConsolidate: true,
        autoConsolidateIntervalHours: 24,
        lastConsolidatedAt: 100 * _hour,
      );
      // 23h later → too soon.
      expect(shouldAutoConsolidate(s, 123 * _hour), isFalse);
      // Exactly 24h later → fires.
      expect(shouldAutoConsolidate(s, 124 * _hour), isTrue);
      // Well past → fires.
      expect(shouldAutoConsolidate(s, 200 * _hour), isTrue);
    });

    test('honours a custom interval', () {
      const s = MemorySettings(
        enabled: true,
        autoConsolidate: true,
        autoConsolidateIntervalHours: 6,
        lastConsolidatedAt: 10 * _hour,
      );
      expect(shouldAutoConsolidate(s, 15 * _hour), isFalse);
      expect(shouldAutoConsolidate(s, 16 * _hour), isTrue);
    });
  });
}
