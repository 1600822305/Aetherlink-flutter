import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';

/// The static tool lists exposed by the built-in (in-memory) MCP servers — the
/// port of each `*Server.ts`'s `ListToolsRequest` handler under
/// `src/shared/services/mcp/servers/`. Keyed by the server's `name`
/// (e.g. `@aether/calculator`), matching `builtin_mcp_servers.dart`.
///
/// This is metadata only (what each server offers). Execution lives in
/// `builtin_tools.dart` — and only the pure-computation servers
/// (`@aether/calculator`, `@aether/time`) can run locally; `@aether/calendar`
/// and `@aether/alarm` need native device plugins, so their tools are listed
/// here but not executed until that integration lands.
const Map<String, List<McpToolDefinition>> kBuiltinMcpTools = {
  '@aether/time': [
    McpToolDefinition(
      name: 'get_current_time',
      description: '获取当前时间和日期，支持多种格式输出',
      inputSchema: {
        'type': 'object',
        'properties': {
          'format': {
            'type': 'string',
            'description':
                '时间格式：locale(本地化), iso(ISO 8601), timestamp(Unix 时间戳)',
            'enum': ['locale', 'iso', 'timestamp'],
            'default': 'locale',
          },
          'timezone': {
            'type': 'string',
            'description': '时区，例如：Asia/Shanghai, America/New_York（可选）',
          },
        },
      },
    ),
  ],
  '@aether/calculator': [
    McpToolDefinition(
      name: 'calculate',
      description: '执行数学计算，支持基本运算和科学计算函数',
      inputSchema: {
        'type': 'object',
        'properties': {
          'expression': {
            'type': 'string',
            'description':
                '数学表达式，例如: "2 + 3 * 4", "sin(30)", "sqrt(16)", "pow(2, 10)"',
          },
        },
        'required': ['expression'],
      },
    ),
    McpToolDefinition(
      name: 'convert_base',
      description: '进制转换，支持二进制、八进制、十进制、十六进制之间的转换',
      inputSchema: {
        'type': 'object',
        'properties': {
          'value': {'type': 'string', 'description': '要转换的数值'},
          'fromBase': {
            'type': 'number',
            'description': '源进制 (2, 8, 10, 16)',
            'enum': [2, 8, 10, 16],
          },
          'toBase': {
            'type': 'number',
            'description': '目标进制 (2, 8, 10, 16)',
            'enum': [2, 8, 10, 16],
          },
        },
        'required': ['value', 'fromBase', 'toBase'],
      },
    ),
    McpToolDefinition(
      name: 'convert_unit',
      description: '单位转换，支持长度、重量、温度等常用单位转换',
      inputSchema: {
        'type': 'object',
        'properties': {
          'value': {'type': 'number', 'description': '要转换的数值'},
          'category': {
            'type': 'string',
            'description':
                '单位类别：length(长度), weight(重量), temperature(温度), area(面积), volume(体积)',
            'enum': ['length', 'weight', 'temperature', 'area', 'volume'],
          },
          'fromUnit': {
            'type': 'string',
            'description': '源单位，如: m, km, kg, g, celsius, fahrenheit 等',
          },
          'toUnit': {'type': 'string', 'description': '目标单位'},
        },
        'required': ['value', 'category', 'fromUnit', 'toUnit'],
      },
    ),
    McpToolDefinition(
      name: 'statistics',
      description: '统计计算，包括平均值、中位数、标准差、方差等',
      inputSchema: {
        'type': 'object',
        'properties': {
          'numbers': {
            'type': 'array',
            'items': {'type': 'number'},
            'description': '数字数组，例如: [1, 2, 3, 4, 5]',
          },
        },
        'required': ['numbers'],
      },
    ),
  ],
  '@aether/calendar': [
    McpToolDefinition(
      name: 'get_calendars',
      description: '获取设备上的所有日历列表',
      inputSchema: {'type': 'object', 'properties': {}},
    ),
    McpToolDefinition(
      name: 'get_calendar_events',
      description: '获取指定时间范围内的日历事件',
      inputSchema: {
        'type': 'object',
        'properties': {
          'startDate': {
            'type': 'string',
            'description': '开始日期，ISO 8601格式，例如：2025-11-08T00:00:00.000Z',
          },
          'endDate': {
            'type': 'string',
            'description': '结束日期，ISO 8601格式，例如：2025-11-15T23:59:59.999Z',
          },
          'calendarId': {
            'type': 'string',
            'description': '日历ID，如果不提供则查询所有日历（可选）',
          },
        },
        'required': ['startDate', 'endDate'],
      },
    ),
    McpToolDefinition(
      name: 'create_calendar_event',
      description: '创建新的日历事件',
      inputSchema: {
        'type': 'object',
        'properties': {
          'title': {'type': 'string', 'description': '事件标题'},
          'startDate': {'type': 'string', 'description': '开始时间，ISO 8601格式'},
          'endDate': {'type': 'string', 'description': '结束时间，ISO 8601格式'},
          'location': {'type': 'string', 'description': '事件地点（可选）'},
          'notes': {'type': 'string', 'description': '事件备注（可选）'},
          'calendarId': {
            'type': 'string',
            'description': '目标日历ID，如果不提供则使用默认日历（可选）',
          },
        },
        'required': ['title', 'startDate', 'endDate'],
      },
    ),
    McpToolDefinition(
      name: 'update_calendar_event',
      description: '更新已存在的日历事件',
      inputSchema: {
        'type': 'object',
        'properties': {
          'eventId': {'type': 'string', 'description': '要更新的事件ID'},
          'title': {'type': 'string', 'description': '新的事件标题（可选）'},
          'startDate': {
            'type': 'string',
            'description': '新的开始时间，ISO 8601格式（可选）',
          },
          'endDate': {'type': 'string', 'description': '新的结束时间，ISO 8601格式（可选）'},
          'location': {'type': 'string', 'description': '新的事件地点（可选）'},
          'notes': {'type': 'string', 'description': '新的事件备注（可选）'},
        },
        'required': ['eventId'],
      },
    ),
    McpToolDefinition(
      name: 'delete_calendar_event',
      description: '删除日历事件',
      inputSchema: {
        'type': 'object',
        'properties': {
          'eventId': {'type': 'string', 'description': '要删除的事件ID'},
          'startDate': {'type': 'string', 'description': '事件开始时间，ISO 8601格式'},
          'endDate': {'type': 'string', 'description': '事件结束时间，ISO 8601格式'},
        },
        'required': ['eventId', 'startDate', 'endDate'],
      },
    ),
  ],
  '@aether/alarm': [
    McpToolDefinition(
      name: 'set_alarm',
      description: '调用系统原生闹钟应用直接设置闹钟，自动完成无需用户手动操作',
      inputSchema: {
        'type': 'object',
        'properties': {
          'title': {'type': 'string', 'description': '闹钟标题'},
          'time': {
            'type': 'string',
            'description': '闹钟时间，ISO 8601格式，例如：2025-11-08T07:00:00.000Z',
          },
          'repeat': {
            'type': 'string',
            'description':
                '重复模式：none(不重复), daily(每天), weekday(工作日), weekend(周末)',
            'enum': ['none', 'daily', 'weekday', 'weekend'],
            'default': 'none',
          },
          'skipUi': {
            'type': 'boolean',
            'description': '是否跳过系统UI直接设置，默认true自动设置',
            'default': true,
          },
        },
        'required': ['title', 'time'],
      },
    ),
    McpToolDefinition(
      name: 'show_alarms',
      description: '打开系统闹钟应用，查看和管理所有闹钟',
      inputSchema: {'type': 'object', 'properties': {}},
    ),
    McpToolDefinition(
      name: 'set_timer',
      description: '设置倒计时',
      inputSchema: {
        'type': 'object',
        'properties': {
          'seconds': {'type': 'number', 'description': '倒计时秒数'},
          'message': {
            'type': 'string',
            'description': '倒计时描述',
            'default': '倒计时',
          },
          'skipUi': {
            'type': 'boolean',
            'description': '是否跳过系统UI直接设置',
            'default': false,
          },
        },
        'required': ['seconds'],
      },
    ),
  ],
  '@aether/searxng': [
    McpToolDefinition(
      name: 'searxng_search',
      description:
          '聚合多引擎互联网搜索。通过 categories 参数选择搜索类别：general(通用), news(新闻), '
          'science(学术), it(技术), videos, images, repos, packages, social media, '
          'translate, weather, map, music, books, movies, q&a, dictionaries, '
          'currency, files。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'description': '搜索关键词'},
          'engines': {
            'type': 'string',
            'description':
                '指定引擎（逗号分隔），如 google,bing,duckduckgo。留空使用类别默认引擎',
          },
          'language': {
            'type': 'string',
            'description': '语言代码，如 zh-CN, en, ja',
            'default': 'zh-CN',
          },
          'categories': {
            'type': 'string',
            'description': '搜索类别（逗号分隔）',
            'default': 'general',
          },
          'maxResults': {
            'type': 'number',
            'description': '最大结果数',
            'default': 10,
          },
          'timeRange': {
            'type': 'string',
            'enum': ['day', 'week', 'month', 'year', ''],
            'description': '时间范围过滤',
          },
          'pageno': {
            'type': 'number',
            'description': '页码',
            'default': 1,
          },
          'safesearch': {
            'type': 'number',
            'enum': [0, 1, 2],
            'description': '安全搜索：0=关闭, 1=中等, 2=严格',
            'default': 0,
          },
        },
        'required': ['query'],
      },
    ),
    McpToolDefinition(
      name: 'searxng_read_url',
      description: '抓取网页内容并提取正文，支持 HTML/JSON/纯文本',
      inputSchema: {
        'type': 'object',
        'properties': {
          'url': {
            'type': 'string',
            'format': 'uri',
            'description': '目标 URL',
          },
          'maxLength': {
            'type': 'number',
            'description': '最大返回字符数',
            'default': 5000,
          },
        },
        'required': ['url'],
      },
    ),
  ],
};

/// Whether [serverName] is a built-in server whose tools can be executed
/// locally (pure computation or simple HTTP — no native plugin needed).
const Set<String> kLocallyRunnableBuiltins = {
  '@aether/calculator',
  '@aether/time',
  '@aether/searxng',
};

/// The tools a built-in MCP server exposes, or an empty list for servers
/// without a static catalog (e.g. external servers, discovered at connect time).
List<McpToolDefinition> builtinToolsFor(String serverName) =>
    kBuiltinMcpTools[serverName] ?? const [];
