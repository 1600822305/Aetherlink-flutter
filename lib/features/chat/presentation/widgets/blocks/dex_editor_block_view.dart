import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/code_block/code_block_view.dart';

/// Compact rendering for the `@aether/dex-editor` built-in tools (dex_* / apk_*
/// / attempt_completion)。与知识库、file-editor 工具同款的一行头部卡片
/// （图标 + 摘要 + 展开箭头），展开后按工具展示类/方法反汇编、类列表、搜索命中、
/// 交叉引用、资源与清单等，替代默认的原始 JSON 工具卡。
///
/// dex 工具的返回体（见 `dex_editor_tool.dart`）没有统一的 `{success,data}`
/// 包裹：有的是纯文本（smali / java / 成功提示 `✅...`），有的是直接的 JSON
/// 对象。这里对两种形态都做兜底解析，并用 `isError` / 内容前缀 / block 状态共同
/// 判定错误。
class DexEditorBlockView extends StatefulWidget {
  const DexEditorBlockView({required this.block, super.key});

  final ToolBlock block;

  @override
  State<DexEditorBlockView> createState() => _DexEditorBlockViewState();
}

/// 展开区最大高度：超出则内部滚动，防止长反汇编/长列表把气泡撑得过长。
const double _kBodyMaxHeight = 320;

class _DexEditorBlockViewState extends State<DexEditorBlockView> {
  bool _expanded = false;

  ToolBlock get block => widget.block;
  String get _tool => block.toolName ?? '';
  Map<String, Object?> get _args => block.arguments ?? const {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = block.status;
    final isProcessing = status == MessageBlockStatus.pending ||
        status == MessageBlockStatus.processing ||
        status == MessageBlockStatus.streaming;
    final hasError = status == MessageBlockStatus.error || _isErrorContent();

    final (icon, summary) = _header();
    final body = (!isProcessing && !hasError) ? _body(theme) : null;
    final canExpand = body != null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap:
                canExpand ? () => setState(() => _expanded = !_expanded) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  if (isProcessing)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  else
                    Icon(
                      hasError ? LucideIcons.circleAlert : icon,
                      size: 15,
                      color: hasError
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isProcessing ? _processingLabel() : summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: hasError ? theme.colorScheme.error : null,
                      ),
                    ),
                  ),
                  if (canExpand)
                    AnimatedRotation(
                      turns: _expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        LucideIcons.chevronRight,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (hasError && !isProcessing)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Text(
                _errorMessage() ?? 'DEX 编辑器工具执行失败',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          if (canExpand)
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                // 超长内容（反汇编正文、类/搜索/文件长列表）固定最大高度并内部
                // 滚动，避免把整个气泡撑得过长。短内容按需收缩、不会留白。
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: _kBodyMaxHeight),
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      primary: false,
                      child: body,
                    ),
                  ),
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
        ],
      ),
    );
  }

  // ----- header -----

  (IconData, String) _header() {
    final data = _dataMap();
    switch (_tool) {
      case 'dex_open_apk':
        final files = data?['dexFiles'];
        final count = files is List ? files.length : 0;
        return (LucideIcons.package, '打开 APK · $count 个 DEX · ${_apkName()}');
      case 'dex_open':
        final classCount = data?['classCount'];
        return (
          LucideIcons.folderOpen,
          '打开 DEX 会话${classCount is num ? ' · $classCount 个类' : ''}'
        );
      case 'dex_list_sessions':
        final total = data?['total'];
        return (LucideIcons.layers, '会话列表${total is num ? ' · $total 个' : ''}');
      case 'dex_close':
        return (LucideIcons.x, '关闭会话');
      case 'dex_list_classes':
        final total = data?['total'];
        return (
          LucideIcons.list,
          '类列表${total is num ? ' · 共 $total 个' : ''}'
        );
      case 'dex_search':
        final query = _strArg('query');
        final total = data?['total'];
        return (
          LucideIcons.search,
          '搜索「$query」${total is num ? ' · $total 条命中' : ''}'
        );
      case 'dex_get_class':
        return (LucideIcons.fileCode, '查看类 ${_shortClass()}');
      case 'dex_outline_class':
        return (LucideIcons.listTree, '类轮廓 ${_shortClass()}');
      case 'dex_get_method':
        return (LucideIcons.code, '查看方法 ${_strArg('methodName')}');
      case 'dex_modify_class':
        return (LucideIcons.filePenLine, '修改类 ${_shortClass()}');
      case 'dex_add_class':
        return (LucideIcons.filePlus, '新增类 ${_shortClass()}');
      case 'dex_delete_class':
        return (LucideIcons.fileX, '删除类 ${_shortClass()}');
      case 'dex_modify_method':
        return (LucideIcons.filePenLine, '修改方法 ${_strArg('methodName')}');
      case 'dex_rename_class':
        return (
          LucideIcons.pencil,
          '重命名类 → ${_shortName(_strArg('newClassName'))}'
        );
      case 'dex_save':
        // scope=all 展示批量保存摘要。
        if (_strArg('scope') == 'all') {
          final saved = data?['saved'];
          return (
            LucideIcons.save,
            '批量保存${saved is num ? ' · $saved 个' : ''}'
          );
        }
        return (LucideIcons.save, '保存 DEX 到 APK');
      case 'dex_find_xrefs':
        final xrefs = data?['xrefs'];
        final count = xrefs is List ? xrefs.length : 0;
        return (LucideIcons.gitFork, '交叉引用 · $count 处');
      case 'dex_smali_to_java':
        return (LucideIcons.coffee, '反编译为 Java ${_shortClass()}');
      case 'apk_get_manifest':
        return (LucideIcons.fileText, '读取 AndroidManifest');
      case 'apk_edit_manifest':
        // 统一清单写入：按 mode 呈现对应图标与摘要。
        switch (_strArg('mode')) {
          case 'patch':
            final applied = data?['appliedCount'];
            return (
              LucideIcons.filePenLine,
              'Patch Manifest${applied is num ? ' · $applied 处' : ''}'
            );
          case 'find_replace':
            final replaced = data?['replacedCount'];
            return (
              LucideIcons.replace,
              '替换 Manifest${replaced is num ? ' · $replaced 处' : ''}'
            );
          default:
            return (LucideIcons.filePenLine, '修改 AndroidManifest');
        }
      case 'apk_list_resources':
        final total = data?['total'];
        return (
          LucideIcons.folderTree,
          '资源列表${total is num ? ' · 共 $total 个' : ''}'
        );
      case 'apk_get_resource':
        return (LucideIcons.fileText, '读取资源 ${_shortName(_resourceName())}');
      case 'apk_modify_resource':
        return (LucideIcons.filePenLine, '修改资源 ${_shortName(_resourceName())}');
      case 'apk_get_resource_value':
        return (LucideIcons.tag, '读取资源值 ${_strArg('id')}');
      case 'apk_set_resource_value':
        return (LucideIcons.tag, '修改资源值 ${_strArg('id')}');
      case 'apk_list_files':
        final total = data?['total'];
        return (
          LucideIcons.files,
          'APK 文件列表${total is num ? ' · 共 $total 个' : ''}'
        );
      case 'apk_read_file':
        return (LucideIcons.file, '读取 APK 文件 ${_shortName(_strArg('filePath'))}');
      case 'apk_delete_file':
        return (LucideIcons.fileX, '删除 APK 文件 ${_shortName(_strArg('filePath'))}');
      case 'apk_add_file':
        return (LucideIcons.filePlus, '添加 APK 文件 ${_shortName(_strArg('filePath'))}');
      case 'apk_parse_arsc_cpp':
        return (LucideIcons.database, '解析 resources.arsc');
      case 'attempt_completion':
        return (LucideIcons.circleCheck, '任务完成');
    }
    return (LucideIcons.smartphone, _tool);
  }

  String _processingLabel() => switch (_tool) {
        'dex_open_apk' || 'dex_open' => '打开 APK 中...',
        'dex_search' => '搜索中...',
        'dex_get_class' || 'dex_get_method' => '读取反汇编中...',
        'dex_smali_to_java' => '反编译中...',
        'dex_save' => '编译并保存中...',
        _ when _tool.startsWith('dex_modify') ||
            _tool.startsWith('dex_add') ||
            _tool.startsWith('dex_delete') ||
            _tool.startsWith('dex_rename') =>
          '修改中...',
        _ when _tool.startsWith('apk_') => '处理 APK 中...',
        _ => 'DEX 编辑器执行中...',
      };

  // ----- body -----

  Widget? _body(ThemeData theme) {
    // 代码类：类/方法反汇编、Java 反编译、清单 / 资源正文 —— 用代码块渲染。
    final code = _codeContent();
    if (code != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: CodeBlockView(language: code.$1, code: code.$2),
      );
    }

    final data = _dataMap();
    switch (_tool) {
      case 'dex_list_classes':
        return _classesBody(theme, data?['classes'], data);
      case 'dex_search':
        return _searchBody(theme, data?['results']);
      case 'dex_list_sessions':
        return _sessionsBody(theme, data?['sessions']);
      case 'dex_open_apk':
        return _stringListBody(theme, data?['dexFiles'], LucideIcons.fileCode);
      case 'dex_find_xrefs':
        return _xrefsBody(theme, data?['xrefs']);
      case 'apk_list_resources':
        return _resourcesBody(theme, data?['resources']);
      case 'apk_list_files':
        return _filesBody(theme, data?['files']);
    }

    // 修改/保存等以文本提示为主的结果（含 ✅ 提示）：直接展示正文文本。
    final text = _plainText();
    if (text != null && text.trim().isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: Text(text.trim(), style: theme.textTheme.bodySmall),
      );
    }
    // 兜底：其余结构化 JSON 以键值形式展示。
    if (data != null && data.isNotEmpty) return _kvBody(theme, data);
    return null;
  }

  Widget _classesBody(ThemeData theme, Object? classes, Map<String, Object?>? data) {
    if (classes is! List || classes.isEmpty) {
      return _emptyBody(theme, '没有类');
    }
    return Column(
      children: [
        for (final c in classes)
          if (c is Map)
            _simpleRow(
              theme,
              icon: LucideIcons.fileCode,
              title: _pick(c, ['className', 'name']) ?? c.toString(),
            )
          else
            _simpleRow(theme, icon: LucideIcons.fileCode, title: c.toString()),
        if (data?['hasMore'] == true) _moreRow(theme),
      ],
    );
  }

  Widget _searchBody(ThemeData theme, Object? results) {
    if (results is! List || results.isEmpty) {
      return _emptyBody(theme, '没有命中的结果');
    }
    return Column(
      children: [
        for (final r in results)
          if (r is Map)
            _simpleRow(
              theme,
              icon: LucideIcons.search,
              title: _searchTitle(r),
              trailing: _pick(r, ['type']),
            )
          else
            _simpleRow(theme, icon: LucideIcons.search, title: r.toString()),
      ],
    );
  }

  /// 搜索命中的展示名：类名 +（方法/字段/父类/接口/注解等）成员，缺失字段在
  /// 原生结果里是空字符串而非缺键，故用 `_pick` 取第一个非空值再拼接。
  String _searchTitle(Map<Object?, Object?> r) {
    final cls = _pick(r, ['className']);
    final member = _pick(r, [
      'methodName',
      'fieldName',
      'name',
      'superclass',
      'interface',
      'annotation',
      'value',
    ]);
    if (cls != null && member != null) return '${_shortName(cls)} · $member';
    return cls ?? member ?? r.toString();
  }

  Widget _sessionsBody(ThemeData theme, Object? sessions) {
    if (sessions is! List || sessions.isEmpty) {
      return _emptyBody(theme, '当前没有打开的会话');
    }
    return Column(
      children: [
        for (final s in sessions)
          if (s is Map)
            _simpleRow(
              theme,
              icon: LucideIcons.folderOpen,
              title: _pick(s, ['apkPath', 'sessionId']) ?? s.toString(),
              trailing: s['classCount'] != null ? '${s['classCount']} 类' : null,
            ),
      ],
    );
  }

  Widget _xrefsBody(ThemeData theme, Object? xrefs) {
    if (xrefs is! List || xrefs.isEmpty) {
      return _emptyBody(theme, '没有交叉引用');
    }
    return Column(
      children: [
        for (final x in xrefs)
          if (x is Map)
            _simpleRow(
              theme,
              icon: LucideIcons.gitFork,
              title: _pick(x, ['className', 'caller']) ?? x.toString(),
              trailing: _pick(x, ['methodName', 'line']),
            )
          else
            _simpleRow(theme, icon: LucideIcons.gitFork, title: x.toString()),
      ],
    );
  }

  Widget _resourcesBody(ThemeData theme, Object? resources) {
    if (resources is! List || resources.isEmpty) {
      return _emptyBody(theme, '没有资源');
    }
    return Column(
      children: [
        for (final r in resources)
          if (r is Map)
            _simpleRow(
              theme,
              icon: LucideIcons.image,
              title: _pick(r, ['path', 'name']) ?? r.toString(),
              trailing: _pick(r, ['type']),
            )
          else
            _simpleRow(theme, icon: LucideIcons.image, title: r.toString()),
      ],
    );
  }

  Widget _filesBody(ThemeData theme, Object? files) {
    if (files is! List || files.isEmpty) {
      return _emptyBody(theme, '没有文件');
    }
    return Column(
      children: [
        for (final f in files)
          if (f is Map)
            _simpleRow(
              theme,
              icon: LucideIcons.file,
              title: _pick(f, ['path', 'name']) ?? f.toString(),
              trailing: f['size'] != null ? '${f['size']} B' : null,
            )
          else
            _simpleRow(theme, icon: LucideIcons.file, title: f.toString()),
      ],
    );
  }

  Widget _stringListBody(ThemeData theme, Object? items, IconData icon) {
    if (items is! List || items.isEmpty) return _emptyBody(theme, '空');
    return Column(
      children: [
        for (final i in items)
          _simpleRow(theme, icon: icon, title: i.toString()),
      ],
    );
  }

  Widget _kvBody(ThemeData theme, Map<String, Object?> data) {
    final entries = <(String, String)>[
      for (final MapEntry(:key, :value) in data.entries)
        if (value is! List && value is! Map && key != 'hint')
          (key, value.toString()),
    ];
    if (entries.isEmpty) return _emptyBody(theme, '无更多信息');
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, value) in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(value, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _moreRow(ThemeData theme) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          '还有更多，可继续翻页…',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );

  Widget _simpleRow(
    ThemeData theme, {
    required IconData icon,
    required String title,
    String? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (trailing != null && trailing.isNotEmpty)
            Text(
              trailing,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  /// First non-empty value among [keys] of [m], or null. dex 原生结果里缺失字段
  /// 常返回空字符串（而非缺键），直接 `?? ` 会被空串截断，用它统一取第一个非空值。
  String? _pick(Map<Object?, Object?> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return null;
  }

  Widget _emptyBody(ThemeData theme, String message) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );

  // ----- content parsing -----

  /// The block's textual content, or null.
  String? _plainText() {
    final content = block.content;
    return content is String ? content : null;
  }

  /// Parsed JSON object from the content, or null if the content is plain text
  /// / a JSON array / not JSON. dex tools that return structured data emit a
  /// bare JSON object (no `{success,data}` wrapper).
  Map<String, Object?>? _dataMap() {
    final content = _plainText();
    if (content == null || content.isEmpty) return null;
    // 交叉引用返回体前面带一行「找到 N 个交叉引用:」文本，JSON 在其后。
    final start = content.indexOf('{');
    if (start < 0) return null;
    try {
      final decoded = jsonDecode(content.substring(start));
      if (decoded is Map) return decoded.cast<String, Object?>();
    } catch (_) {}
    return null;
  }

  /// `(language, code)` when this tool's result should render as a code block:
  /// class/method smali, decompiled Java, manifest/resource text. Paginated
  /// readers wrap the body in JSON `{content: ...}`; raw readers return the text
  /// directly.
  (String, String)? _codeContent() {
    String lang;
    switch (_tool) {
      case 'dex_get_class':
      case 'dex_get_method':
        lang = 'smali';
      case 'dex_smali_to_java':
        lang = 'java';
      case 'apk_get_manifest':
      case 'apk_get_resource':
        lang = 'xml';
      default:
        return null;
    }
    final data = _dataMap();
    if (data != null && data['content'] is String) {
      return (lang, data['content'] as String);
    }
    // 无 offset/maxChars 时 dex 工具直接返回纯文本正文。
    final text = _plainText();
    if (text != null && text.trim().isNotEmpty && !text.startsWith('{')) {
      return (lang, text);
    }
    return null;
  }

  String _apkName() => _shortName(_strArg('apkPath'));

  String _resourceName() =>
      _strArg('resourcePath').isNotEmpty ? _strArg('resourcePath') : _strArg('id');

  String _shortClass() => _shortName(
        _strArg('className').isNotEmpty
            ? _strArg('className')
            : _strArg('oldClassName'),
      );

  /// Last path/class segment, for a compact header. Handles both `/` (paths)
  /// and `.` (dotted class names).
  String _shortName(String value) {
    if (value.isEmpty) return '';
    final slash = value.split('/').last;
    final seg = slash.split('.');
    // 类名 com.x.Foo → Foo；文件名 a/b/c.xml → c.xml（保留扩展名）。
    if (slash.contains('/') || value.contains('/')) return slash;
    return seg.length > 1 && !slash.contains('.xml') ? seg.last : slash;
  }

  String _strArg(String key) => _args[key]?.toString() ?? '';

  bool _isErrorContent() {
    final text = _plainText();
    if (text == null) return false;
    return text.startsWith('错误') ||
        text.startsWith('修改失败') ||
        text.startsWith('删除') && text.contains('失败') ||
        text.contains('失败:') ||
        _dataMap()?['success'] == false;
  }

  String? _errorMessage() {
    final data = _dataMap();
    if (data != null && data['error'] != null) return data['error'].toString();
    final text = _plainText();
    if (text != null && text.isNotEmpty) return text.trim();
    final blockErr = block.error;
    if (blockErr != null && blockErr['message'] is String) {
      return blockErr['message'] as String;
    }
    return null;
  }
}
