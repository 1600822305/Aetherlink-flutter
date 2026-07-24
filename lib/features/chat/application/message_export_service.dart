import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';

/// The three one-tap export formats (多选底部栏的格式按钮).
enum MessageExportFormat { txt, markdown, image }

/// Saves [content] via the system save dialog. Returns true when the file was
/// written (false = user cancelled).
Future<bool> saveExportTextFile(
  String content,
  String filename,
  List<String> extensions,
) async {
  final bytes = utf8.encode(content);
  final path = await FilePicker.saveFile(
    dialogTitle: '导出文件',
    fileName: filename,
    type: FileType.custom,
    allowedExtensions: extensions,
    bytes: Uint8List.fromList(bytes),
  );
  if (path == null) return false; // user cancelled
  // On desktop, FilePicker.saveFile doesn't write bytes — write manually.
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await File(path).writeAsString(content);
  }
  return true;
}

String buildMarkdownForExport(
  List<ChatMessageView> messages, {
  String? topicTitle,
  required bool showThinkingAndTools,
  required bool expandThinking,
}) {
  final buf = StringBuffer();
  final title = topicTitle?.trim();
  if (title != null && title.isNotEmpty) {
    buf.writeln('# $title\n');
  }
  for (final msg in messages) {
    final isUser = msg.role == MessageRole.user;
    final roleName = isUser ? '用户' : (msg.modelName ?? 'AI助手');
    final time = formatExportTime(msg.createdAt);
    buf.writeln('> $time · $roleName\n');

    if (showThinkingAndTools && expandThinking && msg.thinking.isNotEmpty) {
      buf.writeln('**思考过程**\n');
      buf.writeln('```text');
      buf.writeln(msg.thinking.trim());
      buf.writeln('```\n');
    }

    if (showThinkingAndTools) {
      for (final block in msg.blocks) {
        if (block is ToolBlock) {
          final name = block.toolName ?? block.toolId;
          final failed = block.status == MessageBlockStatus.error;
          buf.writeln('> 🔧 **$name** → ${failed ? "错误" : "完成"}\n');
        }
      }
    }

    if (msg.text.trim().isNotEmpty) {
      buf.writeln(msg.text.trim());
      buf.writeln();
    }
    buf.writeln('---\n');
  }
  return buf.toString();
}

String buildTxtForExport(
  List<ChatMessageView> messages, {
  String? topicTitle,
  required bool showThinkingAndTools,
  required bool expandThinking,
}) {
  final buf = StringBuffer();
  final title = topicTitle?.trim();
  if (title != null && title.isNotEmpty) {
    buf.writeln('$title\n');
  }
  for (final msg in messages) {
    final isUser = msg.role == MessageRole.user;
    final roleName = isUser ? '用户' : (msg.modelName ?? 'AI助手');
    final time = formatExportTime(msg.createdAt);
    buf.writeln('$time · $roleName\n');

    if (showThinkingAndTools && expandThinking && msg.thinking.isNotEmpty) {
      buf.writeln('[思考过程]');
      buf.writeln(msg.thinking.trim());
      buf.writeln();
    }

    if (showThinkingAndTools) {
      for (final block in msg.blocks) {
        if (block is ToolBlock) {
          final name = block.toolName ?? block.toolId;
          final failed = block.status == MessageBlockStatus.error;
          buf.writeln('[工具] $name → ${failed ? "错误" : "完成"}');
        }
      }
    }

    if (msg.text.trim().isNotEmpty) {
      buf.writeln(msg.text.trim());
      buf.writeln();
    }
    buf.writeln('---\n');
  }
  return buf.toString();
}

String formatExportTime(DateTime? time) {
  if (time == null) return '';
  final t = time.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} '
      '${two(t.hour)}:${two(t.minute)}';
}
