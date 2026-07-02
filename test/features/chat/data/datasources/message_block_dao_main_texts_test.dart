import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';

/// getAllMainTexts：聊天搜索的全库扫描在 SQL 层只取 main_text 的
/// (messageId, content)，图片/文件块（含内联 base64）不进内存。
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('returns only main_text (messageId, content); other kinds skipped',
      () async {
    final now = DateTime.utc(2024, 3, 1);
    await db.messageBlockDao.upsertAll([
      MessageBlock.mainText(
        id: 'b1',
        messageId: 'm1',
        status: MessageBlockStatus.success,
        createdAt: now,
        content: 'hello 世界',
      ),
      MessageBlock.image(
        id: 'b2',
        messageId: 'm1',
        status: MessageBlockStatus.success,
        createdAt: now,
        url: '',
        mimeType: 'image/png',
        base64Data: 'A' * 1024,
      ),
      MessageBlock.thinking(
        id: 'b3',
        messageId: 'm2',
        status: MessageBlockStatus.success,
        createdAt: now,
        content: 'reasoning',
      ),
      MessageBlock.mainText(
        id: 'b4',
        messageId: 'm2',
        status: MessageBlockStatus.success,
        createdAt: now,
        content: 'second',
      ),
    ]);

    final texts = await db.messageBlockDao.getAllMainTexts();
    expect(texts, hasLength(2));
    expect(
      texts,
      containsAll(<({String messageId, String content})>[
        (messageId: 'm1', content: 'hello 世界'),
        (messageId: 'm2', content: 'second'),
      ]),
    );
  });
}
