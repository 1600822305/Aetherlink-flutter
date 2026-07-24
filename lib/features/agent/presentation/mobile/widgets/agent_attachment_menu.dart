import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/agent_attachment_access.dart';
import 'package:aetherlink_flutter/app/di/agent_terminal_access.dart';
import 'package:aetherlink_flutter/app/di/agent_workspace_access.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/settings/agent_compaction_settings_page.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// 输入栏「＋」菜单：紧凑图标宫格——附件类（工作区 @ 引用 / 设备文件 /
/// 图片 / 当前改动 Diff / 终端输出）+ 话题动作（立即压缩）。
/// 返回选中的附件列表（图片可多选；取消/纯动作返回空列表）。
Future<List<AgentUserAttachment>> showAgentAttachmentMenu(
  BuildContext context,
  WidgetRef ref, {
  required String? workspaceId,
  AgentTask? task,
}) async {
  // 手动压缩只对已启动的话题有意义（与设置页/侧栏入口同条件）。
  final canCompact = task != null && task.status != AgentTaskStatus.draft;
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Wrap(
          children: [
            const _MenuGridItem(
              icon: LucideIcons.atSign,
              label: '工作区文件',
              action: 'workspace',
            ),
            const _MenuGridItem(
              icon: LucideIcons.folderOpen,
              label: '设备文件',
              action: 'device',
            ),
            const _MenuGridItem(
              icon: LucideIcons.image,
              label: '图片',
              action: 'image',
            ),
            const _MenuGridItem(
              icon: LucideIcons.gitCompareArrows,
              label: '当前改动',
              action: 'diff',
            ),
            const _MenuGridItem(
              icon: LucideIcons.terminal,
              label: '终端输出',
              action: 'terminal',
            ),
            _MenuGridItem(
              icon: LucideIcons.archive,
              label: '立即压缩',
              action: 'compact',
              enabled: canCompact,
            ),
          ],
        ),
      ),
    ),
  );
  if (action == null || !context.mounted) return const [];
  switch (action) {
    case 'workspace':
      final attachment = await showAgentWorkspaceFilePicker(
        context,
        ref,
        workspaceId: workspaceId,
      );
      return [if (attachment != null) attachment];
    case 'device':
      final attachment = await _pickDeviceFile(context);
      return [if (attachment != null) attachment];
    case 'image':
      return _pickImages(context);
    case 'diff':
      final attachment = await _diffAttachment(context, ref, workspaceId);
      return [if (attachment != null) attachment];
    case 'terminal':
      final attachment = await _terminalAttachment(context, ref, workspaceId);
      return [if (attachment != null) attachment];
    case 'compact':
      if (task != null) await confirmAndCompactNow(context, ref, task);
      return const [];
  }
  return const [];
}

/// 宫格项：四列等宽，圆角图标块 + 小字标签，禁用时降透明度。
class _MenuGridItem extends StatelessWidget {
  const _MenuGridItem({
    required this.icon,
    required this.label,
    required this.action,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String action;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fg = cs.onSurface.withValues(alpha: enabled ? 0.8 : 0.3);
    return FractionallySizedBox(
      widthFactor: 1 / 4,
      child: InkWell(
        onTap: enabled ? () => Navigator.pop(context, action) : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: enabled ? 0.06 : 0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: fg),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(color: fg),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 工作区文件模糊搜索浮层（＋菜单与输入框 @ 触发共用）。
/// 选中后读取文件内容为文本附件。
Future<AgentUserAttachment?> showAgentWorkspaceFilePicker(
  BuildContext context,
  WidgetRef ref, {
  required String? workspaceId,
}) async {
  final relPath = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _WorkspaceFileSearchSheet(workspaceId: workspaceId),
  );
  if (relPath == null || !context.mounted) return null;
  try {
    final attachment = await ref.read(
      agentWorkspaceFileAttachmentProvider((workspaceId, relPath)).future,
    );
    if (attachment == null && context.mounted) {
      AppToast.error(context, '未找到工作区，无法读取文件');
    }
    return attachment;
  } catch (e) {
    if (context.mounted) AppToast.error(context, '读取文件失败 · $e');
    return null;
  }
}

const Set<String> _kImageExtensions = {
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'bmp',
  'heic',
};

/// 单个设备文件附件上限（8 MB）：base64/文本都随事件落库，防止巨型附件。
const int _kDeviceFileByteCap = 8 * 1024 * 1024;

String _mimeOf(String ext) => switch (ext) {
  'jpg' || 'jpeg' => 'image/jpeg',
  'gif' => 'image/gif',
  'webp' => 'image/webp',
  'bmp' => 'image/bmp',
  'heic' => 'image/heic',
  _ => 'image/png',
};

Future<AgentUserAttachment?> _pickDeviceFile(BuildContext context) async {
  final result = await FilePicker.pickFiles();
  final file = result?.files.firstOrNull;
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  if (bytes.length > _kDeviceFileByteCap) {
    if (context.mounted) AppToast.error(context, '文件超过 8 MB，暂不支持');
    return null;
  }
  final ext = file.extension?.toLowerCase() ?? '';
  if (_kImageExtensions.contains(ext)) {
    return AgentUserAttachment(
      kind: AgentAttachmentKind.image,
      name: file.name,
      mimeType: _mimeOf(ext),
      base64Data: base64Encode(bytes),
    );
  }
  final text = const Utf8Decoder(allowMalformed: true).convert(bytes);
  return AgentUserAttachment(
    kind: AgentAttachmentKind.file,
    name: file.name,
    text: clipAgentAttachmentText(text),
  );
}

Future<List<AgentUserAttachment>> _pickImages(BuildContext context) async {
  final picked = await ImagePicker().pickMultiImage(
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 85,
  );
  return [
    for (final file in picked)
      AgentUserAttachment(
        kind: AgentAttachmentKind.image,
        name: file.name,
        mimeType:
            file.mimeType ?? _mimeOf(file.name.split('.').last.toLowerCase()),
        base64Data: base64Encode(await file.readAsBytes()),
      ),
  ];
}

Future<AgentUserAttachment?> _diffAttachment(
  BuildContext context,
  WidgetRef ref,
  String? workspaceId,
) async {
  try {
    final result = await ref.read(
      agentWorkspaceChangesProvider(workspaceId).future,
    );
    final reason = result.unavailableReason;
    if (reason != null) {
      if (context.mounted) AppToast.error(context, reason.split('\n').first);
      return null;
    }
    final attachment = agentDiffAttachmentFrom(result);
    if (attachment == null && context.mounted) {
      AppToast.info(context, '当前没有未提交改动');
    }
    return attachment;
  } catch (e) {
    if (context.mounted) AppToast.error(context, '读取改动失败 · $e');
    return null;
  }
}

Future<AgentUserAttachment?> _terminalAttachment(
  BuildContext context,
  WidgetRef ref,
  String? workspaceId,
) async {
  final manager = ref.read(agentSessionPoolManagerProvider);
  final sessions = agentAliveSessions(manager, workspaceId ?? '');
  if (sessions.isEmpty) {
    if (context.mounted) AppToast.info(context, '当前工作区没有存活的终端会话');
    return null;
  }
  final session = sessions.length == 1
      ? sessions.first
      : await showModalBottomSheet<PooledWorkspaceSession>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final s in sessions)
                  ListTile(
                    leading: const Icon(LucideIcons.terminal, size: 20),
                    title: Text(s.name),
                    subtitle: Text(s.workspaceLabel),
                    onTap: () => Navigator.pop(context, s),
                  ),
              ],
            ),
          ),
        );
  if (session == null) return null;
  final snapshot = session.snapshot();
  if (snapshot.trim().isEmpty) {
    if (context.mounted) AppToast.info(context, '终端暂无输出');
    return null;
  }
  return agentTerminalAttachmentFrom(session.name, snapshot);
}

class _WorkspaceFileSearchSheet extends ConsumerStatefulWidget {
  const _WorkspaceFileSearchSheet({required this.workspaceId});

  final String? workspaceId;

  @override
  ConsumerState<_WorkspaceFileSearchSheet> createState() =>
      _WorkspaceFileSearchSheetState();
}

class _WorkspaceFileSearchSheetState
    extends ConsumerState<_WorkspaceFileSearchSheet> {
  String _query = '';

  /// 浏览模式的当前目录（相对路径，'' 为根）。
  String _dir = '';

  /// 子序列模糊匹配（Cursor 同款体验）：查询字符按序出现即命中，
  /// 文件名段命中的排前面。
  List<String> _filter(List<String> paths) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return paths.take(100).toList();
    bool fuzzy(String target) {
      var i = 0;
      for (final code in target.codeUnits) {
        if (code == query.codeUnitAt(i)) {
          i++;
          if (i == query.length) return true;
        }
      }
      return false;
    }

    final nameHits = <String>[];
    final pathHits = <String>[];
    for (final p in paths) {
      final lower = p.toLowerCase();
      final name = lower.split('/').last;
      if (name.contains(query) || fuzzy(name)) {
        nameHits.add(p);
      } else if (lower.contains(query) || fuzzy(lower)) {
        pathHits.add(p);
      }
      if (nameHits.length >= 100) break;
    }
    return [...nameHits, ...pathHits].take(100).toList();
  }

  /// 浏览模式：只 listDir 当前一层目录，即开即显；用户逐层点选。
  Widget _browseView(BuildContext context) {
    final dir = ref.watch(
      agentWorkspaceDirProvider((widget.workspaceId, _dir)),
    );
    final parent = _dir.contains('/')
        ? _dir.substring(0, _dir.lastIndexOf('/'))
        : '';
    return switch (dir) {
      AsyncData(:final value) => ListView(
        children: [
          if (_dir.isNotEmpty)
            ListTile(
              dense: true,
              leading: const Icon(LucideIcons.cornerLeftUp, size: 18),
              title: const Text('..'),
              subtitle: Text(
                _dir,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => setState(() => _dir = parent),
            ),
          if (value.isEmpty && _dir.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('工作区为空或未绑定工作区')),
            ),
          for (final e in value)
            ListTile(
              dense: true,
              leading: Icon(
                e.isDirectory ? LucideIcons.folder : LucideIcons.fileText,
                size: 18,
              ),
              title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                final rel = _dir.isEmpty ? e.name : '$_dir/${e.name}';
                if (e.isDirectory) {
                  setState(() => _dir = rel);
                } else {
                  Navigator.pop(context, rel);
                }
              },
            ),
        ],
      ),
      AsyncError(:final error) => Center(child: Text('加载失败 · $error')),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  /// 搜索模式：后台索引边扫边出，来多少搜多少，不等整棵树扫完。
  Widget _searchView(BuildContext context) {
    final index = ref.watch(
      agentWorkspaceFileIndexProvider(widget.workspaceId),
    );
    final snapshot = index.value;
    final indexing = snapshot == null || !snapshot.done;
    final paths = snapshot?.paths ?? const <String>[];
    final filtered = _filter(paths);
    return Column(
      children: [
        if (indexing) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text(indexing ? '索引中…' : '没有匹配的文件'))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final path = filtered[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(LucideIcons.fileText, size: 18),
                      title: Text(
                        path.split('/').last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.pop(context, path),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(LucideIcons.search, size: 18),
                  hintText: '搜索文件，或直接在下方浏览…',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: _query.trim().isEmpty
                  ? _browseView(context)
                  : _searchView(context),
            ),
          ],
        ),
      ),
    );
  }
}
