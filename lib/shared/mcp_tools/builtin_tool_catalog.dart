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
            'description': '指定引擎（逗号分隔），如 google,bing,duckduckgo。留空使用类别默认引擎',
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
          'pageno': {'type': 'number', 'description': '页码', 'default': 1},
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
          'url': {'type': 'string', 'format': 'uri', 'description': '目标 URL'},
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
  '@aether/fetch': [
    McpToolDefinition(
      name: 'fetch',
      description:
          '获取 URL 内容并转换为 Markdown 格式（便于 LLM 阅读）。'
          '支持分块读取：通过 start_index 指定起始位置，实现大页面分段获取。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'url': {
            'type': 'string',
            'format': 'uri',
            'description': '要获取的 URL 地址',
          },
          'max_length': {
            'type': 'integer',
            'description': '返回内容的最大字符数（默认 5000）',
            'default': 5000,
          },
          'start_index': {
            'type': 'integer',
            'description': '从第几个字符开始提取（默认 0），用于分块读取大页面',
            'default': 0,
          },
          'raw': {
            'type': 'boolean',
            'description': '是否返回原始内容，不做 Markdown 转换（默认 false）',
            'default': false,
          },
          'headers': {
            'type': 'object',
            'description': '可选的自定义 HTTP 请求头',
            'additionalProperties': {'type': 'string'},
          },
        },
        'required': ['url'],
      },
    ),
  ],
  '@aether/metaso-search': [
    McpToolDefinition(
      name: 'metaso_search',
      description:
          '秘塔AI搜索（metaso.cn 官方API）。'
          '搜索范围通过 scope 指定：webpage(网页)/document(文库)/scholar(学术)/image(图片)/video(视频)/podcast(播客)',
      inputSchema: {
        'type': 'object',
        'properties': {
          'q': {'type': 'string', 'description': '搜索关键词'},
          'scope': {
            'type': 'string',
            'enum': ['webpage', 'document', 'scholar', 'image', 'video', 'podcast'],
            'description': '搜索范围（默认 webpage）',
            'default': 'webpage',
          },
          'size': {
            'type': 'integer',
            'description': '返回结果数量（1-50，默认 10）',
            'default': 10,
          },
          'page': {
            'type': 'integer',
            'description': '页码（默认 1）',
            'default': 1,
          },
          'includeSummary': {
            'type': 'boolean',
            'description': '是否返回 AI 摘要（默认 false）',
            'default': false,
          },
          'includeRawContent': {
            'type': 'boolean',
            'description': '是否抓取所有来源网页原文（响应较慢，默认 false）',
            'default': false,
          },
          'conciseSnippet': {
            'type': 'boolean',
            'description': '是否返回精简的原文匹配信息（默认 false）',
            'default': false,
          },
        },
        'required': ['q'],
      },
    ),
    McpToolDefinition(
      name: 'metaso_reader',
      description: '根据 URL 抓取网页全文，以 Markdown 格式返回',
      inputSchema: {
        'type': 'object',
        'properties': {
          'url': {
            'type': 'string',
            'format': 'uri',
            'description': '目标网页 URL',
          },
          'format': {
            'type': 'string',
            'enum': ['markdown', 'text'],
            'description': '返回格式（默认 markdown）',
            'default': 'markdown',
          },
        },
        'required': ['url'],
      },
    ),
    McpToolDefinition(
      name: 'metaso_chat',
      description: '秘塔AI问答。根据查询问题，基于实时搜索返回带引用的解答',
      inputSchema: {
        'type': 'object',
        'properties': {
          'q': {'type': 'string', 'description': '查询问题'},
          'scope': {
            'type': 'string',
            'enum': ['webpage', 'document', 'scholar', 'video', 'podcast'],
            'description': '知识范围（默认 webpage）',
            'default': 'webpage',
          },
          'model': {
            'type': 'string',
            'enum': ['fast', 'fast_thinking', 'ds-r1'],
            'description': '模型：fast(极速)/fast_thinking(深度思考)/ds-r1(DeepSeek-R1)',
            'default': 'fast',
          },
          'conciseSnippet': {
            'type': 'boolean',
            'description': '是否返回精简的原文匹配信息（默认 false）',
            'default': false,
          },
        },
        'required': ['q'],
      },
    ),
  ],
  '@aether/grok-search': [
    McpToolDefinition(
      name: 'web_search',
      description:
          '使用 xAI Grok 进行实时联网搜索。利用 Grok API 的原生 search_parameters '
          '在 Web 和 X (Twitter) 上搜索最新信息并返回带引用的回答。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'description': '搜索查询内容'},
          'mode': {
            'type': 'string',
            'enum': ['on', 'auto'],
            'description': '搜索模式：on(始终搜索)/auto(模型自动判断)，默认 on',
            'default': 'on',
          },
          'max_search_results': {
            'type': 'integer',
            'description': '最大搜索结果数（默认不限制）',
          },
          'from_date': {
            'type': 'string',
            'description': '搜索起始日期（ISO-8601 YYYY-MM-DD 格式，如 2025-01-01）',
          },
          'to_date': {
            'type': 'string',
            'description': '搜索截止日期（ISO-8601 YYYY-MM-DD 格式）',
          },
          'sources': {
            'type': 'array',
            'items': {'type': 'string', 'enum': ['web', 'x', 'news']},
            'description': '搜索数据源列表，默认 web+x',
          },
        },
        'required': ['query'],
      },
    ),
  ],
  '@aether/settings': [
    // ── Provider-level tools ──
    McpToolDefinition(
      name: 'list_providers',
      description: '列出所有模型供应商及其启用状态、模型数量、是否配置 API Key',
      inputSchema: {'type': 'object', 'properties': {}},
    ),
    McpToolDefinition(
      name: 'get_provider',
      description: '获取指定供应商的详细信息，包括配置、所有模型列表',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': '供应商 ID'},
        },
        'required': ['id'],
      },
    ),
    McpToolDefinition(
      name: 'toggle_provider',
      description: '启用或禁用指定供应商',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': '供应商 ID'},
          'enabled': {'type': 'boolean', 'description': '是否启用'},
        },
        'required': ['id', 'enabled'],
      },
    ),
    McpToolDefinition(
      name: 'update_provider_config',
      description: '更新供应商配置（API 密钥、基础 URL、名称）',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': '供应商 ID'},
          'apiKey': {'type': 'string', 'description': '新的 API 密钥（可选）'},
          'baseUrl': {'type': 'string', 'description': '新的基础 URL（可选）'},
          'name': {'type': 'string', 'description': '新的供应商名称（可选）'},
        },
        'required': ['id'],
      },
    ),
    McpToolDefinition(
      name: 'create_provider',
      description: '创建一个新的模型供应商。这是一个需要用户确认的操作，请先向用户确认后再调用',
      inputSchema: {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': '供应商名称'},
          'type': {
            'type': 'string',
            'description':
                '供应商类型：openai, anthropic, gemini, deepseek, azure-openai 等',
            'default': 'openai',
          },
          'apiKey': {'type': 'string', 'description': 'API 密钥（可选）'},
          'baseUrl': {'type': 'string', 'description': '基础 URL（可选）'},
        },
        'required': ['name'],
      },
    ),
    McpToolDefinition(
      name: 'delete_provider',
      description: '删除指定的模型供应商及其所有模型。这是一个危险操作，请先向用户确认后再调用',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': '要删除的供应商 ID'},
        },
        'required': ['id'],
      },
    ),
    // ── Model-level tools ──
    McpToolDefinition(
      name: 'list_models',
      description: '列出指定供应商下的所有模型',
      inputSchema: {
        'type': 'object',
        'properties': {
          'providerId': {'type': 'string', 'description': '供应商 ID'},
        },
        'required': ['providerId'],
      },
    ),
    McpToolDefinition(
      name: 'get_current_model',
      description: '获取当前正在使用的默认聊天模型及其所属供应商',
      inputSchema: {'type': 'object', 'properties': {}},
    ),
    McpToolDefinition(
      name: 'set_default_model',
      description: '设置全局默认聊天模型',
      inputSchema: {
        'type': 'object',
        'properties': {
          'providerId': {'type': 'string', 'description': '供应商 ID'},
          'modelId': {'type': 'string', 'description': '模型 ID'},
        },
        'required': ['providerId', 'modelId'],
      },
    ),
    McpToolDefinition(
      name: 'toggle_model',
      description: '启用或禁用供应商中的指定模型',
      inputSchema: {
        'type': 'object',
        'properties': {
          'providerId': {'type': 'string', 'description': '供应商 ID'},
          'modelId': {'type': 'string', 'description': '模型 ID'},
          'enabled': {'type': 'boolean', 'description': '是否启用'},
        },
        'required': ['providerId', 'modelId', 'enabled'],
      },
    ),
    McpToolDefinition(
      name: 'add_model',
      description: '向供应商添加一个新模型。这是一个需要用户确认的操作，请先向用户确认后再调用',
      inputSchema: {
        'type': 'object',
        'properties': {
          'providerId': {'type': 'string', 'description': '供应商 ID'},
          'modelId': {
            'type': 'string',
            'description': '模型 ID（如 gpt-4o, claude-sonnet-4-20250514）',
          },
          'modelName': {
            'type': 'string',
            'description': '模型显示名称（可选，默认使用 modelId）',
          },
        },
        'required': ['providerId', 'modelId'],
      },
    ),
    McpToolDefinition(
      name: 'delete_model',
      description: '从供应商中删除指定模型。这是一个危险操作，请先向用户确认后再调用',
      inputSchema: {
        'type': 'object',
        'properties': {
          'providerId': {'type': 'string', 'description': '供应商 ID'},
          'modelId': {'type': 'string', 'description': '要删除的模型 ID'},
        },
        'required': ['providerId', 'modelId'],
      },
    ),
  ],
  '@aether/file-editor': [
    McpToolDefinition(
      name: 'list_workspaces',
      description:
          '获取用户已打开的所有工作区列表。返回带编号的工作区，可用编号、ID 或名称调用其他工具。操作文件前应先调用此工具了解可用工作区。',
      inputSchema: {'type': 'object', 'properties': {}},
    ),
    McpToolDefinition(
      name: 'get_workspace_files',
      description: '获取指定工作区中的文件和目录列表。支持浅层（只看当前目录）或递归（获取所有子目录内容）两种模式。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'workspace': {
            'type': 'string',
            'description': '工作区编号（如 "1"）或工作区 ID 或工作区名称',
          },
          'sub_path': {
            'type': 'string',
            'description': '子目录相对路径（可选，默认根目录）。例如 "src/components"',
          },
          'recursive': {
            'type': 'boolean',
            'description': '是否递归获取所有子目录。false=只看当前目录（默认），true=递归',
          },
          'max_depth': {
            'type': 'number',
            'description': '递归时的最大深度（可选，默认 3）。仅当 recursive=true 时有效',
          },
        },
        'required': ['workspace'],
      },
    ),
    McpToolDefinition(
      name: 'list_files',
      description: '列出指定目录的内容。path 为 get_workspace_files / list_workspaces 返回的目录路径（不透明句柄）。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': '目录的完整路径（不透明句柄）'},
          'recursive': {
            'type': 'boolean',
            'description': '是否递归列出子目录内容，默认 false',
          },
        },
        'required': ['path'],
      },
    ),
    McpToolDefinition(
      name: 'read_file',
      description: '读取文件内容。支持单文件(path)或批量(files 数组)读取，可指定行范围。大文件建议指定行范围。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': '单个文件的完整路径（与 files 二选一）'},
          'files': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'path': {'type': 'string', 'description': '文件路径'},
                'start_line': {'type': 'number', 'description': '起始行号 (1-based)'},
                'end_line': {'type': 'number', 'description': '结束行号 (1-based, 包含)'},
              },
            },
            'description': '批量读取的文件列表（与 path 二选一）',
          },
          'start_line': {
            'type': 'number',
            'description': '起始行号 (1-based)，可选。不指定则从第一行开始',
          },
          'end_line': {
            'type': 'number',
            'description': '结束行号 (1-based, 包含)，可选。需与 start_line 同时提供才按范围读取',
          },
        },
      },
    ),
    McpToolDefinition(
      name: 'get_file_info',
      description: '获取文件信息，包括大小、修改时间、类型、行数等。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': '文件的完整路径'},
        },
        'required': ['path'],
      },
    ),
    McpToolDefinition(
      name: 'search_files',
      description: '在目录中搜索文件。支持按文件名或内容搜索。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'directory': {'type': 'string', 'description': '搜索的目录路径'},
          'query': {'type': 'string', 'description': '搜索关键词'},
          'search_type': {
            'type': 'string',
            'enum': ['name', 'content', 'both'],
            'description': '搜索类型：name(文件名), content(文件内容), both(两者)',
          },
          'file_types': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': '文件类型过滤，如 ["ts", "js", "md"]',
          },
        },
        'required': ['directory', 'query'],
      },
    ),
    McpToolDefinition(
      name: 'write_to_file',
      description:
          '覆盖写入已有文件的全部内容（不能用于新建文件，新建请用 create_file）。会触发用户确认。'
          '建议传 line_count 以校验内容是否被截断；大文件的增量修改请优先用 apply_diff。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': '目标文件的完整路径（不透明句柄）'},
          'content': {'type': 'string', 'description': '要写入的完整文件内容'},
          'line_count': {
            'type': 'number',
            'description': '内容的预期行数（可选），用于检测内容是否被意外截断',
          },
        },
        'required': ['path', 'content'],
      },
    ),
    McpToolDefinition(
      name: 'create_file',
      description: '在指定父目录下新建文件。会触发用户确认。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'parent_path': {
            'type': 'string',
            'description': '父目录的完整路径（不透明句柄，来自 list_files / get_workspace_files）',
          },
          'name': {'type': 'string', 'description': '新文件名（含扩展名）'},
          'content': {'type': 'string', 'description': '初始内容（可选，默认空）'},
          'overwrite': {
            'type': 'boolean',
            'description': '同名文件已存在时是否覆盖，默认 false',
          },
        },
        'required': ['parent_path', 'name'],
      },
    ),
    McpToolDefinition(
      name: 'rename_file',
      description: '重命名文件或目录（仅改名，不移动）。会触发用户确认。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': '要重命名的文件/目录完整路径'},
          'new_name': {'type': 'string', 'description': '新名称（不含路径）'},
        },
        'required': ['path', 'new_name'],
      },
    ),
    McpToolDefinition(
      name: 'move_file',
      description: '将文件或目录移动到目标父目录下（保持原名）。会触发用户确认。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'source_path': {'type': 'string', 'description': '要移动的文件/目录完整路径'},
          'destination_path': {
            'type': 'string',
            'description': '目标父目录的完整路径（不透明句柄）',
          },
        },
        'required': ['source_path', 'destination_path'],
      },
    ),
    McpToolDefinition(
      name: 'copy_file',
      description: '将文件或目录复制到目标父目录下。会触发用户确认。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'source_path': {'type': 'string', 'description': '要复制的文件/目录完整路径'},
          'destination_path': {
            'type': 'string',
            'description': '目标父目录的完整路径（不透明句柄）',
          },
          'new_name': {'type': 'string', 'description': '复制后的新名称（可选，默认沿用原名）'},
          'overwrite': {
            'type': 'boolean',
            'description': '目标已存在同名时是否覆盖，默认 false',
          },
        },
        'required': ['source_path', 'destination_path'],
      },
    ),
    McpToolDefinition(
      name: 'delete_file',
      description: '删除文件或目录。会触发用户确认。删除目录时 recursive 默认为 true。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': '要删除的文件/目录完整路径'},
          'recursive': {
            'type': 'boolean',
            'description': '删除目录时是否递归删除其内容，默认 true',
          },
        },
        'required': ['path'],
      },
    ),
    McpToolDefinition(
      name: 'insert_content',
      description: '在文件指定行之前插入内容（不覆盖原有内容）。会触发用户确认。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': '目标文件的完整路径'},
          'line': {
            'type': 'number',
            'description': '插入位置的行号 (1-based)；在该行之前插入',
          },
          'content': {'type': 'string', 'description': '要插入的内容'},
        },
        'required': ['path', 'line', 'content'],
      },
    ),
    McpToolDefinition(
      name: 'apply_diff',
      description:
          '对文件应用 SEARCH/REPLACE（或 unified）diff，做增量精确修改。会触发用户确认。'
          '传入由 read_file 行范围读取得到的 start_line/end_line 与 expected_range_hash 可启用乐观锁，'
          '在应用前校验该范围未被并发改动。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': '目标文件的完整路径'},
          'diff': {
            'type': 'string',
            'description': 'diff 内容。默认 SEARCH/REPLACE 格式（<<<<<<< SEARCH … ======= … >>>>>>> REPLACE）',
          },
          'strategy': {
            'type': 'string',
            'enum': ['auto', 'search-replace', 'unified'],
            'description': 'diff 策略，默认 auto（按 search-replace 解析）',
          },
          'start_line': {
            'type': 'number',
            'description': '乐观锁：read_file 时读取范围的起始行 (1-based)',
          },
          'end_line': {
            'type': 'number',
            'description': '乐观锁：read_file 时读取范围的结束行 (1-based)',
          },
          'expected_range_hash': {
            'type': 'string',
            'description': '乐观锁：read_file 范围返回的 rangeHash，用于检测并发修改',
          },
          'create_backup': {
            'type': 'boolean',
            'description': '是否在修改前创建备份，默认 false',
          },
        },
        'required': ['path', 'diff'],
      },
    ),
    McpToolDefinition(
      name: 'replace_in_file',
      description: '在文件中查找并替换文本，支持字面量或正则。会触发用户确认。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': '目标文件的完整路径'},
          'search': {'type': 'string', 'description': '要查找的文本或正则表达式'},
          'replace': {'type': 'string', 'description': '替换后的文本'},
          'is_regex': {
            'type': 'boolean',
            'description': 'search 是否按正则解释，默认 false',
          },
          'replace_all': {
            'type': 'boolean',
            'description': '是否替换所有匹配，默认 true',
          },
          'case_sensitive': {
            'type': 'boolean',
            'description': '是否区分大小写，默认 true',
          },
        },
        'required': ['path', 'search', 'replace'],
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
  '@aether/fetch',
  '@aether/metaso-search',
  '@aether/grok-search',
};

/// Servers that run in-process but need Riverpod [Ref] (settings assistant,
/// file editor — both reach app state/providers).
const Set<String> kRefDependentBuiltins = {
  '@aether/settings',
  '@aether/file-editor',
};

/// The tools a built-in MCP server exposes, or an empty list for servers
/// without a static catalog (e.g. external servers, discovered at connect time).
List<McpToolDefinition> builtinToolsFor(String serverName) =>
    kBuiltinMcpTools[serverName] ?? const [];
