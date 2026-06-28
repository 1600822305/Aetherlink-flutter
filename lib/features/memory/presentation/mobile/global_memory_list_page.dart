import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/memory/application/memory_providers.dart';
import 'package:aetherlink_flutter/features/memory/presentation/mobile/memory_list_view.dart';

/// 全局记忆 list (记忆 → 全局记忆) — the data-backed management surface for
/// chat-global memories: manual add / edit / delete plus keyword search. All
/// rows are `kind=chat, level=global`. The shared [MemoryListView] renders the
/// UI; this page only binds it to [GlobalMemoriesController].
class GlobalMemoryListPage extends ConsumerWidget {
  const GlobalMemoryListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(globalMemoriesControllerProvider.notifier);
    return MemoryListView(
      title: '全局记忆',
      searchHint: '搜索全局记忆',
      emptyTitle: '还没有全局记忆',
      emptySubtitle: '全局记忆会在所有助手对话中生效',
      items: ref.watch(globalMemoriesControllerProvider),
      onQueryChanged: controller.setQuery,
      onCreate: controller.create,
      onSave: controller.save,
      onDelete: controller.delete,
    );
  }
}
