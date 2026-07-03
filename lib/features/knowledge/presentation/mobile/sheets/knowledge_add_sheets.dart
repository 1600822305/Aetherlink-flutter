// 「添加数据源」相关面板：来源选择 / 添加网址。笔记来源从笔记功能里选取
// （见 app/di/notes_knowledge_access.dart），不再现场手写。
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:aetherlink_flutter/features/knowledge/presentation/mobile/widgets/knowledge_common.dart';

/// 「添加数据源」面板：四种来源各一行，点选后 pop 出对应动作由调用方执行
/// （先关面板再开来源自己的面板 / 选择器，避免嵌套导航）。
class KnowledgeAddSourceSheet extends StatelessWidget {
  const KnowledgeAddSourceSheet({
    super.key,
    required this.onNote,
    required this.onFile,
    required this.onUrl,
    required this.onWorkspace,
  });

  final Future<void> Function() onNote;
  final Future<void> Function() onFile;
  final Future<void> Function() onUrl;
  final Future<void> Function() onWorkspace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget entry({
      required IconData icon,
      required String title,
      required String subtitle,
      required Future<void> Function() action,
    }) {
      return ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        onTap: () => Navigator.of(context).pop(action),
      );
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                '添加数据源',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            entry(
              icon: LucideIcons.notebookPen,
              title: '笔记',
              subtitle: '从笔记中选择一篇并摄取',
              action: onNote,
            ),
            entry(
              icon: LucideIcons.upload,
              title: '文件',
              subtitle:
                  'txt / md / html / docx / pdf / pptx / xlsx / epub，'
                  '配置云端解析后支持 doc / ppt / xls 等更多格式',
              action: onFile,
            ),
            entry(
              icon: LucideIcons.link,
              title: '网址',
              subtitle: '抓取网页正文并摄取',
              action: onUrl,
            ),
            entry(
              icon: LucideIcons.folder,
              title: '文件夹 / 目录',
              subtitle: '选择文件夹或工作区，批量摄取其中的文本文件',
              action: onWorkspace,
            ),
          ],
        ),
      ),
    );
  }
}

/// 添加网址面板。
class KnowledgeAddUrlSheet extends StatefulWidget {
  const KnowledgeAddUrlSheet({super.key});

  @override
  State<KnowledgeAddUrlSheet> createState() => _KnowledgeAddUrlSheetState();
}

class _KnowledgeAddUrlSheetState extends State<KnowledgeAddUrlSheet> {
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KnowledgeSheetScaffold(
      title: '添加网址',
      confirmLabel: '抓取',
      onConfirm: () => Navigator.of(context).pop((
        url: _urlController.text.trim(),
        title: _titleController.text.trim(),
      )),
      children: [
        TextField(
          controller: _urlController,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: '网址',
            hintText: 'https://example.com/article',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(labelText: '标题（可选，留空用网页标题）'),
        ),
      ],
    );
  }
}
