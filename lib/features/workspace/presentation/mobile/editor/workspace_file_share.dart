// The "用其他应用打开" escape hatch for files the editor can't render or edit
// (binary / too-large placeholders, image preview): reads the file's bytes
// through the workspace backend, drops them into a temp file, and hands that
// to the OS share sheet, where the user can open it with any capable app.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:aetherlink_flutter/core/platform/platform_providers.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// Cap on how many bytes we'll pull into memory for a share export.
const int kMaxShareBytes = 64 << 20;

Future<void> shareWorkspaceFile(
  BuildContext context,
  WidgetRef ref, {
  required WorkspaceEntry entry,
  Uint8List? bytes,
}) async {
  if (bytes == null && entry.size > kMaxShareBytes) {
    AppToast.error(context, '文件过大(超过 64MB),暂不支持导出分享');
    return;
  }
  try {
    if (bytes == null) {
      final backend = ref.read(workspacePreviewBackendProvider);
      if (backend == null) throw StateError('没有打开的工作区');
      bytes = Uint8List.fromList(await backend.readFileBytes(entry.path));
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/workspace_share/${entry.name}');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    await ref.read(shareApiProvider).shareFiles([file.path]);
  } catch (e) {
    if (context.mounted) AppToast.error(context, '分享失败:$e');
  }
}
