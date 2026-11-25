// 条目标题为空（ST `comment` 为空，很多酒馆世界书都这样）时的显示标题。

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';

void main() {
  test('有标题时用标题', () {
    const e = WorldBookEntry(id: '0', name: ' 王都 ', keywords: ['k']);
    expect(e.displayTitle, '王都');
    expect(e.hasInferredTitle, isFalse);
  });

  test('标题为空：优先用内容里的 <Name>', () {
    const e = WorldBookEntry(
      id: '0',
      keywords: ['Aliya'],
      content: '<Name>\nAliya Mahvash\n</Name>\n\n<Background>…',
    );
    expect(e.displayTitle, 'Aliya Mahvash');
    expect(e.hasInferredTitle, isTrue);
  });

  test('再用第一个主关键词', () {
    const e = WorldBookEntry(
      id: '0',
      keywords: ['', 'Asticassia School of Technology', 'Asticassia'],
      content: 'Asticassia School of Technology is a prestigious…',
    );
    expect(e.displayTitle, 'Asticassia School of Technology');
  });

  test('再用内容第一行（跳过装饰器，截到 30 字）', () {
    final e = WorldBookEntry(
      id: '0',
      content: '@@activate\n${'长' * 40}',
    );
    expect(e.displayTitle, '${'长' * 30}…');
  });

  test('只用于显示：导出时 comment 仍为空', () {
    const e = WorldBookEntry(id: '0', keywords: ['k']);
    expect(e.toJson()['comment'], '');
  });

  test('ST 文件 comment 为空时也能显示名字', () {
    final book = WorldBook.fromJson({
      'entries': {
        '0': {
          'uid': 0,
          'key': ['Benerit Group'],
          'comment': '',
          'content': 'The Benerit Group is…',
        },
      },
    });
    expect(book.entries.single.name, '');
    expect(book.entries.single.displayTitle, 'Benerit Group');
  });
}
