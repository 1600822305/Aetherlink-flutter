import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/world_book_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';

part 'world_book_menu_status.g.dart';

/// The current conversation's 世界书 status for the 扩展 menu's 高亮 + 徽标.
///
/// [currentTopicProvider] and [worldBookLibraryProvider] are async; this
/// provider combines their *loaded* values synchronously (`.value`) so the
/// input-box port can read it in `isActive` without awaiting — before both
/// resolve it reports "off", and it rebuilds as soon as they land.
@riverpod
WorldBookMenuStatus worldBookMenuStatus(Ref ref) {
  final topic = ref.watch(currentTopicProvider).value;
  final assistant = ref.watch(currentAssistantProvider);
  final books =
      ref.watch(worldBookLibraryProvider).value ?? const <WorldBook>[];
  final globalBookIds =
      ref.watch(worldBookGlobalDefaultProvider).value ?? const <String>[];
  return worldBookMenuStatusOf(
    assistant,
    topic,
    books,
    globalBookIds: globalBookIds,
  );
}
