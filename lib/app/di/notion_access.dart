import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/notion/application/notion_export_service.dart';
import 'package:aetherlink_flutter/features/notion/application/notion_settings_controller.dart';
import 'package:aetherlink_flutter/features/notion/domain/notion_settings.dart';

part 'notion_access.g.dart';

/// App-level composition seam for the Notion 集成 (same pattern as
/// `app_settings_access.dart`): chat UI must not import notion's
/// `application`, so it reaches the export service and the current settings
/// through these providers instead.
@Riverpod(keepAlive: true)
NotionExportService notionExportService(Ref ref) =>
    NotionExportService(repository: ref.watch(chatRepositoryProvider));

/// The live Notion settings, re-exposed for cross-feature consumers (chat's
/// export entry points use [NotionSettings.isConfigured] for visibility).
@Riverpod(keepAlive: true)
NotionSettings notionSettings(Ref ref) =>
    ref.watch(notionSettingsControllerProvider);
