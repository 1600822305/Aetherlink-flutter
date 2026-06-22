import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

/// Tool permission level — mirrors the original `ToolPermission`.
///   read:    direct execution, no user prompt
///   write:   low-risk config change, direct execution
///   confirm: destructive / sensitive, AI description asks user to confirm
enum SettingsToolPermission { read, write, confirm }

/// Metadata for each settings tool (used by the UI detail pages).
class SettingsToolMeta {
  const SettingsToolMeta({
    required this.name,
    required this.permission,
    required this.description,
  });

  final String name;
  final SettingsToolPermission permission;
  final String description;
}

/// Domain → tools mapping for the settings assistant.
const String kSettingsDomainProviders = 'providers';

/// All settings tool metadata, grouped by domain.
const Map<String, List<SettingsToolMeta>> kSettingsToolMeta = {
  kSettingsDomainProviders: [
    SettingsToolMeta(
      name: 'list_providers',
      permission: SettingsToolPermission.read,
      description: '列出所有模型供应商及其状态',
    ),
    SettingsToolMeta(
      name: 'get_provider',
      permission: SettingsToolPermission.read,
      description: '获取指定供应商的详细信息',
    ),
    SettingsToolMeta(
      name: 'toggle_provider',
      permission: SettingsToolPermission.write,
      description: '启用或禁用指定供应商',
    ),
    SettingsToolMeta(
      name: 'update_provider_config',
      permission: SettingsToolPermission.write,
      description: '更新供应商的 API 密钥、基础 URL 等配置',
    ),
    SettingsToolMeta(
      name: 'create_provider',
      permission: SettingsToolPermission.confirm,
      description: '创建一个新的模型供应商（需要用户确认）',
    ),
    SettingsToolMeta(
      name: 'delete_provider',
      permission: SettingsToolPermission.confirm,
      description: '删除指定的模型供应商（需要用户确认）',
    ),
    SettingsToolMeta(
      name: 'list_models',
      permission: SettingsToolPermission.read,
      description: '列出指定供应商的所有模型',
    ),
    SettingsToolMeta(
      name: 'get_current_model',
      permission: SettingsToolPermission.read,
      description: '获取当前正在使用的默认模型',
    ),
    SettingsToolMeta(
      name: 'set_default_model',
      permission: SettingsToolPermission.write,
      description: '设置全局默认聊天模型',
    ),
    SettingsToolMeta(
      name: 'toggle_model',
      permission: SettingsToolPermission.write,
      description: '启用或禁用供应商中的指定模型',
    ),
    SettingsToolMeta(
      name: 'add_model',
      permission: SettingsToolPermission.confirm,
      description: '向供应商添加一个新模型（需要用户确认）',
    ),
    SettingsToolMeta(
      name: 'delete_model',
      permission: SettingsToolPermission.confirm,
      description: '从供应商中删除指定模型（需要用户确认）',
    ),
  ],
};

/// Infer which domain a tool name belongs to.
String inferSettingsDomain(String toolName) => kSettingsDomainProviders;

/// Infer tool permission from metadata.
SettingsToolPermission inferSettingsPermission(String toolName) {
  for (final tools in kSettingsToolMeta.values) {
    for (final tool in tools) {
      if (tool.name == toolName) return tool.permission;
    }
  }
  return SettingsToolPermission.read;
}

// ─── Execution ──────────────────────────────────────────────────────────────

/// Executes a settings tool call. Requires a [Ref] to access the model store.
Future<McpToolResult> runSettingsTool(
  Ref ref,
  String toolName,
  Map<String, Object?> args,
) async {
  switch (toolName) {
    case 'list_providers':
      return _listProviders(ref);
    case 'get_provider':
      return _getProvider(ref, args);
    case 'toggle_provider':
      return _toggleProvider(ref, args);
    case 'update_provider_config':
      return _updateProviderConfig(ref, args);
    case 'create_provider':
      return _createProvider(ref, args);
    case 'delete_provider':
      return _deleteProvider(ref, args);
    case 'list_models':
      return _listModels(ref, args);
    case 'get_current_model':
      return _getCurrentModel(ref);
    case 'set_default_model':
      return _setDefaultModel(ref, args);
    case 'toggle_model':
      return _toggleModel(ref, args);
    case 'add_model':
      return _addModel(ref, args);
    case 'delete_model':
      return _deleteModel(ref, args);
    default:
      return _error('未知的工具: $toolName');
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

McpToolResult _ok(Object? data) =>
    McpToolResult(_encode({'success': true, 'data': data}));

McpToolResult _error(String message) =>
    McpToolResult(_encode({'success': false, 'error': message}), isError: true);

String _encode(Object? obj) => const JsonEncoder.withIndent('  ').convert(obj);

Future<List<ModelProvider>> _providers(Ref ref) =>
    ref.read(appModelRepositoryProvider).getProviders();

Future<ModelProvider?> _providerById(Ref ref, String id) async {
  final providers = await _providers(ref);
  for (final p in providers) {
    if (p.id == id) return p;
  }
  return null;
}

Map<String, Object?> _providerSummary(ModelProvider p) => {
  'id': p.id,
  'name': p.name,
  'type': p.providerType ?? 'openai',
  'isEnabled': p.isEnabled,
  'modelCount': p.models.length,
  'hasApiKey': p.apiKey != null && p.apiKey!.isNotEmpty,
  'baseUrl': p.baseUrl,
};

Map<String, Object?> _modelSummary(Model m) => {
  'id': m.id,
  'name': m.name,
  'enabled': m.enabled ?? true,
  'isDefault': m.isDefault ?? false,
  'group': m.group,
};

// ─── Provider Tools ─────────────────────────────────────────────────────────

Future<McpToolResult> _listProviders(Ref ref) async {
  final providers = await _providers(ref);
  return _ok(providers.map(_providerSummary).toList());
}

Future<McpToolResult> _getProvider(Ref ref, Map<String, Object?> args) async {
  final id = args['id'] as String?;
  if (id == null || id.isEmpty) return _error('缺少参数: id');
  final provider = await _providerById(ref, id);
  if (provider == null) return _error('供应商不存在: $id');
  return _ok({
    ..._providerSummary(provider),
    'avatar': provider.avatar,
    'color': provider.color,
    'models': provider.models.map(_modelSummary).toList(),
  });
}

Future<McpToolResult> _toggleProvider(
  Ref ref,
  Map<String, Object?> args,
) async {
  final id = args['id'] as String?;
  final enabled = args['enabled'] as bool?;
  if (id == null || id.isEmpty) return _error('缺少参数: id');
  if (enabled == null) return _error('缺少参数: enabled');
  final provider = await _providerById(ref, id);
  if (provider == null) return _error('供应商不存在: $id');
  await ref
      .read(modelStoreProvider.notifier)
      .saveProvider(provider.copyWith(isEnabled: enabled));
  return _ok({'id': id, 'isEnabled': enabled});
}

Future<McpToolResult> _updateProviderConfig(
  Ref ref,
  Map<String, Object?> args,
) async {
  final id = args['id'] as String?;
  if (id == null || id.isEmpty) return _error('缺少参数: id');
  final provider = await _providerById(ref, id);
  if (provider == null) return _error('供应商不存在: $id');

  var updated = provider;
  if (args.containsKey('apiKey')) {
    updated = updated.copyWith(apiKey: args['apiKey'] as String?);
  }
  if (args.containsKey('baseUrl')) {
    updated = updated.copyWith(baseUrl: args['baseUrl'] as String?);
  }
  if (args.containsKey('name')) {
    updated = updated.copyWith(name: args['name'] as String? ?? provider.name);
  }
  await ref.read(modelStoreProvider.notifier).saveProvider(updated);
  return _ok({'id': id, 'updated': true});
}

Future<McpToolResult> _createProvider(
  Ref ref,
  Map<String, Object?> args,
) async {
  final name = args['name'] as String?;
  final type = args['type'] as String? ?? 'openai';
  if (name == null || name.trim().isEmpty) return _error('缺少参数: name');
  final id = generateId('provider');
  final avatar = name.isNotEmpty ? name[0].toUpperCase() : 'P';
  final provider = ModelProvider(
    id: id,
    name: name.trim(),
    avatar: avatar,
    color: '#64748B',
    isEnabled: true,
    providerType: type,
    apiKey: args['apiKey'] as String?,
    baseUrl: args['baseUrl'] as String?,
  );
  await ref.read(modelStoreProvider.notifier).saveProvider(provider);
  return _ok({'id': id, 'name': provider.name, 'created': true});
}

Future<McpToolResult> _deleteProvider(
  Ref ref,
  Map<String, Object?> args,
) async {
  final id = args['id'] as String?;
  if (id == null || id.isEmpty) return _error('缺少参数: id');
  final provider = await _providerById(ref, id);
  if (provider == null) return _error('供应商不存在: $id');
  await ref.read(modelStoreProvider.notifier).deleteProvider(id);
  return _ok({'id': id, 'name': provider.name, 'deleted': true});
}

// ─── Model Tools ────────────────────────────────────────────────────────────

Future<McpToolResult> _listModels(Ref ref, Map<String, Object?> args) async {
  final providerId = args['providerId'] as String?;
  if (providerId == null || providerId.isEmpty) {
    return _error('缺少参数: providerId');
  }
  final provider = await _providerById(ref, providerId);
  if (provider == null) return _error('供应商不存在: $providerId');
  return _ok({
    'provider': provider.name,
    'models': provider.models.map(_modelSummary).toList(),
  });
}

Future<McpToolResult> _getCurrentModel(Ref ref) async {
  final providers = await _providers(ref);
  final current = findCurrentModel(providers);
  if (current == null) return _ok({'selected': false});
  return _ok({
    'selected': true,
    'provider': {'id': current.provider.id, 'name': current.provider.name},
    'model': _modelSummary(current.model),
  });
}

Future<McpToolResult> _setDefaultModel(
  Ref ref,
  Map<String, Object?> args,
) async {
  final providerId = args['providerId'] as String?;
  final modelId = args['modelId'] as String?;
  if (providerId == null || providerId.isEmpty) {
    return _error('缺少参数: providerId');
  }
  if (modelId == null || modelId.isEmpty) return _error('缺少参数: modelId');
  final provider = await _providerById(ref, providerId);
  if (provider == null) return _error('供应商不存在: $providerId');
  final hasModel = provider.models.any((m) => m.id == modelId);
  if (!hasModel) return _error('模型不存在: $modelId');
  await ref
      .read(modelStoreProvider.notifier)
      .selectCurrentModel(providerId: providerId, modelId: modelId);
  return _ok({'providerId': providerId, 'modelId': modelId, 'set': true});
}

Future<McpToolResult> _toggleModel(Ref ref, Map<String, Object?> args) async {
  final providerId = args['providerId'] as String?;
  final modelId = args['modelId'] as String?;
  final enabled = args['enabled'] as bool?;
  if (providerId == null || providerId.isEmpty) {
    return _error('缺少参数: providerId');
  }
  if (modelId == null || modelId.isEmpty) return _error('缺少参数: modelId');
  if (enabled == null) return _error('缺少参数: enabled');
  final provider = await _providerById(ref, providerId);
  if (provider == null) return _error('供应商不存在: $providerId');
  final models = [
    for (final m in provider.models)
      if (m.id == modelId) m.copyWith(enabled: enabled) else m,
  ];
  if (models.length == provider.models.length &&
      !provider.models.any((m) => m.id == modelId)) {
    return _error('模型不存在: $modelId');
  }
  await ref
      .read(modelStoreProvider.notifier)
      .saveProvider(provider.copyWith(models: models));
  return _ok({
    'providerId': providerId,
    'modelId': modelId,
    'enabled': enabled,
  });
}

Future<McpToolResult> _addModel(Ref ref, Map<String, Object?> args) async {
  final providerId = args['providerId'] as String?;
  final modelId = args['modelId'] as String?;
  final modelName = args['modelName'] as String?;
  if (providerId == null || providerId.isEmpty) {
    return _error('缺少参数: providerId');
  }
  if (modelId == null || modelId.isEmpty) return _error('缺少参数: modelId');
  final provider = await _providerById(ref, providerId);
  if (provider == null) return _error('供应商不存在: $providerId');
  if (provider.models.any((m) => m.id == modelId)) {
    return _error('模型已存在: $modelId');
  }
  final model = Model(
    id: modelId,
    name: modelName ?? modelId,
    provider: providerId,
    enabled: true,
  );
  await ref
      .read(modelStoreProvider.notifier)
      .addModels(providerId: providerId, models: [model]);
  return _ok({
    'providerId': providerId,
    'modelId': modelId,
    'name': model.name,
    'added': true,
  });
}

Future<McpToolResult> _deleteModel(Ref ref, Map<String, Object?> args) async {
  final providerId = args['providerId'] as String?;
  final modelId = args['modelId'] as String?;
  if (providerId == null || providerId.isEmpty) {
    return _error('缺少参数: providerId');
  }
  if (modelId == null || modelId.isEmpty) return _error('缺少参数: modelId');
  final provider = await _providerById(ref, providerId);
  if (provider == null) return _error('供应商不存在: $providerId');
  if (!provider.models.any((m) => m.id == modelId)) {
    return _error('模型不存在: $modelId');
  }
  final models = provider.models.where((m) => m.id != modelId).toList();
  await ref
      .read(modelStoreProvider.notifier)
      .saveProvider(provider.copyWith(models: models));
  return _ok({'providerId': providerId, 'modelId': modelId, 'deleted': true});
}
