import 'dart:io';

import 'package:aetherlink_flutter/shared/domain/system_prompt_variables.dart';

/// Dynamic system-prompt variable helpers — the port of the web
/// `src/shared/utils/systemPromptVariables.ts`. Each enabled variable is
/// appended to the system prompt in 纯追加 (append-only) mode before a request
/// is sent.

const List<String> _weekdays = <String>[
  '星期日',
  '星期一',
  '星期二',
  '星期三',
  '星期四',
  '星期五',
  '星期六',
];

String _pad2(int value) => value.toString().padLeft(2, '0');

/// The formatted current time, e.g. `2026年06月18日 04:06 星期四`.
String getCurrentTimeString() {
  final now = DateTime.now();
  final weekday = _weekdays[now.weekday % 7];
  return '${now.year}年${_pad2(now.month)}月${_pad2(now.day)}日 '
      '${_pad2(now.hour)}:${_pad2(now.minute)} $weekday';
}

/// The operating-system label. The web reads `navigator.userAgent`; on Flutter
/// we resolve it natively from [Platform].
String getOperatingSystemString() {
  if (Platform.isIOS) return 'iOS';
  if (Platform.isAndroid) return 'Android';
  if (Platform.isWindows) return 'Windows';
  if (Platform.isMacOS) return 'macOS';
  if (Platform.isLinux) return 'Linux';
  if (Platform.isFuchsia) return 'Fuchsia';
  return '未知操作系统';
}

/// The location string: [customLocation] when set, otherwise the device time
/// zone name (the web maps a handful of IANA zones; natively we surface the
/// zone abbreviation, falling back to `未知位置`).
String getLocationString([String? customLocation]) {
  final trimmed = customLocation?.trim() ?? '';
  if (trimmed.isNotEmpty) return trimmed;
  final zone = DateTime.now().timeZoneName.trim();
  return zone.isEmpty ? '未知位置' : zone;
}

/// Appends the enabled dynamic variables to [systemPrompt] (append-only),
/// mirroring `injectSystemPromptVariables`. Returns [systemPrompt] unchanged
/// when it is empty or no variable is enabled.
String injectSystemPromptVariables(
  String systemPrompt,
  SystemPromptVariables config,
) {
  if (systemPrompt.isEmpty) return systemPrompt;

  var processed = systemPrompt;
  if (config.enableTimeVariable) {
    processed += '\n\n当前时间：${getCurrentTimeString()}';
  }
  if (config.enableLocationVariable) {
    processed += '\n\n当前位置：${getLocationString(config.customLocation)}';
  }
  if (config.enableOSVariable) {
    processed += '\n\n操作系统：${getOperatingSystemString()}';
  }
  return processed;
}
