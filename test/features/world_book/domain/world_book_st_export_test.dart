// SillyTavern World Info 导出（world_book_st_export.dart）：
// - 与 parseWorldBookImport 的 ST 分支互逆：导出再导入，名称 / 内容 / 关键词 /
//   位置 / 深度 / 角色 / 优先级 / 条目顺序都还原；
// - priority → order 反映射（含正优先级平移）；
// - 聊天顶部 / 底部、正则、计时器、混合角色、@@ 装饰器、整本关闭的降级统计。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_import.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_st_export.dart';

Map<String, dynamic> _decode(WorldBookStExport e) =>
    (jsonDecode(e.json) as Map).cast<String, dynamic>();

Map<String, dynamic> _stEntries(WorldBookStExport e) =>
    (_decode(e)['entries'] as Map).cast<String, dynamic>();

WorldBook _reimport(WorldBookStExport e) =>
    parseWorldBookImport(jsonDecode(e.json), fileName: 'x.json')!.book;

void main() {
  test('导出再导入：支持的字段与条目顺序无损还原', () {
    const book = WorldBook(
      id: 'wb',
      name: '山海世界',
      description: '描述',
      entries: [
        WorldBookEntry(
          id: 'a',
          name: '基础设定',
          content: '常驻内容',
          constantActive: true,
          priority: -100,
          position: WorldBookInjectionPosition.beforeSystemPrompt,
        ),
        WorldBookEntry(
          id: 'b',
          name: '龙',
          content: '山里住着龙。',
          keywords: ['龙', '山'],
          priority: -100,
          caseSensitive: true,
          scanDepth: 6,
        ),
        WorldBookEntry(
          id: 'c',
          name: '深度条目',
          content: '插在倒数第 3 条',
          keywords: ['旅店'],
          priority: -250,
          position: WorldBookInjectionPosition.atDepth,
          injectDepth: 3,
          role: WorldBookInjectionRole.user,
        ),
        WorldBookEntry(
          id: 'd',
          name: '已关闭',
          content: '关',
          keywords: ['关'],
          enabled: false,
          priority: -50,
        ),
      ],
    );

    final exported = encodeWorldBookStExport(book);
    expect(exported.issues, isEmpty);

    final back = _reimport(exported);
    expect(back.name, '山海世界');
    expect(back.description, '描述');
    expect(back.entries.map((e) => e.name), ['基础设定', '龙', '深度条目', '已关闭']);

    for (var i = 0; i < book.entries.length; i++) {
      final a = book.entries[i];
      final b = back.entries[i];
      expect(b.content, a.content, reason: a.name);
      expect(b.keywords, a.keywords, reason: a.name);
      expect(b.constantActive, a.constantActive, reason: a.name);
      expect(b.enabled, a.enabled, reason: a.name);
      expect(b.priority, a.priority, reason: a.name);
      expect(b.position, a.position, reason: a.name);
      expect(b.caseSensitive, a.caseSensitive, reason: a.name);
    }
    expect(back.entries[1].scanDepth, 6);
    expect(back.entries[2].injectDepth, 3);
    expect(back.entries[2].role, WorldBookInjectionRole.user);
  });

  test('ST 导入 → 导出：order 原样回写', () {
    final parsed = parseWorldBookImport(
      jsonDecode(
        jsonEncode({
          'entries': {
            '0': {
              'uid': 0,
              'key': ['a'],
              'content': 'A',
              'comment': 'A',
              'order': 300,
              'position': 1,
            },
            '1': {
              'uid': 1,
              'key': ['b'],
              'content': 'B',
              'comment': 'B',
              'order': 100,
              'position': 0,
            },
          },
        }),
      ),
      fileName: 'st.json',
    )!;
    final entries = _stEntries(encodeWorldBookStExport(parsed.book));
    final byComment = {
      for (final v in entries.values)
        (v as Map)['comment'] as String: v['order'] as int,
    };
    expect(byComment, {'A': 300, 'B': 100});
  });

  test('正优先级整体平移，order 不为负且保持相对顺序', () {
    const book = WorldBook(
      id: 'wb',
      entries: [
        WorldBookEntry(id: 'hi', name: 'hi', content: 'x', priority: 10),
        WorldBookEntry(id: 'mid', name: 'mid', content: 'x', priority: 0),
        WorldBookEntry(id: 'lo', name: 'lo', content: 'x', priority: -5),
      ],
    );
    final exported = encodeWorldBookStExport(book);
    final orders = {
      for (final v in _stEntries(exported).values)
        (v as Map)['comment'] as String: v['order'] as int,
    };
    expect(orders, {'hi': 0, 'mid': 10, 'lo': 15});
    expect(exported.issues[WorldBookStExportIssue.priorityShifted], 1);
  });

  test('位置降级：聊天顶部 → 角色定义之后，聊天底部 → @深度 0', () {
    const book = WorldBook(
      id: 'wb',
      entries: [
        WorldBookEntry(
          id: 't',
          name: 'top',
          content: 'x',
          position: WorldBookInjectionPosition.topOfChat,
        ),
        WorldBookEntry(
          id: 'b',
          name: 'bottom',
          content: 'x',
          position: WorldBookInjectionPosition.bottomOfChat,
          role: WorldBookInjectionRole.user,
        ),
      ],
    );
    final exported = encodeWorldBookStExport(book);
    final byComment = {
      for (final v in _stEntries(exported).values)
        (v as Map)['comment'] as String: v,
    };
    expect(byComment['top']!['position'], 1);
    expect(byComment['top']!['role'], isNull);
    expect(byComment['bottom']!['position'], 4);
    expect(byComment['bottom']!['depth'], 0);
    expect(byComment['bottom']!['role'], 1);
    expect(exported.issues[WorldBookStExportIssue.topOfChat], 1);
    expect(exported.issues[WorldBookStExportIssue.bottomOfChat], 1);
  });

  test('正则关键词写成 /pattern/flags 并转义斜杠', () {
    const book = WorldBook(
      id: 'wb',
      entries: [
        WorldBookEntry(
          id: 'r',
          name: 'r',
          content: 'x',
          keywords: ['a/b', r'c\/d', '龙+'],
          useRegex: true,
        ),
        WorldBookEntry(
          id: 'cs',
          name: 'cs',
          content: 'x',
          keywords: ['Dragon'],
          useRegex: true,
          caseSensitive: true,
        ),
      ],
    );
    final exported = encodeWorldBookStExport(book);
    final byComment = {
      for (final v in _stEntries(exported).values)
        (v as Map)['comment'] as String: (v['key'] as List).cast<String>(),
    };
    expect(byComment['r'], [r'/a\/b/i', r'/c\/d/i', '/龙+/i']);
    expect(byComment['cs'], ['/Dragon/']);
    expect(exported.issues[WorldBookStExportIssue.regexKeywords], 2);
  });

  test('计时器、混合角色、@@ 内容与整本关闭计入降级', () {
    const book = WorldBook(
      id: 'wb',
      enabled: false,
      entries: [
        WorldBookEntry(id: '1', name: '1', content: 'x', sticky: 2),
        WorldBookEntry(
          id: '2',
          name: '2',
          content: 'x',
          position: WorldBookInjectionPosition.atDepth,
          injectDepth: 2,
          role: WorldBookInjectionRole.user,
        ),
        WorldBookEntry(
          id: '3',
          name: '3',
          content: 'x',
          position: WorldBookInjectionPosition.atDepth,
          injectDepth: 2,
          role: WorldBookInjectionRole.assistant,
        ),
        WorldBookEntry(id: '4', name: '4', content: '@@depth 2\n正文'),
      ],
    );
    final issues = encodeWorldBookStExport(book).issues;
    expect(issues[WorldBookStExportIssue.timers], 1);
    expect(issues[WorldBookStExportIssue.mixedDepthRoles], 2);
    expect(issues[WorldBookStExportIssue.decoratorContent], 1);
    expect(issues[WorldBookStExportIssue.bookDisabled], 1);
  });

  test('键按数值升序写出，displayIndex 保持本应用列表顺序', () {
    const book = WorldBook(
      id: 'wb',
      entries: [
        WorldBookEntry(id: 'x', name: 'first', content: 'x'),
        WorldBookEntry(id: 'y', name: 'second', content: 'y'),
      ],
    );
    final entries = _stEntries(encodeWorldBookStExport(book));
    expect(entries.keys, ['0', '1']);
    expect((entries['0'] as Map)['comment'], 'second');
    expect((entries['0'] as Map)['displayIndex'], 1);
    expect((entries['1'] as Map)['comment'], 'first');
    expect((entries['1'] as Map)['displayIndex'], 0);
  });

  test('文件名加 _sillytavern 后缀', () {
    expect(worldBookStExportFileName('山海.json'), '山海_sillytavern.json');
  });
}
