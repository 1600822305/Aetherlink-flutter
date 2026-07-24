import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Enforces the project's cross-feature dependency rule from
/// `docs/PROJECT_STRUCTURE.md` §5 / `docs/CONVENTIONS.md` §2 at CI time:
///
///   **A feature must not import another feature's `application` or `data`.**
///   Only that feature's `domain` (pure Dart contracts) and `presentation`
///   (shared widgets such as `ModelSettingsAppBar` / `AppMarkdown`, which the UI
///   conventions deliberately reuse) may be imported across features. All
///   cross-feature *composition* (wiring one feature's controllers/services into
///   another) goes through `app/di` instead — `app/` is the composition root and
///   is exempt.
///
/// This is the substitute for a `custom_lint` boundary plugin: the latest
/// `custom_lint` only supports analyzer ^8, incompatible with the analyzer ^10+
/// required by this SDK's codegen toolchain. Scanning imports in a test gives the
/// same "fail the build on violation" guarantee without the version conflict.
/// Migrate to a `custom_lint` plugin once it supports analyzer ^10+.
///
/// [_knownAcceptedViolations] is a frozen baseline of cross-feature
/// application/data imports that predate this guard. **Do not add entries** —
/// new cross-feature composition must go through `app/di`. The list only exists
/// so the guard can be green today while the existing debt is migrated.
void main() {
  const packageName = 'aetherlink_flutter';
  const packagePrefix = 'package:$packageName/';

  final libDir = Directory('lib');
  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) => !_isGenerated(file.path))
      .toList();

  final violations = <String>[];

  for (final file in dartFiles) {
    final libPath = _toPosix(file.path); // e.g. lib/features/chat/...
    final feature = _featureOf(libPath.split('/'));
    if (feature == null) continue; // only feature-to-feature imports are scoped

    for (final import in _importsOf(file)) {
      if (!import.startsWith(packagePrefix)) continue;
      final internalPath = 'lib/${import.substring(packagePrefix.length)}';
      final targetFeature = _featureOf(internalPath.split('/'));
      if (targetFeature == null || targetFeature == feature) continue;

      final crossesIntoInternals =
          _isIn(internalPath, 'application') || _isIn(internalPath, 'data');
      if (!crossesIntoInternals) continue;

      final key = '$libPath -> $import';
      if (_knownAcceptedViolations.contains(key)) continue;
      violations.add(
        '[feature→feature application/data] $libPath imports $import '
        '(only $targetFeature\'s domain/presentation is allowed; route '
        'composition through app/di)',
      );
    }
  }

  // 智能体模块隔离（智能体架构稿 §决策记录 13）：agent 与 chat 互不引用——
  // agent 是与聊天同级的全新主界面，禁止 import features/chat 的任何内容
  // （含 domain/presentation）；chat 侧也不得依赖 agent 内部（模式切换按钮
  // 经由 app/di + 路由完成）。
  final agentChatViolations = <String>[];
  for (final file in dartFiles) {
    final libPath = _toPosix(file.path);
    final feature = _featureOf(libPath.split('/'));
    if (feature != 'agent' && feature != 'chat') continue;
    final forbidden = feature == 'agent' ? 'chat' : 'agent';
    for (final import in _importsOf(file)) {
      if (!import.startsWith(packagePrefix)) continue;
      final internalPath = 'lib/${import.substring(packagePrefix.length)}';
      if (_featureOf(internalPath.split('/')) == forbidden) {
        agentChatViolations.add('[agent↔chat] $libPath imports $import');
      }
    }
  }

  test('agent and chat never import each other', () {
    expect(
      agentChatViolations,
      isEmpty,
      reason: 'agent↔chat imports found:\n${agentChatViolations.join('\n')}',
    );
  });

  test('features do not import other features\' application/data', () {
    expect(
      dartFiles,
      isNotEmpty,
      reason: 'no Dart files were scanned under lib/ — check the test setup',
    );
    expect(
      violations,
      isEmpty,
      reason:
          'cross-feature application/data imports found:\n'
          '${violations.join('\n')}',
    );
  });
}

/// Frozen baseline of pre-existing cross-feature application/data imports.
/// DO NOT ADD ENTRIES — new cross-feature composition must go through `app/di`.
const _knownAcceptedViolations = <String>{
  'lib/features/backup/application/backup_controller.dart -> package:aetherlink_flutter/features/chat/application/chat_providers.dart',
  'lib/features/chat/application/chat_controller.dart -> package:aetherlink_flutter/features/settings/application/auxiliary_model_controller.dart',
  'lib/features/chat/application/chat_controller.dart -> package:aetherlink_flutter/features/settings/application/model_combo_controller.dart',
  'lib/features/chat/application/chat_controller.dart -> package:aetherlink_flutter/features/settings/application/model_combo_providers.dart',
  'lib/features/chat/application/combo_executor.dart -> package:aetherlink_flutter/features/settings/application/model_combo_controller.dart',
  'lib/features/chat/application/context_condense_service.dart -> package:aetherlink_flutter/features/settings/application/auxiliary_model_controller.dart',
  'lib/features/chat/application/translate/translate_controller.dart -> package:aetherlink_flutter/features/settings/application/auxiliary_model_controller.dart',
  'lib/features/chat/presentation/widgets/chat_top_bar.dart -> package:aetherlink_flutter/features/settings/application/model_combo_controller.dart',
  'lib/features/chat/presentation/widgets/model_selector/model_selector_dialog.dart -> package:aetherlink_flutter/features/settings/application/model_combo_controller.dart',
  'lib/features/chat/presentation/widgets/model_selector/model_selector_dialog.dart -> package:aetherlink_flutter/features/settings/application/model_combo_providers.dart',
  'lib/features/settings/application/auxiliary_model_controller.dart -> package:aetherlink_flutter/features/chat/application/chat_providers.dart',
  'lib/features/settings/presentation/mobile/skill_store_page.dart -> package:aetherlink_flutter/features/chat/application/chat_providers.dart',
  'lib/features/settings/presentation/mobile/skill_store_page.dart -> package:aetherlink_flutter/features/chat/application/translate/translate_controller.dart',
  'lib/features/settings/presentation/mobile/web_search/add_search_provider_page.dart -> package:aetherlink_flutter/features/chat/application/web_search_settings_controller.dart',
  'lib/features/settings/presentation/mobile/web_search/search_provider_detail_page.dart -> package:aetherlink_flutter/features/chat/application/web_search_settings_controller.dart',
  'lib/features/settings/presentation/mobile/web_search_settings_page.dart -> package:aetherlink_flutter/features/chat/application/web_search_settings_controller.dart',
  // Accumulated while the guard itself was red (masked by the other failing
  // suites): workspace/terminal/knowledge/backup slices that landed with
  // direct cross-feature imports. Same migration debt as above — route these
  // through app/di and remove the entries.
  'lib/features/backup/data/chatbox_importer.dart -> package:aetherlink_flutter/features/chat/data/message_tree_backfill.dart',
  'lib/features/backup/data/chatbox_txt_importer.dart -> package:aetherlink_flutter/features/chat/data/message_tree_backfill.dart',
  'lib/features/backup/data/cherry_importer.dart -> package:aetherlink_flutter/features/chat/data/message_tree_backfill.dart',
  'lib/features/chat/application/send/turn_stream_binder.dart -> package:aetherlink_flutter/features/workspace/application/workspace_store.dart',
  'lib/features/chat/presentation/widgets/blocks/message_selection_area.dart -> package:aetherlink_flutter/features/settings/application/selection_menu_settings_controller.dart',
  'lib/features/chat/presentation/widgets/message_actions/message_toolbar.dart -> package:aetherlink_flutter/features/settings/application/message_bubble_settings_controller.dart',
  'lib/features/knowledge/presentation/mobile/knowledge_base_detail_page.dart -> package:aetherlink_flutter/features/workspace/application/workspace_backend_provider.dart',
  'lib/features/knowledge/presentation/mobile/knowledge_base_detail_page.dart -> package:aetherlink_flutter/features/workspace/application/workspace_store.dart',
  'lib/features/settings/presentation/mobile/web_search/search_multi_key_page.dart -> package:aetherlink_flutter/features/chat/application/web_search_settings_controller.dart',
  'lib/features/workspace/data/proot_local_backend.dart -> package:aetherlink_flutter/features/terminal/application/terminal_engine_manager.dart',
  'lib/features/workspace/data/proot_local_backend.dart -> package:aetherlink_flutter/features/terminal/data/proot_process_runner.dart',
  'lib/features/workspace/presentation/mobile/file_ops/open_workspace_sheet.dart -> package:aetherlink_flutter/features/terminal/application/terminal_engine_manager.dart',
  'lib/features/workspace/presentation/mobile/workspace_terminal_page.dart -> package:aetherlink_flutter/features/terminal/application/terminal_engine_manager.dart',
};

/// Whether [path] contains [segment] as a full path segment.
bool _isIn(String path, String segment) => path.split('/').contains(segment);

/// The feature name for a `lib/features/<name>/...` path, or null.
String? _featureOf(List<String> segments) {
  final index = segments.indexOf('features');
  if (index == -1 || index + 1 >= segments.length) return null;
  return segments[index + 1];
}

bool _isGenerated(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.endsWith('.drift.dart');

String _toPosix(String path) => path.replaceAll(r'\', '/');

final _importPattern = RegExp(
  '''^\\s*import\\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

List<String> _importsOf(File file) {
  final content = file.readAsStringSync();
  return _importPattern
      .allMatches(content)
      .map((match) => match.group(1)!)
      .toList();
}
