import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/chat/application/tools/tool_confirmation.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_routes.dart';
import 'package:aetherlink_flutter/shared/config/builtin_mcp_servers.dart';
import 'package:aetherlink_flutter/shared/config/builtin_skills.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/builtin_tool_catalog.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/pptx/pptx_tools.dart';

void main() {
  group('@aether/pptx 目录注册', () {
    test('内置服务器目录包含 @aether/pptx 且归类为 ref-dependent', () {
      expect(kBuiltinMcpServers.any((s) => s.name == kPptxServerName), isTrue);
      expect(kRefDependentBuiltins.contains(kPptxServerName), isTrue);
      expect(kLocallyRunnableBuiltins.contains(kPptxServerName), isFalse);
    });

    test('静态工具目录暴露 pptx_check 与 pptx_render', () {
      final names = builtinToolsFor(kPptxServerName).map((t) => t.name);
      expect(names, containsAll(['pptx_check', 'pptx_render']));
      for (final tool in builtinToolsFor(kPptxServerName)) {
        expect(tool.inputSchema['type'], 'object');
      }
    });

    test('内置技能目录包含 PPT 设计师', () {
      expect(kBuiltinSkills.any((s) => s.id == 'builtin-ppt-designer'), isTrue);
    });
  });

  group('@aether/pptx 审批与只读分类', () {
    test('pptx_render 与 pptx_check 都免审批', () {
      expect(
        toolNeedsConfirmation(
          const PptxToolRoute('pptx_render'),
          'pptx_render',
          const {},
        ),
        isFalse,
      );
      expect(
        toolNeedsConfirmation(
          const PptxToolRoute('pptx_check'),
          'pptx_check',
          const {},
        ),
        isFalse,
      );
    });

    test('pptx_check 只读、pptx_render 非只读（并发安全分类）', () {
      expect(toolRouteIsReadOnly(const PptxToolRoute('pptx_check')), isTrue);
      expect(toolRouteIsReadOnly(const PptxToolRoute('pptx_render')), isFalse);
    });
  });
}
