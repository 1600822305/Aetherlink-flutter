import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/tools/tool_helpers.dart';

/// `@aether/time` tool execution (`get_current_time`).
/// [now] is injectable for deterministic tests; defaults to wall clock.
McpToolResult runTimeTool(
  String toolName,
  Map<String, Object?> args, {
  DateTime? now,
}) {
  if (toolName == 'get_current_time') {
    return _getCurrentTime(args, now ?? DateTime.now());
  }
  return McpToolResult('获取时间失败: 未知的工具: $toolName');
}

McpToolResult _getCurrentTime(Map<String, Object?> args, DateTime now) {
  try {
    final format = (args['format'] as String?) ?? 'locale';
    final timezone = args['timezone'] as String?;
    final local = now.toLocal();
    String timeString;
    final additional = <String, Object?>{};
    switch (format) {
      case 'iso':
        timeString = now.toUtc().toIso8601String();
      case 'timestamp':
        final ms = now.millisecondsSinceEpoch;
        timeString = ms.toString();
        additional['milliseconds'] = ms;
        additional['seconds'] = ms ~/ 1000;
      case 'locale':
      default:
        timeString = _formatLocale(local);
        if (timezone != null && timezone.isNotEmpty) {
          additional['timezone'] = timezone;
          additional['note'] = '时区转换暂未支持（需时区数据库），返回设备本地时间';
        }
    }
    return McpToolResult(
      encodeJson({
        'currentTime': timeString,
        'format': format,
        'year': local.year,
        'month': local.month,
        'day': local.day,
        'weekday': _weekdayCn(local.weekday),
        'hour': local.hour,
        'minute': local.minute,
        'second': local.second,
        ...additional,
      }),
    );
  } catch (error) {
    return McpToolResult('获取时间失败: ${errMsg(error, '未知错误')}');
  }
}

String _formatLocale(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}/${t.month}/${t.day} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

const List<String> _weekdays = [
  '星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日',
];

String _weekdayCn(int weekday) => _weekdays[(weekday - 1) % 7];
