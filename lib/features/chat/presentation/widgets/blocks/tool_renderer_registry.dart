import 'package:flutter/widgets.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/file_editor/file_editor_block_view.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/file_editor/file_editor_read_block_view.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/file_editor/run_command_block_view.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/knowledge_block_view.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/terminal_session_block_view.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/web_search_block_view.dart';

/// Builds a special-purpose widget for a [ToolBlock].
typedef ToolBlockBuilder = Widget Function(ToolBlock block);

/// `@aether/file-editor` tools that mutate the workspace (and run behind HITL
/// confirmation). Rendered as Cursor/Windsurf-style edit cards.
const Set<String> _fileEditorWriteTools = {
  'write_to_file',
  'apply_diff',
  'create_file',
  'create_directory',
  'rename_file',
  'move_file',
  'copy_file',
  'delete_file',
  'insert_content',
  'replace_in_file',
};

/// `@aether/file-editor` read-only tools, rendered as compact read/list rows.
const Set<String> _fileEditorReadTools = {
  'get_workspace_files',
  'list_files',
  'read_file',
  'get_file_info',
  'search_files',
};

/// Registry of tool name → custom renderer. Adding a new specially-rendered
/// tool (e.g. a future agent tool) only means registering it here; the block
/// renderer stays untouched. Tools with no entry fall back to the default
/// JSON tool card.
final Map<String, ToolBlockBuilder> _toolRenderers = {
  'builtin_web_search': (b) => WebSearchBlockView(block: b),
  // run_command 已下线（终端能力归 @aether/terminal），保留渲染以兼容历史消息。
  'run_command': (b) => RunCommandBlockView(block: b),
  'terminal_execute': (b) => RunCommandBlockView(block: b),
  for (final t in _terminalSessionTools)
    t: (b) => TerminalSessionBlockView(block: b),
  for (final t in _fileEditorWriteTools)
    t: (b) => FileEditorBlockView(block: b),
  for (final t in _fileEditorReadTools)
    t: (b) => FileEditorReadBlockView(block: b),
  for (final t in _knowledgeTools) t: (b) => KnowledgeBlockView(block: b),
};

/// `@aether/terminal` 长驻会话工具，渲染为终端会话卡片。旧的
/// terminal_session_*（已合并进 terminal_session 的 action 参数）保留
/// 渲染以兼容历史消息。
const Set<String> _terminalSessionTools = {
  'terminal_session',
  'terminal_session_create',
  'terminal_session_list',
  'terminal_session_exec',
  'terminal_session_output',
  'terminal_session_close',
};

/// `@aether/knowledge` tools, rendered as compact knowledge cards
/// (检索命中列表 / 库列表 / 正文预览 / 管理结果).
const Set<String> _knowledgeTools = {
  'kb_list',
  'kb_search',
  'kb_read',
  'kb_manage',
};

/// Returns a custom renderer for [block]'s tool, or `null` to fall back to the
/// default tool card.
Widget? buildSpecialToolBlock(ToolBlock block) =>
    _toolRenderers[block.toolName]?.call(block);

/// Whether [toolName] is a `@aether/file-editor` mutating tool — used by the
/// renderer to coalesce consecutive edits into a changeset card.
bool isFileEditorWriteTool(String? toolName) =>
    toolName != null && _fileEditorWriteTools.contains(toolName);
