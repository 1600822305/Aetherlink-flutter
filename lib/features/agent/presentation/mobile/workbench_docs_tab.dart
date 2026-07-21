import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/agent_workspace_access.dart';
import 'package:aetherlink_flutter/app/di/markdown_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/workbench_docs.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// 工作台「文档」tab：列出智能体本次任务写入的 Markdown 文档。
/// 对齐 Devin 的展示：写入进行中的文档带「创建中」实况徽标、点开
/// 实时渲染已流出的正文；完成后读工作区文件全文渲染，可复制。
class WorkbenchDocsTab extends ConsumerWidget {
  const WorkbenchDocsTab({required this.task, super.key});

  final AgentTask task;

  String? _workspaceId(WidgetRef ref) => ref
      .read(agentProfilesProvider)
      .where((p) => p.id == task.profileId)
      .firstOrNull
      ?.workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(agentTaskEventsProvider(task.id));
    final docs = deriveAgentDocs(async.value ?? const []);
    if (docs.isEmpty) {
      final muted = theme.colorScheme.onSurface.withValues(alpha: 0.35);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.fileText, size: 40, color: muted),
            const SizedBox(height: 12),
            Text(
              '智能体还没有写入文档\n任务中产出的 .md 文档会列在这里',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (context, i) => _DocRow(
        doc: docs[i],
        onTap: () => _openDoc(context, ref, docs[i]),
      ),
    );
  }

  Future<void> _openDoc(
    BuildContext context,
    WidgetRef ref,
    AgentDocEntry doc,
  ) {
    final workspaceId = _workspaceId(ref);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => _DocViewer(
          taskId: task.id,
          workspaceId: workspaceId,
          path: doc.path,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.doc, required this.onTap});

  final AgentDocEntry doc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (label, color) = switch (doc.state) {
      AgentDocState.creating => ('创建中', cs.primary),
      AgentDocState.done => ('已完成', Colors.green),
      AgentDocState.failed => ('失败', cs.error),
    };
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              LucideIcons.fileText,
              size: 16,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: doc.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (doc.dir != null)
                      TextSpan(
                        text: '  ${doc.dir}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (doc.state == AgentDocState.creating) ...[
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 文档内容（成品）读取：seq 变化（同一文档再次写入）自动失效重读。
final _docContentProvider = FutureProvider.autoDispose
    .family<String, (String?, String, int)>((ref, args) {
  final (workspaceId, path, _) = args;
  return readAgentWorkspaceDoc(ref, workspaceId, path);
});

/// 文档阅读器：创建中实时渲染流式正文（跟随事件流刷新），
/// 完成后读文件全文渲染；顶栏含标题与复制按钮。
class _DocViewer extends ConsumerWidget {
  const _DocViewer({
    required this.taskId,
    required this.workspaceId,
    required this.path,
    required this.scrollController,
  });

  final String taskId;
  final String? workspaceId;
  final String path;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final events = ref.watch(agentTaskEventsProvider(taskId)).value;
    final doc = deriveAgentDocs(events ?? const [])
        .where((d) => d.path == path)
        .firstOrNull;
    final creating = doc?.state == AgentDocState.creating;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
          child: Row(
            children: [
              Icon(
                LucideIcons.fileText,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  path.split('/').last,
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (creating)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '创建中…',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                )
              else
                IconButton(
                  tooltip: '复制全文',
                  icon: const Icon(LucideIcons.copy, size: 16),
                  onPressed: () => _copy(context, ref, doc),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: creating
              ? _streamingBody(context, doc)
              : _fileBody(context, ref, doc),
        ),
      ],
    );
  }

  Future<void> _copy(
    BuildContext context,
    WidgetRef ref,
    AgentDocEntry? doc,
  ) async {
    try {
      final content = await ref.read(
        _docContentProvider((workspaceId, path, doc?.seq ?? 0)).future,
      );
      await Clipboard.setData(ClipboardData(text: content));
      if (context.mounted) AppToast.success(context, '已复制文档全文');
    } catch (e) {
      if (context.mounted) AppToast.error(context, '复制失败 · $e');
    }
  }

  Widget _streamingBody(BuildContext context, AgentDocEntry? doc) {
    final theme = Theme.of(context);
    final content = doc?.streamingContent;
    if (content == null || content.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: StreamingMarkdownBody(
        content: '$content▍',
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
      ),
    );
  }

  Widget _fileBody(BuildContext context, WidgetRef ref, AgentDocEntry? doc) {
    final theme = Theme.of(context);
    final async =
        ref.watch(_docContentProvider((workspaceId, path, doc?.seq ?? 0)));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '文档读取失败\n$e',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      ),
      data: (content) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        child: AppMarkdown(
          content: content,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
      ),
    );
  }
}
