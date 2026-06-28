import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/memory/application/memory_providers.dart';
import 'package:aetherlink_flutter/features/memory/presentation/mobile/memory_list_view.dart';

/// 助手私有记忆 list (记忆 → 按助手查看 → <助手>, or the assistant editor's 记忆
/// tab) — the data-backed management surface for one assistant's private
/// memories. All rows are `kind=chat, level=owner, ownerId=assistantId`. The
/// shared [MemoryListView] renders the UI; this page binds it to the
/// family-keyed [AssistantMemoriesController].
class AssistantMemoryListPage extends ConsumerWidget {
  const AssistantMemoryListPage({
    super.key,
    required this.assistantId,
    required this.assistantName,
  });

  final String assistantId;
  final String assistantName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller =
        ref.read(assistantMemoriesControllerProvider(assistantId).notifier);
    final title = assistantName.trim().isEmpty ? '助手记忆' : assistantName.trim();
    return MemoryListView(
      title: title,
      searchHint: '搜索该助手的记忆',
      emptyTitle: '还没有该助手的私有记忆',
      emptySubtitle: '私有记忆只在与该助手对话时生效',
      items: ref.watch(assistantMemoriesControllerProvider(assistantId)),
      onQueryChanged: controller.setQuery,
      onCreate: controller.create,
      onSave: controller.save,
      onDelete: controller.delete,
    );
  }
}
