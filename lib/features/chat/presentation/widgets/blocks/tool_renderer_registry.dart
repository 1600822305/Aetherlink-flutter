import 'package:flutter/widgets.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/file_editor/file_editor_block_view.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/file_editor/file_editor_read_block_view.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/file_editor/run_command_block_view.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/dex_editor_block_view.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/knowledge_block_view.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/web_search_block_view.dart';

/// Builds a special-purpose widget for a [ToolBlock].
typedef ToolBlockBuilder = Widget Function(ToolBlock block);

/// `@aether/file-editor` tools that mutate the workspace (and run behind HITL
/// confirmation). Rendered as Cursor/Windsurf-style edit cards.
const Set<String> _fileEditorWriteTools = {
  'write_to_file',
  'apply_diff',
  'create_file',
  'rename_file',
  'move_file',
  'copy_file',
  'delete_file',
  'insert_content',
  'replace_in_file',
};

/// `@aether/file-editor` read-only tools, rendered as compact read/list rows.
const Set<String> _fileEditorReadTools = {
  'list_workspaces',
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
  'run_command': (b) => RunCommandBlockView(block: b),
  for (final t in _fileEditorWriteTools)
    t: (b) => FileEditorBlockView(block: b),
  for (final t in _fileEditorReadTools)
    t: (b) => FileEditorReadBlockView(block: b),
  for (final t in _knowledgeTools) t: (b) => KnowledgeBlockView(block: b),
  for (final t in _dexEditorTools) t: (b) => DexEditorBlockView(block: b),
};

/// `@aether/dex-editor` built-in tools (会话工作流 / 类·方法反汇编 / 搜索 /
/// 交叉引用 / 反编译 / 清单与资源 / APK 文件 / 任务完成)，渲染为紧凑的 DEX 卡片。
const Set<String> _dexEditorTools = {
  'dex_open_apk',
  'dex_open',
  'dex_list_classes',
  'dex_search',
  'dex_get_class',
  'dex_modify_class',
  'dex_save',
  'dex_save_all', // 向后兼容别名，等价 dex_save(scope: all)
  'dex_close',
  'dex_list_sessions',
  'dex_add_class',
  'dex_delete_class',
  'dex_get_method',
  'dex_modify_method',
  'dex_outline_class',
  'dex_rename_class',
  'dex_find_xrefs',
  'dex_find_method_xrefs', // 向后兼容别名，等价 dex_find_xrefs(target: method)
  'dex_find_field_xrefs', // 向后兼容别名，等价 dex_find_xrefs(target: field)
  'dex_find_class_xrefs', // 向后兼容别名，等价 dex_find_xrefs(target: class)
  'dex_smali_to_java',
  'apk_get_manifest',
  'apk_edit_manifest',
  'apk_modify_manifest', // 向后兼容别名，等价 apk_edit_manifest(mode: replace_all)
  'apk_patch_manifest', // 向后兼容别名，等价 apk_edit_manifest(mode: patch)
  'apk_replace_in_manifest', // 向后兼容别名，等价 apk_edit_manifest(mode: find_replace)
  'apk_list_resources',
  'apk_get_resource',
  'apk_modify_resource',
  'apk_get_resource_value',
  'apk_set_resource_value',
  'apk_list_files',
  'apk_read_file',
  'apk_delete_file',
  'apk_add_file',
  'apk_parse_arsc_cpp',
  'attempt_completion',
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
