import 'package:aetherlink_perf/aetherlink_perf.dart';
import 'package:aetherlink_perf/src/context_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PerfContextLog', () {
    test('returns the context live at a timestamp', () {
      final log = PerfContextLog()
        ..record(0, const PerfContext(route: '/chat'))
        ..record(100, const PerfContext(route: '/chat', streaming: true))
        ..record(200, const PerfContext(route: '/agent'));
      expect(log.at(50).route, '/chat');
      expect(log.at(50).streaming, isFalse);
      expect(log.at(100).streaming, isTrue);
      expect(log.at(199).streaming, isTrue);
      expect(log.at(500).route, '/agent');
    });

    test('timestamps before the history fall back to the oldest entry', () {
      final log = PerfContextLog()..record(100, const PerfContext(route: '/a'));
      expect(log.at(0).route, '/a');
      expect(PerfContextLog().at(0).route, isNull);
    });

    test('skips repeats and caps its size', () {
      final log = PerfContextLog(capacity: 2)
        ..record(0, const PerfContext(messages: 1))
        ..record(1, const PerfContext(messages: 1));
      expect(log.length, 1);
      log
        ..record(2, const PerfContext(messages: 2))
        ..record(3, const PerfContext(messages: 3));
      expect(log.length, 2);
      expect(log.at(0).messages, 2);
    });
  });

  group('PerfMonitor context', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final monitor = PerfMonitor.instance;

    tearDown(monitor.stop);

    test('updates are kept while stopped', () {
      monitor
        ..setRoute('/chat')
        ..setStreaming(true);
      expect(monitor.isRunning, isFalse);
      expect(monitor.context.route, '/chat');
      expect(monitor.context.streaming, isTrue);
      monitor.start();
      expect(monitor.context.route, '/chat');
    });

    test('stop clears the context', () {
      monitor
        ..start()
        ..setRoute('/agent')
        ..setMessages(3)
        ..stop();
      expect(monitor.context.route, isNull);
      expect(monitor.context.messages, isNull);
    });
  });
}
