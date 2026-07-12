import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_tools.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/tool_auth_policy.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/terminal/terminal_tools.dart';

void main() {
  group('kToolAuthCatalog', () {
    test('覆盖 file-editor 全部写工具与终端命令工具', () {
      final fileEditorNames = kToolAuthCatalog
          .where((m) => m.server == kFileEditorServerName)
          .map((m) => m.name)
          .toSet();
      for (final name in fileEditorNames) {
        expect(fileEditorNeedsConfirmation(name), isTrue,
            reason: '$name 应是需审批的写工具');
      }
      expect(fileEditorNames.length, 6);

      final terminalNames = kToolAuthCatalog
          .where((m) => m.server == kTerminalServerName)
          .map((m) => m.name)
          .toSet();
      expect(terminalNames, {'terminal_execute', 'terminal_session'});
    });

    test('key 全局唯一', () {
      final keys = kToolAuthCatalog.map((m) => m.key).toSet();
      expect(keys.length, kToolAuthCatalog.length);
    });
  });

  group('ToolAuthPolicy', () {
    test('withTool 开关与查询', () {
      const empty = ToolAuthPolicy();
      expect(empty.isAutoApproved(kFileEditorServerName, 'delete_file'),
          isFalse);

      final on = empty.withTool(kFileEditorServerName, 'delete_file',
          autoApprove: true);
      expect(on.isAutoApproved(kFileEditorServerName, 'delete_file'), isTrue);
      // 同名工具不跨 server 生效。
      expect(on.isAutoApproved(kTerminalServerName, 'delete_file'), isFalse);

      final off = on.withTool(kFileEditorServerName, 'delete_file',
          autoApprove: false);
      expect(off.isAutoApproved(kFileEditorServerName, 'delete_file'),
          isFalse);
    });

    test('encode/decode 往返', () {
      final policy = const ToolAuthPolicy()
          .withTool(kFileEditorServerName, 'write', autoApprove: true)
          .withTool(kTerminalServerName, 'terminal_execute',
              autoApprove: true);
      final decoded = ToolAuthPolicy.decode(policy.encode());
      expect(decoded, isNotNull);
      expect(decoded!.isAutoApproved(kFileEditorServerName, 'write'),
          isTrue);
      expect(decoded.isAutoApproved(kTerminalServerName, 'terminal_execute'),
          isTrue);
      expect(decoded.isAutoApproved(kFileEditorServerName, 'delete_file'),
          isFalse);
    });

    test('decode 丢弃未知/非法条目', () {
      final decoded = ToolAuthPolicy.decode(
        '["$kFileEditorServerName::write", "bogus::tool", 42]',
      );
      expect(decoded, isNotNull);
      expect(decoded!.autoApproved,
          {'$kFileEditorServerName::write'});

      expect(ToolAuthPolicy.decode(null), isNull);
      expect(ToolAuthPolicy.decode(''), isNull);
      expect(ToolAuthPolicy.decode('not json'), isNull);
      expect(ToolAuthPolicy.decode('{"a":1}'), isNull);
    });
  });
}
