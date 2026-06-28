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

/// The friendly operating-system name (without version).
String _operatingSystemName() {
  if (Platform.isIOS) return 'iOS';
  if (Platform.isAndroid) return 'Android';
  if (Platform.isWindows) return 'Windows';
  if (Platform.isMacOS) return 'macOS';
  if (Platform.isLinux) return 'Linux';
  if (Platform.isFuchsia) return 'Fuchsia';
  return '未知操作系统';
}

/// The operating-system label. The web reads `navigator.userAgent`; on Flutter
/// we resolve it natively from [Platform], appending the version reported by
/// [Platform.operatingSystemVersion] when available (e.g. `iOS Version 16.0`).
/// The version string already embeds the OS name on some platforms (Windows /
/// Android), so it is returned as-is in that case to avoid `Windows Windows …`.
String getOperatingSystemString() {
  final name = _operatingSystemName();
  final version = Platform.operatingSystemVersion.trim();
  if (version.isEmpty) return name;
  if (version.toLowerCase().contains(name.toLowerCase())) return version;
  return '$name $version';
}

/// The current language tag derived from the device locale
/// ([Platform.localeName], e.g. `zh_CN.UTF-8`), normalised to a BCP-47-ish form
/// like `zh-CN`. Falls back to `未知语言` when unavailable.
String getLocaleString() {
  var name = Platform.localeName.trim();
  final dot = name.indexOf('.');
  if (dot != -1) name = name.substring(0, dot);
  name = name.replaceAll('_', '-');
  return name.isEmpty ? '未知语言' : name;
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
  if (config.enableLocaleVariable) {
    processed += '\n\n当前语言：${getLocaleString()}';
  }
  return processed;
}

/// ISO-style `yyyy-MM-dd` for [now].
String _isoDate(DateTime now) =>
    '${now.year.toString().padLeft(4, '0')}-${_pad2(now.month)}-${_pad2(now.day)}';

/// `HH:mm` for [now].
String _isoTime(DateTime now) => '${_pad2(now.hour)}:${_pad2(now.minute)}';

/// Replaces inline placeholder variables anywhere inside [text] (template-style,
/// unlike the append-only [injectSystemPromptVariables]). Mirrors the web /
/// kelivo `{xxx}` placeholders so a prompt like `你是{assistant_name}` resolves
/// at send time. Unknown placeholders are left untouched; an empty [text] is
/// returned unchanged.
///
/// Supported: `{cur_date}`, `{cur_time}`, `{cur_datetime}`, `{model_name}`,
/// `{model_id}`, `{assistant_name}`, `{provider_name}`.
String replaceSystemPromptPlaceholders(
  String text, {
  required String modelName,
  required String modelId,
  required String assistantName,
  required String providerName,
}) {
  if (text.isEmpty || !text.contains('{')) return text;
  final now = DateTime.now();
  final date = _isoDate(now);
  final time = _isoTime(now);
  final vars = <String, String>{
    '{cur_date}': date,
    '{cur_time}': time,
    '{cur_datetime}': '$date $time',
    '{model_name}': modelName,
    '{model_id}': modelId,
    '{assistant_name}': assistantName,
    '{provider_name}': providerName,
  };
  var out = text;
  vars.forEach((key, value) => out = out.replaceAll(key, value));
  return out;
}
