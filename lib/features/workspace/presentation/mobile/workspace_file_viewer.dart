// The middle page in "file open" state. Hosts the file editor, which shows the
// content of the file selected in the left tree and — on writable (SAF)
// backends — lets the user edit, find/replace and save it. Reads from the
// shared preview backend (the opened workspace's real backend).

import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/file_editor.dart';

class WorkspaceFileViewer extends StatelessWidget {
  const WorkspaceFileViewer({
    super.key,
    required this.entry,
    required this.topInset,
  });

  final WorkspaceEntry entry;
  final double topInset;

  @override
  Widget build(BuildContext context) =>
      FileEditor(entry: entry, topInset: topInset);
}
