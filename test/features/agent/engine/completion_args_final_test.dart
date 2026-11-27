import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/engine/loop/finish_result_streamer.dart';

void main() {
  group('completionArgsFinal', () {
    test('完整参数且 result 非空 → 已定稿', () {
      expect(completionArgsFinal('{"result":"做完了","summary":"x"}'), isTrue);
      expect(completionArgsFinal('{"result":"ok"}\n  '), isTrue);
    });

    test('流式中的半截参数 → 未定稿', () {
      expect(completionArgsFinal('{"result":"做完'), isFalse);
      expect(completionArgsFinal('{"result":"a}b'), isFalse);
      expect(completionArgsFinal('{"result":"x", "summary":"y'), isFalse);
    });

    test('result 缺失 / 为空 / 非字符串 → 未定稿（引擎会拒绝）', () {
      expect(completionArgsFinal('{"summary":"x"}'), isFalse);
      expect(completionArgsFinal('{"result":"   "}'), isFalse);
      expect(completionArgsFinal('{"result":1}'), isFalse);
    });

    test('null / 非对象 / 非法 JSON → 未定稿', () {
      expect(completionArgsFinal(null), isFalse);
      expect(completionArgsFinal('[1]'), isFalse);
      expect(completionArgsFinal('{oops}'), isFalse);
    });
  });
}
