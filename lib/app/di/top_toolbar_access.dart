import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/settings/application/top_toolbar_settings_controller.dart';
import 'package:aetherlink_flutter/shared/domain/top_toolbar_settings.dart';

part 'top_toolbar_access.g.dart';

/// App-level composition seam for cross-feature reads of the top-toolbar DIY
/// config.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`;
/// only its `domain` is allowed. The `settings` feature owns
/// [TopToolbarSettingsController], but `chat`'s top bar must follow the same
/// layout the appearance 顶部工具栏 DIY 设置 page edits, so the read provider is
/// re-exposed here in `app/` (the composition root, which may depend on any
/// feature). The chat layer watches this plus the pure-Dart [TopToolbarSettings]
/// domain type — never `settings/application` directly.
@Riverpod(keepAlive: true)
TopToolbarSettings appTopToolbarSettings(Ref ref) =>
    ref.watch(topToolbarSettingsControllerProvider);
