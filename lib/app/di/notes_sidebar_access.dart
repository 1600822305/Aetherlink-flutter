import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/chat/application/sidebar_settings_controller.dart';

part 'notes_sidebar_access.g.dart';

/// App-level composition seam for the「侧边栏笔记入口」toggle.
///
/// The flag physically lives in chat's [SidebarSettings] (the sidebar reads it
/// reactively to add/remove the 笔记 Tab). The notes feature owns the *settings
/// UI* for it, but the import-boundary rule forbids `notes` from importing
/// `chat/application`. So the read/write is composed here in `app/` (the
/// composition root, which may depend on any feature) and the notes settings
/// page depends only on this seam.

/// Whether the sidebar 笔记 Tab is enabled (reactive).
@riverpod
bool notesSidebarTabEnabled(Ref ref) =>
    ref.watch(sidebarSettingsControllerProvider).showNotesSidebarTab;

/// Setter handle for the sidebar 笔记 Tab toggle.
class NotesSidebarTabToggle {
  const NotesSidebarTabToggle(this._ref);

  final Ref _ref;

  void set(bool value) => _ref
      .read(sidebarSettingsControllerProvider.notifier)
      .setShowNotesSidebarTab(value);
}

@Riverpod(keepAlive: true)
NotesSidebarTabToggle notesSidebarTabToggle(Ref ref) =>
    NotesSidebarTabToggle(ref);
