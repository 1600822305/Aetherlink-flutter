import 'dart:convert';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';

/// Parsed outcome of a `@aether/file-editor` tool call, read from the block's
/// JSON result envelope (`{success, data}` / `{success:false, error}`).
class FileEditorResult {
  const FileEditorResult({this.added, this.removed, this.error});

  final int? added;
  final int? removed;
  final String? error;

  int get addedOrZero => added ?? 0;
  int get removedOrZero => removed ?? 0;
}

/// Extracts `+added/-removed` stats (from `diffStats`) and/or an error message
/// from [block]'s result content. Shared by the edit card and the changeset
/// aggregate so the parsing logic lives in one place.
FileEditorResult parseFileEditorResult(ToolBlock block) {
  final content = block.content;
  if (content is String && content.isNotEmpty) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map) {
        if (decoded['success'] == false) {
          return FileEditorResult(error: decoded['error']?.toString());
        }
        final data = decoded['data'];
        if (data is Map) {
          final stats = data['diffStats'];
          if (stats is Map) {
            return FileEditorResult(
              added: (stats['added'] as num?)?.toInt(),
              removed: (stats['removed'] as num?)?.toInt(),
            );
          }
        }
      }
    } catch (_) {
      // Non-JSON content — fall through to the block-level error below.
    }
  }
  final blockErr = block.error;
  if (blockErr != null && blockErr['message'] is String) {
    return FileEditorResult(error: blockErr['message'] as String);
  }
  return const FileEditorResult();
}
