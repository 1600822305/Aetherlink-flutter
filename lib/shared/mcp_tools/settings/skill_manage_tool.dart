import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/skills_access.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/domain/skill.dart';

/// `skill_manage`：让模型自助管理技能库（全局配置，与设置页同一份
/// 存储）。list 免审批；add/update/remove/toggle 走 HITL 审批。
/// 内置技能只能启停，不能改正文或删除；技能正文用 read_skill 读取。
const String kSkillManageToolName = 'skill_manage';

const McpToolDefinition kSkillManageToolDefinition = McpToolDefinition(
  name: kSkillManageToolName,
  description:
      '管理技能库（全局配置）：list 列出 / add 新建 / update 修改 / '
      'remove 删除 / toggle 启停。技能正文用 read_skill 读取；'
      '内置技能只能启停。',
  inputSchema: {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': ['list', 'add', 'update', 'remove', 'toggle'],
        'description': '操作类型',
      },
      'name': {
        'type': 'string',
        'description': 'add 必填：技能名称；update/remove/toggle 可用名称或 id 定位',
      },
      'id': {'type': 'string', 'description': 'update/remove/toggle 定位用技能 id'},
      'description': {'type': 'string', 'description': '一句话描述（add/update）'},
      'content': {
        'type': 'string',
        'description': '技能正文（SKILL.md 风格 Markdown 指令，add/update）',
      },
      'new_name': {'type': 'string', 'description': 'update 可选：改名'},
      'tags': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': '标签（add/update）',
      },
      'enabled': {'type': 'boolean', 'description': 'toggle 必填：是否启用'},
    },
    'required': ['action'],
  },
);

/// 除只读的 list 外都会改技能库，需用户审批。
bool skillManageNeedsConfirmation(Map<String, Object?> args) =>
    (args['action'] as String?)?.toLowerCase() != 'list';

/// 审批卡摘要。
String skillManageConfirmSummary(Map<String, Object?> args) {
  final action = (args['action'] as String?)?.toLowerCase();
  final target = args['name'] ?? args['id'] ?? '';
  switch (action) {
    case 'add':
      return '新建技能「$target」';
    case 'update':
      return '修改技能「$target」';
    case 'remove':
      return '删除技能「$target」';
    case 'toggle':
      return '${args['enabled'] == false ? '停用' : '启用'}技能「$target」';
    default:
      return '管理技能: ${action ?? '未知操作'}';
  }
}

Future<McpToolResult> runSkillManageTool(
  Ref ref,
  Map<String, Object?> args,
) async {
  final action = (args['action'] as String?)?.toLowerCase() ?? '';
  try {
    switch (action) {
      case 'list':
        return _list(ref);
      case 'add':
        return _add(ref, args);
      case 'update':
        return _update(ref, args);
      case 'remove':
        return _remove(ref, args);
      case 'toggle':
        return _toggle(ref, args);
      default:
        return _error('未知的 action: $action（可用：list/add/update/remove/toggle）');
    }
  } catch (e) {
    return _error('skill_manage 执行失败: $e');
  }
}

McpToolResult _ok(Object? data) => McpToolResult(
  const JsonEncoder.withIndent('  ').convert({'success': true, 'data': data}),
);

McpToolResult _error(String message) => McpToolResult(
  jsonEncode({'success': false, 'error': message}),
  isError: true,
);

Map<String, Object?> _summary(Skill s) => {
  'id': s.id,
  'name': s.name,
  'source': s.source.name,
  'enabled': s.enabled,
  if (s.version != null) 'version': s.version,
  if (s.description.isNotEmpty) 'description': s.description,
  if (s.tags.isNotEmpty) 'tags': s.tags,
};

Future<List<Skill>> _skills(Ref ref) => ref.read(skillsProvider.future);

Future<Skill?> _find(Ref ref, Map<String, Object?> args) async {
  final id = (args['id'] as String?)?.trim();
  final name = (args['name'] as String?)?.trim();
  final skills = await _skills(ref);
  if (id != null && id.isNotEmpty) {
    return skills.where((s) => s.id == id).firstOrNull;
  }
  if (name != null && name.isNotEmpty) {
    return skills.where((s) => s.name == name).firstOrNull ??
        skills
            .where((s) => s.name.toLowerCase() == name.toLowerCase())
            .firstOrNull;
  }
  return null;
}

Future<McpToolResult> _list(Ref ref) async {
  final skills = await _skills(ref);
  return _ok(skills.map(_summary).toList());
}

Future<McpToolResult> _add(Ref ref, Map<String, Object?> args) async {
  final name = (args['name'] as String?)?.trim() ?? '';
  if (name.isEmpty) return _error('add 需要 name');
  final existing = await _skills(ref);
  if (existing.any((s) => s.name == name)) {
    return _error('已存在同名技能「$name」（想改内容用 update）');
  }
  final skill = await ref
      .read(skillsProvider.notifier)
      .create(
        name: name,
        description: (args['description'] as String?)?.trim(),
        content: (args['content'] as String?) ?? '',
        tags: _stringList(args['tags']),
      );
  return _ok({'added': _summary(skill)});
}

Future<McpToolResult> _update(Ref ref, Map<String, Object?> args) async {
  final skill = await _find(ref, args);
  if (skill == null) return _error('找不到技能（用 name 或 id 定位，先 list 查看）');
  if (skill.source == SkillSource.builtin) {
    return _error('内置技能「${skill.name}」不能修改，只能 toggle 启停');
  }
  final newName = (args['new_name'] as String?)?.trim();
  final updated = skill.copyWith(
    name: (newName != null && newName.isNotEmpty) ? newName : skill.name,
    description: (args['description'] as String?)?.trim() ?? skill.description,
    content: (args['content'] as String?) ?? skill.content,
    tags: _stringList(args['tags']) ?? skill.tags,
  );
  await ref.read(skillsProvider.notifier).save(updated);
  return _ok({'updated': _summary(updated)});
}

Future<McpToolResult> _remove(Ref ref, Map<String, Object?> args) async {
  final skill = await _find(ref, args);
  if (skill == null) return _error('找不到技能（用 name 或 id 定位，先 list 查看）');
  if (skill.source == SkillSource.builtin) {
    return _error('内置技能「${skill.name}」不能删除，只能 toggle 停用');
  }
  await ref.read(skillsProvider.notifier).remove(skill.id);
  return _ok({'removed': skill.name});
}

Future<McpToolResult> _toggle(Ref ref, Map<String, Object?> args) async {
  final skill = await _find(ref, args);
  if (skill == null) return _error('找不到技能（用 name 或 id 定位，先 list 查看）');
  final enabled = args['enabled'];
  if (enabled is! bool) return _error('toggle 需要 enabled（true/false）');
  final done = await ref
      .read(skillsProvider.notifier)
      .toggle(skill.id, enabled: enabled);
  if (!done) {
    return _error('启用失败：已达同时启用上限（$kMaxEnabledSkills 个），请先停用其他技能');
  }
  return _ok({'name': skill.name, 'enabled': enabled});
}

List<String>? _stringList(Object? value) =>
    value is List ? value.map((e) => e.toString()).toList() : null;
