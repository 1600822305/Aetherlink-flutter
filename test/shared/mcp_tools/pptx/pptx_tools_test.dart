import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/chat/application/tools/tool_confirmation.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_routes.dart';
import 'package:aetherlink_flutter/shared/config/builtin_mcp_servers.dart';
import 'package:aetherlink_flutter/shared/config/builtin_skills.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/builtin_tool_catalog.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/pptx/pptx_tools.dart';

/// 两页 deck：第 0 页两个元素，第 1 页一个。
Map<String, Object?> sampleDeck() => {
      'title': '原标题',
      'style': 'dark_tech',
      'slides': [
        {
          'elements': [
            {'type': 'text', 'text': 'a0'},
            {'type': 'text', 'text': 'a1'},
          ],
        },
        {
          'elements': [
            {'type': 'text', 'text': 'b0'},
          ],
        },
      ],
    };

List<Object?> slidesOf(Map<String, Object?> deck) =>
    deck['slides']! as List<Object?>;

List<Object?> elementsOf(Map<String, Object?> deck, int slide) =>
    (slidesOf(deck)[slide]! as Map)['elements']! as List<Object?>;

Object? textAt(Map<String, Object?> deck, int slide, int index) =>
    (elementsOf(deck, slide)[index]! as Map)['text'];

void main() {
  group('@aether/pptx 目录注册', () {
    test('内置服务器目录包含 @aether/pptx 且归类为 ref-dependent', () {
      expect(kBuiltinMcpServers.any((s) => s.name == kPptxServerName), isTrue);
      expect(kRefDependentBuiltins.contains(kPptxServerName), isTrue);
      expect(kLocallyRunnableBuiltins.contains(kPptxServerName), isFalse);
    });

    test('静态工具目录暴露 pptx_read / pptx_check / pptx_render', () {
      final names = builtinToolsFor(kPptxServerName).map((t) => t.name);
      expect(names, containsAll(['pptx_read', 'pptx_check', 'pptx_render']));
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

    test('pptx_check/pptx_read 只读、pptx_render 非只读（并发安全分类）', () {
      expect(toolRouteIsReadOnly(const PptxToolRoute('pptx_check')), isTrue);
      expect(toolRouteIsReadOnly(const PptxToolRoute('pptx_read')), isTrue);
      expect(toolRouteIsReadOnly(const PptxToolRoute('pptx_render')), isFalse);
    });

    test('M6：pptx_outline 只读、pptx_modify 非只读', () {
      expect(toolRouteIsReadOnly(const PptxToolRoute('pptx_outline')), isTrue);
      expect(toolRouteIsReadOnly(const PptxToolRoute('pptx_modify')), isFalse);
    });
  });

  group('M6 工具注册与审批（pptx_outline / pptx_modify）', () {
    test('静态目录暴露两个新工具且 schema 必填项正确', () {
      final tools = builtinToolsFor(kPptxServerName);
      final names = tools.map((t) => t.name);
      expect(names, containsAll(['pptx_outline', 'pptx_modify']));

      final outline = tools.firstWhere((t) => t.name == 'pptx_outline');
      expect(outline.inputSchema['required'], ['path']);

      final modify = tools.firstWhere((t) => t.name == 'pptx_modify');
      expect(modify.inputSchema['required'], ['path', 'ops']);
      final props = modify.inputSchema['properties']! as Map;
      final opEnum =
          (((props['ops']! as Map)['items']! as Map)['properties']! as Map)['op']!
              as Map;
      expect(
        opEnum['enum'],
        containsAll([
          'set_text',
          'replace_text',
          'set_notes',
          'replace_image',
          'duplicate_slide',
          'delete_slide',
          'move_slide',
        ]),
      );
    });

    test('pptx_outline 免审批', () {
      expect(
        toolNeedsConfirmation(
          const PptxToolRoute('pptx_outline'),
          'pptx_outline',
          const {'path': 'a.pptx'},
        ),
        isFalse,
      );
    });

    test('pptx_modify 原地覆盖要确认，另存到新路径免确认', () {
      bool needs(Map<String, Object?> args) => toolNeedsConfirmation(
        const PptxToolRoute('pptx_modify'),
        'pptx_modify',
        args,
      );

      // 没有 output → 原地改写用户文件
      expect(needs(const {'path': 'a.pptx'}), isTrue);
      // output 指回自己 → 仍是原地改写
      expect(needs(const {'path': 'a.pptx', 'output': 'a.pptx'}), isTrue);
      expect(needs(const {'path': 'a.pptx', 'output': '  a.pptx  '}), isTrue);
      // 另存新文件 → 等同产出新文件，免确认
      expect(needs(const {'path': 'a.pptx', 'output': 'b.pptx'}), isFalse);
      // 空 output 视同没传
      expect(needs(const {'path': 'a.pptx', 'output': '   '}), isTrue);
    });

    test('pptxToolNeedsConfirmation 对其他 pptx 工具一律 false', () {
      for (final name in const [
        'pptx_check',
        'pptx_read',
        'pptx_render',
        'pptx_edit',
        'pptx_styles',
        'pptx_outline',
        'pptx_illustrate',
      ]) {
        expect(
          pptxToolNeedsConfirmation(name, const {'path': 'a.pptx'}),
          isFalse,
          reason: '$name 不该要求确认',
        );
      }
    });
  });

  group('applyDeckEditOp — 幻灯片级操作', () {
    test('set_meta 只改传入的字段，未传的保持不变', () {
      final out = applyDeckEditOp(
        sampleDeck(),
        {'op': 'set_meta', 'title': '新标题'},
        'ops[0]',
      );
      expect(out['title'], '新标题');
      expect(out['style'], 'dark_tech');
      expect(slidesOf(out), hasLength(2));
    });

    test('set_slide 整页替换', () {
      final out = applyDeckEditOp(
        sampleDeck(),
        {
          'op': 'set_slide',
          'index': 1,
          'slide': {'elements': <Object?>[]},
        },
        'ops[0]',
      );
      expect(slidesOf(out), hasLength(2));
      expect(elementsOf(out, 1), isEmpty);
      expect(textAt(out, 0, 0), 'a0');
    });

    test('insert_slide 按 index 插入；省略 index 时追加到末尾', () {
      final inserted = applyDeckEditOp(
        sampleDeck(),
        {
          'op': 'insert_slide',
          'index': 0,
          'slide': {
            'elements': [
              {'type': 'text', 'text': 'new'},
            ],
          },
        },
        'ops[0]',
      );
      expect(slidesOf(inserted), hasLength(3));
      expect(textAt(inserted, 0, 0), 'new');
      expect(textAt(inserted, 1, 0), 'a0');

      final appended = applyDeckEditOp(
        sampleDeck(),
        {
          'op': 'insert_slide',
          'slide': {
            'elements': [
              {'type': 'text', 'text': 'tail'},
            ],
          },
        },
        'ops[0]',
      );
      expect(slidesOf(appended), hasLength(3));
      expect(textAt(appended, 2, 0), 'tail');
    });

    test('insert_slide 允许 index == 页数（末尾），超过则报错', () {
      expect(
        slidesOf(
          applyDeckEditOp(
            sampleDeck(),
            {'op': 'insert_slide', 'index': 2, 'slide': <String, Object?>{}},
            'ops[0]',
          ),
        ),
        hasLength(3),
      );
      expect(
        () => applyDeckEditOp(
          sampleDeck(),
          {'op': 'insert_slide', 'index': 3, 'slide': <String, Object?>{}},
          'ops[0]',
        ),
        throwsA(isA<FileEditorError>()),
      );
    });

    test('remove_slide 删除指定页', () {
      final out = applyDeckEditOp(
        sampleDeck(),
        {'op': 'remove_slide', 'index': 0},
        'ops[0]',
      );
      expect(slidesOf(out), hasLength(1));
      expect(textAt(out, 0, 0), 'b0');
    });

    test('move_slide 把页从 from 挪到 to', () {
      final out = applyDeckEditOp(
        sampleDeck(),
        {'op': 'move_slide', 'from': 0, 'to': 1},
        'ops[0]',
      );
      expect(slidesOf(out), hasLength(2));
      expect(textAt(out, 0, 0), 'b0');
      expect(textAt(out, 1, 0), 'a0');
    });
  });

  group('applyDeckEditOp — 元素级操作', () {
    test('set_element 替换指定元素', () {
      final out = applyDeckEditOp(
        sampleDeck(),
        {
          'op': 'set_element',
          'slide': 0,
          'index': 1,
          'element': {'type': 'text', 'text': 'replaced'},
        },
        'ops[0]',
      );
      expect(elementsOf(out, 0), hasLength(2));
      expect(textAt(out, 0, 0), 'a0');
      expect(textAt(out, 0, 1), 'replaced');
    });

    test('append_element 追加到该页末尾', () {
      final out = applyDeckEditOp(
        sampleDeck(),
        {
          'op': 'append_element',
          'slide': 1,
          'element': {'type': 'text', 'text': 'added'},
        },
        'ops[0]',
      );
      expect(elementsOf(out, 1), hasLength(2));
      expect(textAt(out, 1, 1), 'added');
      expect(elementsOf(out, 0), hasLength(2));
    });

    test('remove_element 删除指定元素', () {
      final out = applyDeckEditOp(
        sampleDeck(),
        {'op': 'remove_element', 'slide': 0, 'index': 0},
        'ops[0]',
      );
      expect(elementsOf(out, 0), hasLength(1));
      expect(textAt(out, 0, 0), 'a1');
    });
  });

  group('applyDeckEditOp — 校验与不可变性', () {
    test('未知 op 报错并列出支持的操作', () {
      expect(
        () => applyDeckEditOp(sampleDeck(), {'op': 'frobnicate'}, 'ops[2]'),
        throwsA(
          isA<FileEditorError>().having(
            (e) => e.message,
            'message',
            allOf(contains('ops[2]'), contains('append_element')),
          ),
        ),
      );
    });

    test('越界 / 非整数索引报错，消息带上 op 位置与合法范围', () {
      for (final op in <Map<String, Object?>>[
        {'op': 'set_slide', 'index': 2, 'slide': <String, Object?>{}},
        {'op': 'remove_slide', 'index': -1},
        {'op': 'remove_slide', 'index': '0'},
        {'op': 'move_slide', 'from': 0, 'to': 5},
        {'op': 'set_element', 'slide': 0, 'index': 9, 'element': null},
        {'op': 'append_element', 'slide': 7, 'element': null},
        {'op': 'remove_element', 'slide': 0, 'index': 2},
      ]) {
        expect(
          () => applyDeckEditOp(sampleDeck(), op, 'ops[1]'),
          throwsA(
            isA<FileEditorError>().having(
              (e) => e.message,
              'message',
              contains('ops[1]'),
            ),
          ),
          reason: 'op ${op['op']} 的越界索引应当被拒绝',
        );
      }
    });

    test('不修改传入的 deck（失败的 op 也不留下半成品）', () {
      final deck = sampleDeck();
      applyDeckEditOp(deck, {'op': 'remove_slide', 'index': 0}, 'ops[0]');
      applyDeckEditOp(
        deck,
        {
          'op': 'append_element',
          'slide': 0,
          'element': {'type': 'text', 'text': 'x'},
        },
        'ops[1]',
      );
      expect(deck, sampleDeck());
    });

    test('多条 op 依次施加，效果累积', () {
      var deck = sampleDeck();
      for (final op in <Map<String, Object?>>[
        {'op': 'set_meta', 'title': 'T'},
        {'op': 'remove_slide', 'index': 1},
        {
          'op': 'append_element',
          'slide': 0,
          'element': {'type': 'text', 'text': 'z'},
        },
      ]) {
        deck = applyDeckEditOp(deck, op, 'ops[?]');
      }
      expect(deck['title'], 'T');
      expect(slidesOf(deck), hasLength(1));
      expect(elementsOf(deck, 0), hasLength(3));
      expect(textAt(deck, 0, 2), 'z');
    });
  });
}
