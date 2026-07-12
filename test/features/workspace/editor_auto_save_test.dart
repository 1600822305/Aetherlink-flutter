import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/application/editor_auto_save.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';

void main() {
  group('AutoSaveDebouncer', () {
    test('停顿满 delay 后触发一次', () {
      fakeAsync((async) {
        var fired = 0;
        final debouncer = AutoSaveDebouncer(
          delay: const Duration(seconds: 3),
          onFire: () => fired++,
        );
        debouncer.notifyEdit();
        async.elapse(const Duration(seconds: 2));
        expect(fired, 0);
        async.elapse(const Duration(seconds: 1));
        expect(fired, 1);
        async.elapse(const Duration(seconds: 10));
        expect(fired, 1);
        debouncer.dispose();
      });
    });

    test('连续编辑重置计时', () {
      fakeAsync((async) {
        var fired = 0;
        final debouncer = AutoSaveDebouncer(
          delay: const Duration(seconds: 3),
          onFire: () => fired++,
        );
        for (var i = 0; i < 5; i++) {
          debouncer.notifyEdit();
          async.elapse(const Duration(seconds: 2));
        }
        expect(fired, 0);
        async.elapse(const Duration(seconds: 1));
        expect(fired, 1);
        debouncer.dispose();
      });
    });

    test('cancel 后不触发', () {
      fakeAsync((async) {
        var fired = 0;
        final debouncer = AutoSaveDebouncer(
          delay: const Duration(seconds: 3),
          onFire: () => fired++,
        );
        debouncer.notifyEdit();
        expect(debouncer.isPending, isTrue);
        debouncer.cancel();
        expect(debouncer.isPending, isFalse);
        async.elapse(const Duration(seconds: 10));
        expect(fired, 0);
      });
    });
  });

  group('EditorSettings 自动保存字段', () {
    test('encode/decode 往返', () {
      const settings = EditorSettings(autoSave: true, autoSaveDelaySecs: 10);
      final decoded = EditorSettings.decode(settings.encode());
      expect(decoded, isNotNull);
      expect(decoded!.autoSave, isTrue);
      expect(decoded.autoSaveDelaySecs, 10);
    });

    test('缺省与非法档位回退默认', () {
      final legacy = EditorSettings.decode('{"fontSize": 14}');
      expect(legacy!.autoSave, isFalse);
      expect(legacy.autoSaveDelaySecs, kAutoSaveDefaultDelaySecs);

      final invalid = EditorSettings.decode(
        '{"autoSave": true, "autoSaveDelaySecs": 7}',
      );
      expect(invalid!.autoSaveDelaySecs, kAutoSaveDefaultDelaySecs);
    });
  });
}
