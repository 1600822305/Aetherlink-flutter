import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/notes/application/notes_controller.dart';
import 'package:aetherlink_flutter/features/notes/presentation/mobile/note_picker.dart';

/// App-level seam that lets the knowledge base ingest a note from the 笔记
/// feature（对齐 CS：知识库的「笔记」数据源从笔记功能里选取，而不是现场手写
/// markdown）。note picker 在 `notes/presentation`、正文在 `notes/data`，
/// 组合放在这里以维持 feature 边界。
///
/// 弹出笔记选择器，选中后读出 markdown 正文；取消时返回 `null`。
Future<({String title, String text, String relativePath})?>
pickNoteForKnowledge(BuildContext context, WidgetRef ref) async {
  final node = await showNotePicker(context);
  if (node == null) return null;
  final text = await ref.read(notesFileStoreProvider).read(node.relativePath);
  return (title: node.title, text: text, relativePath: node.relativePath);
}
