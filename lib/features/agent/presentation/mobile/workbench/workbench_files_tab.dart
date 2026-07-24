import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/agent_workspace_access.dart';
import 'package:aetherlink_flutter/app/di/markdown_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/workbench_files.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// 工作台「文件」tab：列出智能体本次任务写入的文件（不限 Markdown）。
/// 写入进行中带「创建中」实况徽标、点开实时渲染已流出的正文；完成后
/// 读工作区文件全文——Markdown 支持渲染/原文切换，其余按纯文本显示。
class WorkbenchFilesTab extends ConsumerWidget {
  const WorkbenchFilesTab({required this.task, super.key});

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
    final files = deriveAgentFiles(async.value ?? const []);
    if (files.isEmpty) {
      final muted = theme.colorScheme.onSurface.withValues(alpha: 0.35);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.fileText, size: 40, color: muted),
            const SizedBox(height: 12),
            Text(
              '智能体还没有写入文件\n任务中产出的文件会列在这里',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + 8,
      ),
      itemCount: files.length,
      itemBuilder: (context, i) => _FileRow(
        file: files[i],
        onTap: () => _openFile(context, ref, files[i]),
      ),
    );
  }

  void _openFile(BuildContext context, WidgetRef ref, AgentFileEntry file) {
    final workspaceId = _workspaceId(ref);
    // 零时长路由：与项目其它全屏子页一致（MaterialPageRoute 自带
    // 300ms transitionDuration，进入/返回都会卡一拍）。
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => _FileViewerPage(
          taskId: task.id,
          workspaceId: workspaceId,
          path: file.path,
        ),
      ),
    );
  }
}

IconData _iconForExt(String ext) => switch (ext) {
  'md' || 'markdown' => LucideIcons.fileText,
  'json' => LucideIcons.braces,
  'dart' ||
  'ts' ||
  'js' ||
  'py' ||
  'java' ||
  'kt' ||
  'go' ||
  'rs' => LucideIcons.code,
  'png' || 'jpg' || 'jpeg' || 'gif' || 'webp' || 'svg' => LucideIcons.image,
  _ => LucideIcons.file,
};

class _FileRow extends StatelessWidget {
  const _FileRow({required this.file, required this.onTap});

  final AgentFileEntry file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (label, color) = switch (file.state) {
      AgentFileState.creating => ('创建中', cs.primary),
      AgentFileState.done => ('已完成', Colors.green),
      AgentFileState.failed => ('失败', cs.error),
    };
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              _iconForExt(file.ext),
              size: 16,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: file.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (file.dir != null)
                      TextSpan(
                        text: '  ${file.dir}',
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
            if (file.state == AgentFileState.creating) ...[
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

/// 文件内容（成品）读取：seq 变化（同一文件再次写入）自动失效重读。
final _fileContentProvider = FutureProvider.autoDispose
    .family<String, (String?, String, int)>((ref, args) {
      final (workspaceId, path, _) = args;
      return readAgentWorkspaceDoc(ref, workspaceId, path);
    });

/// 全屏文件查看器：创建中实时渲染流式正文（跟随事件流刷新），完成后
/// 读文件全文。Markdown 可在「渲染 / 原文」间切换，其余按纯文本显示。
/// 页面链路复用设置页的 chrome（ModelSettingsAppBar + ModelSettingsCard），
/// 与其他三级页风格一致。
class _FileViewerPage extends ConsumerStatefulWidget {
  const _FileViewerPage({
    required this.taskId,
    required this.workspaceId,
    required this.path,
  });

  final String taskId;
  final String? workspaceId;
  final String path;

  @override
  ConsumerState<_FileViewerPage> createState() => _FileViewerPageState();
}

class _FileViewerPageState extends ConsumerState<_FileViewerPage> {
  /// Markdown 是否渲染显示（false 为查看原文）；非 md 恒为原文。
  bool _rendered = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events = ref.watch(agentTaskEventsProvider(widget.taskId)).value;
    final file = deriveAgentFiles(
      events ?? const [],
    ).where((f) => f.path == widget.path).firstOrNull;
    final creating = file?.state == AgentFileState.creating;
    final isMd = file?.isMarkdown ?? widget.path.toLowerCase().endsWith('.md');

    return Scaffold(
      appBar: ModelSettingsAppBar(
        title: widget.path.split('/').last,
        onBack: () => Navigator.of(context).pop(),
        actions: [
          if (creating)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '创建中…',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else ...[
            if (isMd)
              IconButton(
                tooltip: _rendered ? '查看原文' : '渲染显示',
                icon: Icon(
                  _rendered ? LucideIcons.code : LucideIcons.eye,
                  size: 18,
                ),
                color: theme.colorScheme.primary,
                onPressed: () => setState(() => _rendered = !_rendered),
              ),
            IconButton(
              tooltip: '复制全文',
              icon: const Icon(LucideIcons.copy, size: 18),
              color: theme.colorScheme.primary,
              onPressed: () => _copy(file),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
      body: creating ? _streamingBody(file, isMd) : _fileBody(file, isMd),
    );
  }

  /// 设置页同款卡片容器：16 外边距 + 卡片 + 底部安全区域。
  Widget _cardScroll(Widget child) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      16,
      16,
      16,
      16 + MediaQuery.paddingOf(context).bottom,
    ),
    child: SizedBox(
      width: double.infinity,
      child: ModelSettingsCard(padding: const EdgeInsets.all(16), child: child),
    ),
  );

  Future<void> _copy(AgentFileEntry? file) async {
    try {
      final content = await ref.read(
        _fileContentProvider((
          widget.workspaceId,
          widget.path,
          file?.seq ?? 0,
        )).future,
      );
      await Clipboard.setData(ClipboardData(text: content));
      if (mounted) AppToast.success(context, '已复制文件全文');
    } catch (e) {
      if (mounted) AppToast.error(context, '复制失败 · $e');
    }
  }

  Widget _streamingBody(AgentFileEntry? file, bool isMd) {
    final content = file?.streamingContent;
    if (content == null || content.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    // 创建中始终用流式 Markdown 组件（纯文本也能安全渲染）。
    final theme = Theme.of(context);
    return _cardScroll(
      isMd
          ? StreamingMarkdownBody(
              content: '$content▍',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            )
          : _rawText('$content▍'),
    );
  }

  Widget _fileBody(AgentFileEntry? file, bool isMd) {
    final async = ref.watch(
      _fileContentProvider((widget.workspaceId, widget.path, file?.seq ?? 0)),
    );
    final theme = Theme.of(context);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '文件读取失败\n$e',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      ),
      data: (content) => _cardScroll(
        isMd && _rendered
            ? AppMarkdown(
                content: content,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              )
            : _rawText(content),
      ),
    );
  }

  Widget _rawText(String content) => SelectableText(
    content,
    style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.45),
  );
}
