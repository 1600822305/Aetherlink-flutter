import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/presentation/mobile/workbench/workbench_focus_tab.dart';

void main() {
  group('cleanTerminalText', () {
    test('去掉 SGR 颜色 / 光标控制序列', () {
      expect(
        cleanTerminalText('\x1b[1;32mok\x1b[0m \x1b[2Kdone\x1b[?25h'),
        'ok done',
      );
    });

    test('去掉 OSC（标题 / 超链接）序列', () {
      expect(
        cleanTerminalText('\x1b]0;title\x07a\x1b]8;;http://x\x1b\\link\x1b]8;;\x1b\\'),
        'alink',
      );
    });

    test('进度条 \\r 覆盖只保留最后一段，\\r\\n 当普通换行', () {
      expect(
        cleanTerminalText('10%\r50%\r100% done\r\nnext\r\n'),
        '100% done\nnext\n',
      );
    });

    test('普通文本原样保留', () {
      expect(cleanTerminalText('\$ ls\nfile_a\n中文.txt'), '\$ ls\nfile_a\n中文.txt');
    });
  });
}
