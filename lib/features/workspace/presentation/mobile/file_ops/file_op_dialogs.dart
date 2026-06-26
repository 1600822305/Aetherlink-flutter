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
