import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_file_watch.dart';

void main() {
  group('mergeAgentFileChangeKinds', () {
    test('新建后删除抵消（null 不触发）', () {
      expect(mergeAgentFileChangeKinds('created', 'deleted'), isNull);
    });

    test('新建后修改仍算新建', () {
      expect(mergeAgentFileChangeKinds('created', 'modified'), 'created');
      expect(mergeAgentFileChangeKinds('created', 'created'), 'created');
    });

    test('其余取末次类型', () {
      expect(mergeAgentFileChangeKinds('modified', 'deleted'), 'deleted');
      expect(mergeAgentFileChangeKinds('modified', 'modified'), 'modified');
      expect(mergeAgentFileChangeKinds('moved', 'modified'), 'modified');
    });
  });

  group('AgentFileChangeDebouncer', () {
    final t0 = DateTime(2026, 1, 1);

    test('静默窗口内不吐出，到期后吐出并移除', () {
      final debouncer = AgentFileChangeDebouncer(
        quietWindow: const Duration(seconds: 1),
      );
      debouncer.add('a.dart', 'modified', t0);
      expect(
        debouncer.flushDue(t0.add(const Duration(milliseconds: 500))),
        isEmpty,
      );
      final due = debouncer.flushDue(t0.add(const Duration(seconds: 1)));
      expect(due.single.path, 'a.dart');
      expect(due.single.kind, 'modified');
      expect(debouncer.isEmpty, isTrue);
    });

    test('同路径事件合并且重置静默计时', () {
      final debouncer = AgentFileChangeDebouncer(
        quietWindow: const Duration(seconds: 1),
      );
      debouncer.add('a.dart', 'created', t0);
      debouncer.add(
        'a.dart',
        'modified',
        t0.add(const Duration(milliseconds: 800)),
      );
      // 第二条重置了计时：距首条 1s 时还未到期。
      expect(debouncer.flushDue(t0.add(const Duration(seconds: 1))), isEmpty);
      final due = debouncer.flushDue(
        t0.add(const Duration(milliseconds: 1800)),
      );
      expect(due.single.kind, 'created');
    });

    test('新建后即删除的条目静默移除不触发', () {
      final debouncer = AgentFileChangeDebouncer(
        quietWindow: const Duration(seconds: 1),
      );
      debouncer.add('tmp.txt', 'created', t0);
      debouncer.add('tmp.txt', 'deleted', t0);
      expect(debouncer.flushDue(t0.add(const Duration(seconds: 2))), isEmpty);
      expect(debouncer.isEmpty, isTrue);
    });

    test('多路径独立去抖', () {
      final debouncer = AgentFileChangeDebouncer(
        quietWindow: const Duration(seconds: 1),
      );
      debouncer.add('a.dart', 'modified', t0);
      debouncer.add(
        'b.dart',
        'deleted',
        t0.add(const Duration(milliseconds: 900)),
      );
      final due = debouncer.flushDue(t0.add(const Duration(seconds: 1)));
      expect(due.single.path, 'a.dart');
      expect(debouncer.isEmpty, isFalse);
    });
  });
}
