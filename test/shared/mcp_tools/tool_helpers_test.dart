import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/shared/mcp_tools/tools/tool_helpers.dart';

void main() {
  group('cursor 分页', () {
    test('encodeCursor/decodeCursor 往返保留状态', () {
      final cursor = encodeCursor({'offset': 100, 'limit': 50});
      final state = decodeCursor(cursor);
      expect(state['offset'], 100);
      expect(state['limit'], 50);
    });

    test('cursor 为 base64url，不含 JSON 明文', () {
      final cursor = encodeCursor({'offset': 100, 'maxChars': 2000});
      expect(cursor, isNot(contains('offset')));
      expect(cursor, isNot(contains('{')));
      expect(cursor.trim(), isNotEmpty);
    });

    test('非法/空 cursor 返回空 map，调用方可回退到原始参数', () {
      expect(decodeCursor(null), isEmpty);
      expect(decodeCursor(''), isEmpty);
      expect(decodeCursor('   '), isEmpty);
      expect(decodeCursor('not-a-cursor!!'), isEmpty);
      expect(decodeCursor(123), isEmpty);
    });
  });

  group('locator 解析', () {
    test('解析 scheme:value', () {
      final loc = parseLocator('dex_class:com.foo.Bar');
      expect(loc, isNotNull);
      expect(loc!.scheme, 'dex_class');
      expect(loc.value, 'com.foo.Bar');
    });

    test('value 中含冒号时只按首个冒号切分', () {
      final loc = parseLocator('apk_file:res/values/strings.xml');
      expect(loc!.scheme, 'apk_file');
      expect(loc.value, 'res/values/strings.xml');
    });

    test('资源 ID locator 保留十六进制值', () {
      final loc = parseLocator('res:0x7f010000');
      expect(loc!.scheme, 'res');
      expect(loc.value, '0x7f010000');
    });

    test('缺少 scheme、空串或非字符串返回 null', () {
      expect(parseLocator(''), isNull);
      expect(parseLocator('com.foo.Bar'), isNull);
      expect(parseLocator(':value'), isNull);
      expect(parseLocator('scheme:'), isNull);
      expect(parseLocator(42), isNull);
    });
  });
}
