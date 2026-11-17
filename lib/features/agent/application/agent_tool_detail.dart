import 'dart:convert';

import 'package:path/path.dart' as p;

Map<String, dynamic> _object(String? text) {
  if (text == null) {
    return const {};
  }
  try {
    final value = jsonDecode(text);
    return value is Map<String, dynamic> ? value : const {};
  } on FormatException {
    return const {};
  }
}

String? _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

String? toolCommandText(String toolName, String argsText) {
  if (!const {'terminal_execute', 'terminal_session', 'run_command'}
      .contains(toolName)) {
    return null;
  }
  return _text(_object(argsText)['command']);
}

List<String> toolChangedFilePaths(
  String toolName,
  String argsText, {
  String? resultText,
}) {
  if (!const {
    'write',
    'edit',
    'move',
    'delete_file',
    'create_directory',
    'pptx_modify',
    'pptx_draft',
    'pptx_render',
    'pptx_edit',
    'pptx_illustrate',
  }.contains(toolName)) {
    return const [];
  }
  final args = _object(argsText);
  if (toolName == 'pptx_edit' && args['dry_run'] == true) {
    return const [];
  }
  final result = _object(resultText);
  final data = result['success'] == false
      ? const <String, dynamic>{}
      : result['data'] is Map<String, dynamic>
          ? result['data'] as Map<String, dynamic>
          : result;
  final paths = <String>{};
  void add(Object? value) {
    final path = _text(value);
    if (path != null) {
      paths.add(path);
    }
  }

  if (toolName == 'pptx_edit') {
    add(data['source'] ?? args['source']);
    add(data['path'] ?? args['export']);
  } else {
    final resolved = _text(data['path']);
    final path = _text(args['path']) ?? _text(args['file']);
    final target = toolName == 'pptx_modify' ? _text(args['output']) ?? path : path;
    add(resolved ?? target);
    if (toolName == 'pptx_render') {
      add(data['previewPath']);
      if (_text(data['previewPath']) == null &&
          args['preview'] == true &&
          path != null &&
          path.endsWith('.pptx')) {
        add('${path.substring(0, path.length - 5)}.preview.html');
      }
    }
    if (resolved == null &&
        path == null &&
        (toolName == 'write' || toolName == 'create_directory')) {
      final parent = _text(args['parent_path']);
      final name = _text(args['name']);
      if (parent != null && name != null && !parent.contains('://')) {
        add(p.posix.join(parent, name));
      }
    }
    if (toolName == 'move') {
      add(path);
      if (resolved == null && path != null && !path.contains('://')) {
        final destination = _text(args['destination_path']) ?? p.posix.dirname(path);
        final name = _text(args['new_name']) ?? p.posix.basename(path);
        add(p.posix.join(destination, name));
      }
    }
  }
  return paths.toList();
}

List<T> prioritizeToolDiffRepository<T>(
  List<T> files,
  int focusIndex, {
  required String Function(T) repoRootOf,
}) {
  if (focusIndex < 0 || focusIndex >= files.length) {
    return [...files];
  }
  final focused = files[focusIndex];
  final root = repoRootOf(focused);
  return [
    focused,
    for (var i = 0; i < files.length; i++)
      if (i != focusIndex && repoRootOf(files[i]) == root) files[i],
    for (final file in files)
      if (repoRootOf(file) != root) file,
  ];
}

int? findToolDiffFileIndex(
  String path,
  List<String> absolutePaths, {
  required String workspaceRoot,
}) {
  String normalize(String value) =>
      p.posix.normalize(value.replaceAll('\\', '/'));
  if (path.trim().isEmpty || path.contains('://')) {
    return null;
  }
  final normalized = normalize(path);
  if (normalized == '.' || normalized == '~' || normalized.startsWith('~/')) {
    return null;
  }
  final isAbsolute = p.posix.isAbsolute(normalized) ||
      RegExp(r'^[A-Za-z]:/').hasMatch(normalized);
  final target = isAbsolute
      ? normalized
      : normalize(p.posix.join(workspaceRoot, normalized));
  final index = absolutePaths.indexWhere((file) => normalize(file) == target);
  return index < 0 ? null : index;
}
