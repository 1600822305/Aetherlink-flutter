import 'package:flutter/material.dart';

/// Small reusable dialogs shared by the file-tree write operations. Kept free
/// of any backend/plugin types so they stay pure UI.

/// Prompts for a (file/folder) name. Returns the trimmed input, or `null` when
/// the user cancels or leaves it empty. [initial] pre-fills the field (used by
/// rename) with the text pre-selected.
Future<String?> promptName(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? initial,
  String hint = '名称',
}) async {
  final controller = TextEditingController(text: initial ?? '');
  if (initial != null) {
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: initial.length,
    );
  }
  final name = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  controller.dispose();
  if (name == null || name.isEmpty) return null;
  return name;
}

/// Prompts for a new file's name plus whether to seed it with a starter
/// template matched by extension. Returns `null` on cancel/empty input.
Future<({String name, bool useTemplate})?> promptNewFile(
  BuildContext context,
) async {
  final controller = TextEditingController();
  final result = await showDialog<({String name, bool useTemplate})>(
    context: context,
    builder: (context) {
      var useTemplate = true;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('新建文件'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(hintText: '文件名,如 notes.md'),
                onSubmitted: (v) => Navigator.of(context)
                    .pop((name: v.trim(), useTemplate: useTemplate)),
              ),
              const SizedBox(height: 4),
              CheckboxListTile(
                value: useTemplate,
                onChanged: (v) => setState(() => useTemplate = v ?? true),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  '按扩展名填入起始模板(.md/.py/.sh/.html 等)',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                (name: controller.text.trim(), useTemplate: useTemplate),
              ),
              child: const Text('创建'),
            ),
          ],
        ),
      );
    },
  );
  controller.dispose();
  if (result == null || result.name.isEmpty) return null;
  return result;
}

/// User's choice when a move/copy destination already has a same-name entry.
enum ConflictAction { overwrite, keepBoth }

/// Asks how to handle a name conflict at the destination: 覆盖（先删除既有
/// 项再执行）、保留两者（自动改成「name (2).ext」）或取消（返回 null）。
Future<ConflictAction?> promptNameConflict(
  BuildContext context, {
  required String name,
  required bool existingIsDirectory,
}) {
  return showDialog<ConflictAction>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('目标已存在'),
      content: Text(
        existingIsDirectory
            ? '目标位置已有同名文件夹「$name」。覆盖将删除该文件夹及其全部内容。'
            : '目标位置已有同名文件「$name」。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(ConflictAction.keepBoth),
          child: const Text('保留两者'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () =>
              Navigator.of(context).pop(ConflictAction.overwrite),
          child: const Text('覆盖'),
        ),
      ],
    ),
  );
}

/// Confirms deletion of [name]. Directories warn that contents go too.
Future<bool> confirmDelete(
  BuildContext context, {
  required String name,
  required bool isDirectory,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('确认删除'),
        content: Text(
          isDirectory
              ? '删除文件夹「$name」及其全部内容?此操作无法撤销。'
              : '删除文件「$name」?此操作无法撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      );
    },
  );
  return ok ?? false;
}
