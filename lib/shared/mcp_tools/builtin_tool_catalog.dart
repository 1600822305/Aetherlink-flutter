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
      description: '读取文件内容。支持单文件(path)或批量(files 数组)读取。大文件建议指定行范围（1-based，含端点）：'
          'start_line/end_line 可单独使用——只给 start_line 表示读到文件末尾，只给 end_line 表示从第 1 行开始。'
          '范围读取会返回 rangeHash，可配合 apply_diff 的乐观锁。',
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
            'description': '起始行号 (1-based)，可选。省略则从第 1 行开始',
          },
          'end_line': {
            'type': 'number',
            'description': '结束行号 (1-based, 包含)，可选。省略则读到文件末尾。给出任一端点即按范围读取',
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
      description: '在目录中搜索文件。支持按文件名或内容搜索，可选正则。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'directory': {'type': 'string', 'description': '搜索的目录路径'},
          'query': {'type': 'string', 'description': '搜索关键词，或正则表达式（当 use_regex=true）'},
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
          'use_regex': {
            'type': 'boolean',
            'description': 'query 是否按正则解释（大小写不敏感），默认 false',
          },
        },
        'required': ['directory', 'query'],
      },
    ),
    McpToolDefinition(
      name: 'write_to_file',
      description:
          '覆盖写入已有文件的全部内容（不能用于新建文件，新建请用 create_file）。会触发用户确认。'
          '务必传入完整内容，不要用 "// rest unchanged" 之类的省略标记（会被拒绝）。'
          '建议传 line_count 以校验内容是否被截断；大文件的增量修改请优先用 apply_diff / insert_content。'
          '若整段内容被代码围栏(```)包裹会自动去除；整体 HTML 转义的内容会自动还原。',
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
      description: '将文件或目录移动到目标父目录下，可同时改名（传 new_name）。会触发用户确认。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'source_path': {'type': 'string', 'description': '要移动的文件/目录完整路径'},
          'destination_path': {
            'type': 'string',
            'description': '目标父目录的完整路径（不透明句柄）',
          },
          'new_name': {
            'type': 'string',
            'description': '移动后的新名称（可选，默认沿用原名）',
          },
          'overwrite': {
            'type': 'boolean',
            'description': '目标目录已存在同名时是否覆盖，默认 false',
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
      description: '删除文件或目录。会触发用户确认。删除非空目录需显式传 recursive=true（默认 false，防止误删整棵目录树）。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': '要删除的文件/目录完整路径'},
          'recursive': {
            'type': 'boolean',
            'description': '删除目录时是否递归删除其内容，默认 false。删除非空目录必须为 true',
          },
        },
        'required': ['path'],
      },
    ),
    McpToolDefinition(
      name: 'insert_content',
      description: '在文件指定行的前/后插入内容，或追加到文件末尾（不覆盖原有内容）。会触发用户确认。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': '目标文件的完整路径'},
          'line': {
            'type': 'number',
            'description': '插入位置的行号 (1-based)。at_end=true 时可省略',
          },
          'position': {
            'type': 'string',
            'enum': ['before', 'after'],
            'description': '相对 line 在其之前还是之后插入，默认 before',
          },
          'at_end': {
            'type': 'boolean',
            'description': '为 true 时追加到文件末尾，无需 line，默认 false',
          },
          'content': {'type': 'string', 'description': '要插入的内容'},
        },
        'required': ['path', 'content'],
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
    McpToolDefinition(
      name: 'run_command',
      description: '在工作区所在机器上执行一条 shell 命令并返回 stdout/stderr/退出码（非交互、非 PTY）。'
          '仅远程类后端（SSH / Termux）支持；本地 SAF 工作区不支持。属高危操作，会触发用户确认。'
          '适合跑构建/测试/git/查询等一次性命令；不要用于需要交互输入的程序。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'command': {'type': 'string', 'description': '要执行的 shell 命令'},
          'workspace': {
            'type': 'string',
            'description': '工作区编号（如 "1"）或 ID 或名称（可选，默认当前工作区）',
          },
          'cwd': {
            'type': 'string',
            'description': '工作目录绝对路径（可选，默认工作区根目录）',
          },
          'timeout_ms': {
            'type': 'number',
            'description': '超时毫秒数（可选，默认 60000；超时会终止命令）',
          },
        },
        'required': ['command'],
      },
    ),
  ],
  '@aether/knowledge': [
    McpToolDefinition(
      name: 'kb_list',
      description:
          '列出所有知识库；传入 base_id 时改为列出该库下的条目（文档）。只读操作，无需确认。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'base_id': {
            'type': 'string',
            'description': '知识库 ID（可选）。省略时列出所有知识库；提供时列出该库的条目。',
          },
        },
      },
    ),
    McpToolDefinition(
      name: 'kb_search',
      description:
          '在知识库中检索与 query 最相关的内容片段（按库的检索模式走语义/关键词/混合，自动关键词兜底）。'
          '省略 base_id 时跨所有知识库检索并按相似度融合。返回片段含 documentId，可交给 kb_read 取全文。只读。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'description': '检索关键词或问题。'},
          'base_id': {
            'type': 'string',
            'description': '限定检索的知识库 ID（可选）。省略时检索所有知识库。',
          },
          'top_k': {
            'type': 'number',
            'description': '返回的最大片段数（可选，默认 5）。',
          },
        },
        'required': ['query'],
      },
    ),
    McpToolDefinition(
      name: 'kb_read',
      description: '按 base_id + document_id（来自 kb_search 结果的 documentId）读取某个条目的完整正文。只读。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'base_id': {'type': 'string', 'description': '知识库 ID。'},
          'document_id': {
            'type': 'string',
            'description': '条目（文档）ID，即 kb_search 结果里的 documentId。',
          },
        },
        'required': ['base_id', 'document_id'],
      },
    ),
    McpToolDefinition(
      name: 'kb_manage',
      description:
          '管理知识库（写操作，需用户确认）。action=create 建库（可选 embedding_model_key/search_mode）；'
          'action=add_note 向库中加入一条文本笔记；action=add_url 抓取网页转 Markdown 后加入；'
          'action=add_workspace 遍历一个工作区目录，把其中的文本文件逐个加入；'
          'action=delete 删除整个知识库；action=refresh 从已存正文重建整库索引（切块+向量）；'
          'action=retry_embeddings 只补嵌嵌入失败/中断留下的待补切块（比 refresh 轻）。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'description': '操作类型。',
            'enum': [
              'create',
              'add_note',
              'add_url',
              'add_workspace',
              'delete',
              'refresh',
              'retry_embeddings',
            ],
          },
          'name': {'type': 'string', 'description': 'create 时的知识库名称。'},
          'embedding_model_key': {
            'type': 'string',
            'description': 'create 时可选的嵌入模型键（providerId:modelId）。提供后可启用语义检索。',
          },
          'search_mode': {
            'type': 'string',
            'description': 'create 时的检索模式（需配合 embedding_model_key）。',
            'enum': ['keyword', 'vector', 'hybrid'],
          },
          'base_id': {
            'type': 'string',
            'description':
                'add_note / add_url / add_workspace / delete / refresh / '
                'retry_embeddings 的目标知识库 ID。',
          },
          'title': {
            'type': 'string',
            'description': 'add_note 的笔记标题（可选）；add_url 的条目标题（可选，留空用网页标题）。',
          },
          'text': {'type': 'string', 'description': 'add_note 的笔记正文。'},
          'url': {'type': 'string', 'description': 'add_url 要抓取的网页地址。'},
          'workspace_id': {
            'type': 'string',
            'description': 'add_workspace 要摄取的工作区 ID（「最近打开」列表里的工作区）。',
          },
        },
        'required': ['action'],
      },
    ),
  ],
  // DEX/APK 编辑（迁移自 web `DexEditorServer.ts`）。会话式工作流：
  // dex_open_apk → dex_open → 搜索/查看/修改 → dex_save；外加无状态的
  // APK/资源/清单工具。执行见 `tools/dex_editor_tool.dart`（原生 Android 桥）。
  // 会话管理：dex_open 对同一 apkPath 幂等（复用会话）；后续工具的 sessionId
  // 可直接填 apkPath；会话丢失（进程回收/引擎重建）时按 apkPath 落盘元数据惰性
  // 重建，只读操作全程无感，仅当上次有未保存(dex_save)改动时才明确报错提示重做。
  '@aether/dex-editor': [
    McpToolDefinition(
      name: 'dex_open_apk',
      description: '打开 APK 文件，查看其中包含的所有 DEX 文件列表。这是第一步操作。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'apkPath': {'type': 'string', 'description': 'APK 文件的完整路径'},
        },
        'required': ['apkPath'],
      },
    ),
    McpToolDefinition(
      name: 'dex_open',
      description: '打开指定的 DEX 文件进行编辑，可同时打开多个 DEX，返回会话 ID。'
          '幂等：同一 apkPath 重复调用会复用已有会话（返回同一 sessionId，reused=true），'
          '不会产生重复会话。后续工具的 sessionId 也可直接填该 apkPath，无需记忆 sessionId。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'apkPath': {'type': 'string', 'description': 'APK 文件路径'},
          'dexFiles': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'DEX 文件名列表，如 ["classes.dex", "classes2.dex"]',
          },
        },
        'required': ['apkPath', 'dexFiles'],
      },
    ),
    McpToolDefinition(
      name: 'dex_list_classes',
      description: '列出 DEX 中的所有类，支持包名过滤和分页。'
          '返回的 className 统一为点分格式（com.example.Foo），可直接传给 dex_get_class 等工具。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'sessionId': {
            'type': 'string',
            'description': '会话 ID（dex_open 返回）。也可直接填 APK 路径，'
                '系统会自动复用或按 apkPath 重建该会话，避免 "Session not found"。',
          },
          'packageFilter': {
            'type': 'string',
            'description': '包名过滤（如 "com.example"）',
          },
          'offset': {'type': 'integer', 'description': '偏移量', 'default': 0},
          'limit': {'type': 'integer', 'description': '返回数量', 'default': 100},
          'cursor': {
            'type': 'string',
            'description': '分页游标：把上一页返回的 nextCursor 原样传入即可翻页（优先于 offset/limit）',
          },
        },
        'required': ['sessionId'],
      },
    ),
    McpToolDefinition(
      name: 'dex_search',
      description:
          '统一搜索入口（一个工具搜遍 5 个面，用 target 区分，无需记忆多个工具）：\n'
          '- target=dex（默认）：已打开会话内的 DEX 搜索，用 searchType 选类名(class)/包名(package)/'
          '方法名(method)/字段名(field)/字符串(string)/整数(int)/代码(code)/父类(superclass)/'
          '接口(interface)/注解(annotation)；\n'
          '- target=strings：DEX 字符串池（=旧 dex_list_strings，用 filter 过滤）；\n'
          '- target=files：APK 内文本文件搜索（=旧 apk_search_text，用 query 作为 pattern）；\n'
          '- target=arsc：resources.arsc 搜索（=旧 apk_search_arsc，arscTarget=strings/resources）；\n'
          '- target=manifest：AndroidManifest 属性/值搜索（=旧 apk_search_manifest_cpp，用 attrName/value）。\n'
          'dex/strings 走会话（sessionId，也可填 apkPath）；files/arsc/manifest 走 apkPath。'
          'dex 结果中的 className/superclass/interface/annotation 统一为点分格式（com.example.Foo）。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'target': {
            'type': 'string',
            'enum': ['dex', 'strings', 'files', 'arsc', 'manifest'],
            'description': '搜索面，默认 dex。dex/strings 需 sessionId；files/arsc/manifest 需 apkPath',
            'default': 'dex',
          },
          'sessionId': {
            'type': 'string',
            'description': '会话 ID（dex_open 返回，target=dex/strings 用）。也可直接填 APK 路径，'
                '系统会自动复用或按 apkPath 重建该会话，避免 "Session not found"。',
          },
          'apkPath': {
            'type': 'string',
            'description': 'APK 文件路径（target=files/arsc/manifest 用）',
          },
          'query': {
            'type': 'string',
            'description': '搜索内容。target=dex 时是搜索词（superclass/interface/annotation 搜类型名，'
                '可用完整或部分类名如 "Activity"、"Landroidx/"）；target=files/arsc 时用作 pattern',
          },
          'searchType': {
            'type': 'string',
            'enum': [
              'class',
              'package',
              'method',
              'field',
              'string',
              'int',
              'code',
              'superclass',
              'interface',
              'annotation',
            ],
            'description': '搜索类型（仅 target=dex 必填）',
          },
          'filter': {
            'type': 'string',
            'description': '过滤字符串（仅 target=strings，包含匹配）',
          },
          'arscTarget': {
            'type': 'string',
            'enum': ['strings', 'resources'],
            'description': 'arsc 子目标（仅 target=arsc）：strings=字符串池，resources=资源条目',
            'default': 'strings',
          },
          'type': {
            'type': 'string',
            'description': '资源类型过滤（仅 target=arsc 且 arscTarget=resources，如 string/drawable/layout）',
          },
          'fileExtensions': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': '文件扩展名过滤（仅 target=files，如 [".xml", ".json"]）',
          },
          'isRegex': {
            'type': 'boolean',
            'description': '是否使用正则表达式（仅 target=files）',
            'default': false,
          },
          'contextLines': {
            'type': 'integer',
            'description': '上下文行数（仅 target=files）',
            'default': 2,
          },
          'attrName': {
            'type': 'string',
            'description': '属性名（仅 target=manifest，可选）',
          },
          'value': {
            'type': 'string',
            'description': '属性值（仅 target=manifest，可选）',
          },
          'caseSensitive': {
            'type': 'boolean',
            'description': '是否区分大小写（target=dex/files）',
            'default': false,
          },
          'maxResults': {
            'type': 'integer',
            'description': '最大返回结果数',
            'default': 50,
          },
          'limit': {
            'type': 'integer',
            'description': '最大返回数量（target=strings/arsc/manifest）',
            'default': 50,
          },
        },
        'required': ['query'],
      },
    ),
    McpToolDefinition(
      name: 'dex_get_class',
      description:
          '获取指定类的 Smali 代码。支持限制返回的字符数（用于控制 token）。'
          '传入 maxChars/offset 时返回 JSON，含 totalChars(总字符数)、returnedLength、'
          'hasMore(是否还有后续)、nextOffset(下一页 offset)、nextCursor(分页游标)，'
          '据此翻页无需自己计算；把 nextCursor 原样回传到 cursor 即可取下一页。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'sessionId': {
            'type': 'string',
            'description': '会话 ID（dex_open 返回）。也可直接填 APK 路径，'
                '系统会自动复用或按 apkPath 重建该会话，避免 "Session not found"。',
          },
          'className': {
            'type': 'string',
            'description':
                '类名（如 "com.example.MainActivity" 或 "Lcom/example/MainActivity;"）',
          },
          'locator': {
            'type': 'string',
            'description': '统一定位符，可替代 className，如 "dex_class:com.example.Foo"',
          },
          'maxChars': {
            'type': 'integer',
            'description': '最大返回字符数（用于限制 token），0 表示不限制',
            'default': 0,
          },
          'offset': {
            'type': 'integer',
            'description': '字符偏移量（用于分页获取大文件）',
            'default': 0,
          },
          'cursor': {
            'type': 'string',
            'description': '分页游标：把上一页返回的 nextCursor 原样传入即可翻页（优先于 offset/maxChars）',
          },
        },
        'required': ['sessionId', 'className'],
      },
    ),
    McpToolDefinition(
      name: 'dex_get_method',
      description: '获取类中单个方法的 Smali 代码。适用于大类只看特定方法的场景',
      inputSchema: {
        'type': 'object',
        'properties': {
          'sessionId': {
            'type': 'string',
            'description': '会话 ID（dex_open 返回）。也可直接填 APK 路径，'
                '系统会自动复用或按 apkPath 重建该会话，避免 "Session not found"。',
          },
          'className': {
            'type': 'string',
            'description': '类名（点分/L描述符/斜杠任意格式均可，内部自动转换）',
          },
          'methodName': {
            'type': 'string',
            'description': '方法名（如 "onCreate" 或 "<init>"）',
          },
          'methodSignature': {
            'type': 'string',
            'description': '方法签名（可选，用于区分重载方法，如 "(Landroid/os/Bundle;)V"）',
          },
        },
        'required': ['sessionId', 'className', 'methodName'],
      },
    ),
    McpToolDefinition(
      name: 'dex_modify_class',
      description: '修改类的 Smali 代码（仅修改内存中的内容，需要调用 dex_save 保存到 APK）',
      inputSchema: {
        'type': 'object',
        'properties': {
          'sessionId': {
            'type': 'string',
            'description': '会话 ID（dex_open 返回）。也可直接填 APK 路径，'
                '系统会自动复用或按 apkPath 重建该会话，避免 "Session not found"。',
          },
          'className': {
            'type': 'string',
            'description': '类名（点分/L描述符/斜杠任意格式均可，内部自动转换）',
          },
          'smaliContent': {'type': 'string', 'description': '新的 Smali 代码'},
        },
        'required': ['sessionId', 'className', 'smaliContent'],
      },
    ),
    McpToolDefinition(
      name: 'dex_modify_method',
      description: '修改类中单个方法的 Smali 代码。只需提供方法代码，自动替换原方法',
      inputSchema: {
        'type': 'object',
        'properties': {
          'sessionId': {
            'type': 'string',
            'description': '会话 ID（dex_open 返回）。也可直接填 APK 路径，'
                '系统会自动复用或按 apkPath 重建该会话，避免 "Session not found"。',
          },
          'className': {
            'type': 'string',
            'description': '类名（点分/L描述符/斜杠任意格式均可，内部自动转换）',
          },
          'methodName': {'type': 'string', 'description': '方法名'},
          'methodSignature': {
            'type': 'string',
            'description': '方法签名（可选，用于区分重载方法）',
          },
          'newMethodCode': {
            'type': 'string',
            'description': '新的方法 Smali 代码（从 .method 到 .end method）',
          },
        },
        'required': ['sessionId', 'className', 'methodName', 'newMethodCode'],
      },
    ),
    McpToolDefinition(
      name: 'dex_add_class',
      description: '向 DEX 中添加一个新类。提供完整的 Smali 代码',
      inputSchema: {
        'type': 'object',
        'properties': {
          'sessionId': {
            'type': 'string',
            'description': '会话 ID（dex_open 返回）。也可直接填 APK 路径，'
                '系统会自动复用或按 apkPath 重建该会话，避免 "Session not found"。',
          },
          'className': {
            'type': 'string',
            'description': '新类名（如 "com.example.NewClass"）',
          },
          'smaliContent': {'type': 'string', 'description': '完整的 Smali 代码'},
        },
        'required': ['sessionId', 'className', 'smaliContent'],
      },
    ),
    McpToolDefinition(
      name: 'dex_delete_class',
      description: '从 DEX 中删除一个类',
      inputSchema: {
        'type': 'object',
        'properties': {
          'sessionId': {
            'type': 'string',
            'description': '会话 ID（dex_open 返回）。也可直接填 APK 路径，'
                '系统会自动复用或按 apkPath 重建该会话，避免 "Session not found"。',
          },
          'className': {'type': 'string', 'description': '要删除的类名'},
        },
        'required': ['sessionId', 'className'],
      },
    ),
    McpToolDefinition(
      name: 'dex_outline_class',
      description:
          '获取类的轮廓：一次返回父类(superclass)、接口(interfaces)、字段列表(name/type/'
          'accessFlags)和方法列表(name/signature/returnType/accessFlags)。'
          '适合在读取全量 Smali(dex_get_class) 前先了解类结构，省 token。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'sessionId': {
            'type': 'string',
            'description': '会话 ID（dex_open 返回）。也可直接填 APK 路径，'
                '系统会自动复用或按 apkPath 重建该会话，避免 "Session not found"。',
          },
          'className': {
            'type': 'string',
            'description': '类名（点分/L描述符/斜杠任意格式均可，内部自动转换）',
          },
        },
        'required': ['sessionId', 'className'],
      },
    ),
    McpToolDefinition(
      name: 'dex_rename_class',
      description: '重命名类（修改类名和所有引用）',
      inputSchema: {
        'type': 'object',
        'properties': {
          'sessionId': {
            'type': 'string',
            'description': '会话 ID（dex_open 返回）。也可直接填 APK 路径，'
                '系统会自动复用或按 apkPath 重建该会话，避免 "Session not found"。',
          },
          'oldClassName': {'type': 'string', 'description': '原类名'},
          'newClassName': {'type': 'string', 'description': '新类名'},
        },
        'required': ['sessionId', 'oldClassName', 'newClassName'],
      },
    ),
    McpToolDefinition(
      name: 'dex_list_strings',
      description: '列出 DEX 中的字符串池，支持过滤和限制数量。'
          '（等价于统一入口 dex_search target=strings，二选一即可）',
      inputSchema: {
        'type': 'object',
        'properties': {
          'sessionId': {
            'type': 'string',
            'description': '会话 ID（dex_open 返回）。也可直接填 APK 路径，'
                '系统会自动复用或按 apkPath 重建该会话，避免 "Session not found"。',
          },
          'filter': {'type': 'string', 'description': '过滤字符串（包含匹配）'},
          'limit': {'type': 'integer', 'description': '最大返回数量', 'default': 100},
        },
        'required': ['sessionId'],
      },
    ),
    McpToolDefinition(
      name: 'dex_find_method_xrefs',
      description:
          '查找方法的交叉引用（哪些地方调用了这个方法），基于类继承分析(CHA)、跨全部 DEX。'
          '返回每条引用含 sourceClass/sourceMethod/sourceMethodSignature、invokeType'
          '(invoke-virtual/super/direct/static/interface)、targetOwner、instruction、'
          'codeAddress、matchReason（命中原因，便于人工判读）、certainty（置信度：'
          'exact=字节码确切引用目标本身/静态绑定，改动必生效；possible=虚/接口分发才可能'
          '落到目标，需确认运行时是否走到）。顶层 summary 汇总 total/exact/possible 计数。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'sessionId': {
            'type': 'string',
            'description': '会话 ID（dex_open 返回）。也可直接填 APK 路径，'
                '系统会自动复用或按 apkPath 重建该会话，避免 "Session not found"。',
          },
          'className': {'type': 'string', 'description': '类名，如 com.example.Foo'},
          'methodName': {'type': 'string', 'description': '方法名'},
          'methodSignature': {
            'type': 'string',
            'description': '可选，方法签名(参数+返回)，如 "(Landroid/os/Bundle;)V"，用于区分重载；'
                'slot/dispatch 模式在方法有重载时必须提供',
          },
          'resolution': {
            'type': 'string',
            'enum': ['exact', 'slot', 'dispatch'],
            'description': '方法解析模式（默认 dispatch）：'
                'exact=只匹配完全相等的方法引用；'
                'slot=同一 vtable 槽位的整个 override 家族（父/子覆写）；'
                'dispatch=运行时可能分发到该实现的所有多态调用点（找 hook 点最有用，'
                '可命中通过父类/接口类型调用的点）',
          },
          'locator': {
            'type': 'string',
            'description': '统一定位符，可替代 className，如 "dex_class:com.example.Foo"',
          },
          'limit': {
            'type': 'integer',
            'description': '最多返回多少条引用（默认 50）；截断时 hasMore=true',
          },
        },
        'required': ['sessionId', 'methodName'],
      },
    ),
    McpToolDefinition(
      name: 'dex_find_field_xrefs',
      description:
          '查找字段的交叉引用（哪些地方访问了这个字段），基于 dexlib2、跨全部 DEX、'
          '理解类继承（以父/子类型书写的访问也能命中）。每条引用含 sourceClass/'
          'sourceMethod/sourceMethodSignature、accessType(iget/iput/sget/sput 及'
          ' -wide/-object 等变体)、access(read|write)、isStatic、fieldOwner、'
          'fieldType、instruction、codeAddress、matchReason。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'sessionId': {
            'type': 'string',
            'description': '会话 ID（dex_open 返回）。也可直接填 APK 路径，'
                '系统会自动复用或按 apkPath 重建该会话，避免 "Session not found"。',
          },
          'className': {'type': 'string', 'description': '类名，如 com.example.Foo'},
          'fieldName': {'type': 'string', 'description': '字段名'},
          'fieldType': {
            'type': 'string',
            'description': '可选，字段类型描述符（如 "I"、"Ljava/lang/String;"），'
                '用于区分同名字段；同名多字段时必须提供',
          },
          'access': {
            'type': 'string',
            'enum': ['read', 'write', 'all'],
            'description': '访问过滤（默认 all）：read=只读(iget/sget)；'
                'write=只写(iput/sput)；all=全部',
          },
          'locator': {
            'type': 'string',
            'description': '统一定位符，可替代 className，如 "dex_class:com.example.Foo"',
          },
          'limit': {
            'type': 'integer',
            'description': '最多返回多少条引用（默认 50）；截断时 hasMore=true',
          },
        },
        'required': ['sessionId', 'fieldName'],
      },
    ),
    McpToolDefinition(
      name: 'dex_find_class_xrefs',
      description:
          '查找类（类型）的交叉引用（哪些地方引用了这个类），基于 dexlib2、跨全部 DEX。'
          '覆盖各种引用形式（含数组包装 [Type）：指令级 new-instance/check-cast/'
          'instance-of/const-class/new-array/filled-new-array、字段访问的字段类型、'
          '方法调用的参数/返回类型；声明级 extends(父类)/implements(接口)、字段声明类型、'
          '方法声明的参数/返回类型。每条引用含 sourceClass、sourceMethod?/'
          'sourceMethodSignature?、refKind（引用种类）、detail（指令或位置描述）、'
          'codeAddress?（指令级才有）、arrayDepth（数组维度，0=非数组）、dexFile。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'sessionId': {
            'type': 'string',
            'description': '会话 ID（dex_open 返回）。也可直接填 APK 路径，'
                '系统会自动复用或按 apkPath 重建该会话，避免 "Session not found"。',
          },
          'className': {'type': 'string', 'description': '类名，如 com.example.Foo'},
          'locator': {
            'type': 'string',
            'description': '统一定位符，可替代 className，如 "dex_class:com.example.Foo"',
          },
          'limit': {
            'type': 'integer',
            'description': '最多返回多少条引用（默认 50）；截断时 hasMore=true',
          },
        },
        'required': ['sessionId'],
      },
    ),
    McpToolDefinition(
      name: 'dex_smali_to_java',
      description: '将类的 Smali 代码转换为 Java 伪代码（便于理解）',
      inputSchema: {
        'type': 'object',
        'properties': {
          'sessionId': {
            'type': 'string',
            'description': '会话 ID（dex_open 返回）。也可直接填 APK 路径，'
                '系统会自动复用或按 apkPath 重建该会话，避免 "Session not found"。',
          },
          'className': {
            'type': 'string',
            'description': '类名（点分/L描述符/斜杠任意格式均可，内部自动转换）',
          },
        },
        'required': ['sessionId', 'className'],
      },
    ),
    McpToolDefinition(
      name: 'dex_save',
      description: '编译修改后的 Smali 代码并保存 DEX 到 APK。用户需要自行签名 APK。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'sessionId': {
            'type': 'string',
            'description': '会话 ID（dex_open 返回）。也可直接填 APK 路径，'
                '系统会自动复用或按 apkPath 重建该会话，避免 "Session not found"。',
          },
        },
        'required': ['sessionId'],
      },
    ),
    McpToolDefinition(
      name: 'dex_save_all',
      description:
          '一次性编译并保存所有有改动的 DEX 编辑会话到各自 APK（逆向常同时改多个会话时用）。'
          '无需传 sessionId；逐会话保存，单个失败不影响其余，返回每个会话的 saved/skipped/failed 结果。'
          '保存后的 APK 仍需用户自行签名。',
      inputSchema: {'type': 'object', 'properties': <String, Object?>{}},
    ),
    McpToolDefinition(
      name: 'dex_close',
      description: '关闭 DEX 编辑会话，释放资源（可选）。'
          '现在会话查不到时会按 apkPath 自动重建，通常无需手动 close；'
          '只有想主动释放大 APK 占用的内存时才需要调用。sessionId 也可填 apkPath。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'sessionId': {
            'type': 'string',
            'description': '会话 ID（dex_open 返回）。也可直接填 APK 路径，'
                '系统会自动复用或按 apkPath 重建该会话，避免 "Session not found"。',
          },
        },
        'required': ['sessionId'],
      },
    ),
    McpToolDefinition(
      name: 'dex_list_sessions',
      description: '列出 DEX 编辑会话：既包含当前内存中活跃的会话（alive=true），'
          '也包含进程重启后可按 apkPath 惰性重建的历史会话（alive=false，restorable=true）。'
          '有未保存改动的历史会话 restorable=false（那些改动已随进程丢失，需重做）。',
      inputSchema: {'type': 'object', 'properties': {}},
    ),
    McpToolDefinition(
      name: 'apk_get_manifest',
      description:
          '获取 APK 的 AndroidManifest.xml。format=xml（默认）返回解码后的可读 XML（支持分页/限制字符数，'
          '传入 maxChars/offset 时返回 JSON，含 totalChars、returnedLength、hasMore、nextOffset、nextCursor）；'
          'format=structured 使用 C++ 高性能解析，返回结构化信息（包名、版本、权限、组件等）。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'apkPath': {'type': 'string', 'description': 'APK 文件路径'},
          'format': {
            'type': 'string',
            'enum': ['xml', 'structured'],
            'description': 'xml=可读 XML 文本；structured=结构化解析结果',
            'default': 'xml',
          },
          'maxChars': {
            'type': 'integer',
            'description': '最大返回字符数（用于限制 token），0 表示不限制',
            'default': 0,
          },
          'offset': {
            'type': 'integer',
            'description': '字符偏移量（用于分页获取大文件）',
            'default': 0,
          },
          'cursor': {
            'type': 'string',
            'description': '分页游标：把上一页返回的 nextCursor 原样传入即可翻页（优先于 offset/maxChars）',
          },
        },
        'required': ['apkPath'],
      },
    ),
    McpToolDefinition(
      name: 'apk_modify_manifest',
      description: '修改 AndroidManifest.xml 并保存到 APK。支持修改包名、版本、权限、组件等',
      inputSchema: {
        'type': 'object',
        'properties': {
          'apkPath': {'type': 'string', 'description': 'APK 文件路径'},
          'newManifest': {
            'type': 'string',
            'description': '新的 AndroidManifest.xml 内容',
          },
        },
        'required': ['apkPath', 'newManifest'],
      },
    ),
    McpToolDefinition(
      name: 'apk_patch_manifest',
      description: '快速修改 AndroidManifest.xml 的现有标量属性，无需提供完整 XML（直接改二进制 AXML）。'
          '仅支持对已存在属性的 set；新增/删除元素或权限等结构性改动请用 apk_modify_manifest（整体替换）。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'apkPath': {'type': 'string', 'description': 'APK 文件路径'},
          'patches': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'type': {
                  'type': 'string',
                  'enum': [
                    'package',
                    'versionCode',
                    'versionName',
                    'minSdk',
                    'targetSdk',
                    'debuggable',
                  ],
                  'description': '要修改的属性（均为 manifest 中已存在的标量属性）',
                },
                'action': {
                  'type': 'string',
                  'enum': ['set'],
                  'description': '操作类型（仅支持 set）',
                  'default': 'set',
                },
                'value': {'type': 'string', 'description': '新值'},
              },
              'required': ['type', 'value'],
            },
            'description': '修改列表',
          },
        },
        'required': ['apkPath', 'patches'],
      },
    ),
    McpToolDefinition(
      name: 'apk_replace_in_manifest',
      description: '在 AndroidManifest.xml 中精准替换字符串（直接修改二进制 AXML）',
      inputSchema: {
        'type': 'object',
        'properties': {
          'apkPath': {'type': 'string', 'description': 'APK 文件路径'},
          'replacements': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'oldValue': {'type': 'string', 'description': '要替换的原字符串'},
                'newValue': {'type': 'string', 'description': '新字符串'},
              },
              'required': ['oldValue', 'newValue'],
            },
            'description': '替换列表',
          },
        },
        'required': ['apkPath', 'replacements'],
      },
    ),
    McpToolDefinition(
      name: 'apk_list_resources',
      description: '列出 APK 中的资源文件（res 目录）',
      inputSchema: {
        'type': 'object',
        'properties': {
          'apkPath': {'type': 'string', 'description': 'APK 文件路径'},
          'filter': {
            'type': 'string',
            'description': '过滤路径（如 "layout", "values", "drawable"）',
          },
        },
        'required': ['apkPath'],
      },
    ),
    McpToolDefinition(
      name: 'apk_get_resource',
      description:
          '获取 APK 中的资源文件内容（XML 会解码为可读格式）。支持分页和限制返回字符数。'
          '传入 maxChars/offset 时返回 JSON，含 totalChars(总字符数)、returnedLength、'
          'hasMore(是否还有后续)、nextOffset(下一页 offset)、nextCursor(分页游标)，据此翻页无需自己计算。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'apkPath': {'type': 'string', 'description': 'APK 文件路径'},
          'resourcePath': {
            'type': 'string',
            'description': '资源路径（如 "res/layout/activity_main.xml"）',
          },
          'locator': {
            'type': 'string',
            'description': '统一定位符，可替代 resourcePath，如 "apk_file:res/layout/activity_main.xml"',
          },
          'maxChars': {
            'type': 'integer',
            'description': '最大返回字符数（用于限制 token），0 表示不限制',
            'default': 0,
          },
          'offset': {
            'type': 'integer',
            'description': '字符偏移量（用于分页获取大文件）',
            'default': 0,
          },
          'cursor': {
            'type': 'string',
            'description': '分页游标：把上一页返回的 nextCursor 原样传入即可翻页（优先于 offset/maxChars）',
          },
        },
        'required': ['apkPath', 'resourcePath'],
      },
    ),
    McpToolDefinition(
      name: 'apk_modify_resource',
      description: '修改 APK 中的资源 XML 文件（如 layout、values 等）',
      inputSchema: {
        'type': 'object',
        'properties': {
          'apkPath': {'type': 'string', 'description': 'APK 文件路径'},
          'resourcePath': {
            'type': 'string',
            'description': '资源路径（如 "res/layout/activity_main.xml"）',
          },
          'newContent': {'type': 'string', 'description': '新的 XML 内容'},
        },
        'required': ['apkPath', 'resourcePath', 'newContent'],
      },
    ),
    McpToolDefinition(
      name: 'apk_get_resource_value',
      description:
          '按资源 ID 读取 resources.arsc 里的值（对齐 MT 的 read_resource）。'
          '与 apk_get_resource（按文件路径读资源文件）不同，本工具直接读 arsc 中的值，'
          '并按 config 限定符（default/zh/xxhdpi/v21…）逐条返回。'
          '返回 JSON：{id,name,type,package,found,configs:[{config,valueType,valueTypeName,value}]}。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'apkPath': {'type': 'string', 'description': 'APK 文件路径'},
          'id': {
            'type': 'string',
            'description': '完整资源 ID，十六进制（如 "0x7f010000"）或十进制',
          },
          'locator': {
            'type': 'string',
            'description': '统一定位符，可替代 id，如 "res:0x7f010000"',
          },
        },
        'required': ['apkPath', 'id'],
      },
    ),
    McpToolDefinition(
      name: 'apk_set_resource_value',
      description:
          '按资源 ID 修改 resources.arsc 里的值并写回 APK（对齐 MT 的 edit_resource）。'
          '标量（int/hex/bool/color/reference/float）原地改写；string 复用或追加字符串池后重建。'
          '仅支持修改已存在条目的值，不支持新增/删除资源条目。'
          '资源存在多个 config 时必须用 config 指定目标（否则报错并列出可选 config）。'
          '修改后 APK 需重新签名。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'apkPath': {'type': 'string', 'description': 'APK 文件路径'},
          'id': {
            'type': 'string',
            'description': '完整资源 ID，十六进制（如 "0x7f010000"）或十进制',
          },
          'locator': {
            'type': 'string',
            'description': '统一定位符，可替代 id，如 "res:0x7f010000"',
          },
          'value': {'type': 'string', 'description': '新值文本（按 valueType 解析）'},
          'valueType': {
            'type': 'string',
            'description':
                '值类型：auto（保持原类型）| string | int | hex | bool | color | reference | float',
            'enum': [
              'auto',
              'string',
              'int',
              'hex',
              'bool',
              'color',
              'reference',
              'float',
            ],
            'default': 'auto',
          },
          'config': {
            'type': 'string',
            'description':
                '目标 config 限定符（如 "default"、"zh"、"xxhdpi"）。资源仅单一 config 时可留空。',
            'default': '',
          },
        },
        'required': ['apkPath', 'id', 'value'],
      },
    ),
    McpToolDefinition(
      name: 'apk_list_files',
      description: '列出 APK 中的所有文件（支持过滤和分页）',
      inputSchema: {
        'type': 'object',
        'properties': {
          'apkPath': {'type': 'string', 'description': 'APK 文件路径'},
          'filter': {
            'type': 'string',
            'description': '过滤路径（如 "lib/", "assets/", ".dex", ".so"）',
            'default': '',
          },
          'limit': {'type': 'integer', 'description': '最大返回数量', 'default': 100},
          'offset': {'type': 'integer', 'description': '偏移量（用于分页）', 'default': 0},
          'cursor': {
            'type': 'string',
            'description': '分页游标：把上一页返回的 nextCursor 原样传入即可翻页（优先于 offset/limit）',
          },
        },
        'required': ['apkPath'],
      },
    ),
    McpToolDefinition(
      name: 'apk_search_text',
      description: '在 APK 内的文件中搜索文本内容（不需要解压）。\n'
          '支持搜索 XML、JSON、TXT、SMALI 等文本文件。\n'
          '自动跳过二进制文件（.dex, .so, .png 等）。\n'
          '（等价于统一入口 dex_search target=files，二选一即可）',
      inputSchema: {
        'type': 'object',
        'properties': {
          'apkPath': {'type': 'string', 'description': 'APK 文件路径'},
          'pattern': {'type': 'string', 'description': '搜索模式（文本或正则表达式）'},
          'fileExtensions': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': '文件扩展名过滤(如 [".xml", ".json"])，不指定则搜索所有文本文件',
          },
          'caseSensitive': {
            'type': 'boolean',
            'description': '是否区分大小写',
            'default': false,
          },
          'isRegex': {
            'type': 'boolean',
            'description': '是否使用正则表达式',
            'default': false,
          },
          'maxResults': {'type': 'integer', 'description': '最大结果数', 'default': 50},
          'contextLines': {'type': 'integer', 'description': '上下文行数', 'default': 2},
        },
        'required': ['apkPath', 'pattern'],
      },
    ),
    McpToolDefinition(
      name: 'apk_read_file',
      description: '读取 APK 中的任意文件内容（文本或 Base64 编码）',
      inputSchema: {
        'type': 'object',
        'properties': {
          'apkPath': {'type': 'string', 'description': 'APK 文件路径'},
          'filePath': {
            'type': 'string',
            'description':
                '文件路径（如 "classes.dex", "lib/arm64-v8a/libnative.so", "assets/config.json"）',
          },
          'locator': {
            'type': 'string',
            'description': '统一定位符，可替代 filePath，如 "apk_file:assets/config.json"',
          },
          'asBase64': {
            'type': 'boolean',
            'description': '是否以 Base64 编码返回（用于二进制文件）',
            'default': false,
          },
          'maxBytes': {
            'type': 'integer',
            'description': '最大读取字节数（0 表示不限制）',
            'default': 0,
          },
          'offset': {'type': 'integer', 'description': '字节偏移量', 'default': 0},
        },
        'required': ['apkPath', 'filePath'],
      },
    ),
    McpToolDefinition(
      name: 'apk_delete_file',
      description: '从 APK 中删除指定的文件（如广告资源、无用 so 库等）',
      inputSchema: {
        'type': 'object',
        'properties': {
          'apkPath': {'type': 'string', 'description': 'APK 文件路径'},
          'filePath': {
            'type': 'string',
            'description': '要删除的文件路径（如 "lib/arm64-v8a/libad.so", "assets/config.json"）',
          },
          'locator': {
            'type': 'string',
            'description': '统一定位符，可替代 filePath，如 "apk_file:lib/arm64-v8a/libad.so"',
          },
        },
        'required': ['apkPath', 'filePath'],
      },
    ),
    McpToolDefinition(
      name: 'apk_add_file',
      description: '向 APK 中添加或替换文件（如注入 assets、so 库等）',
      inputSchema: {
        'type': 'object',
        'properties': {
          'apkPath': {'type': 'string', 'description': 'APK 文件路径'},
          'filePath': {
            'type': 'string',
            'description': '目标路径（如 "assets/config.json"）',
          },
          'locator': {
            'type': 'string',
            'description': '统一定位符，可替代 filePath，如 "apk_file:assets/config.json"',
          },
          'content': {
            'type': 'string',
            'description': '文件内容（文本文件直接传内容，二进制文件传 Base64 编码）',
          },
          'isBase64': {
            'type': 'boolean',
            'description': '内容是否为 Base64 编码',
            'default': false,
          },
        },
        'required': ['apkPath', 'filePath', 'content'],
      },
    ),
    McpToolDefinition(
      name: 'apk_search_arsc',
      description: '搜索 APK 资源文件 (resources.arsc)。'
          'target=strings 搜索字符串池；target=resources 搜索资源条目（可按 type 过滤）。'
          '（等价于统一入口 dex_search target=arsc + arscTarget，二选一即可）',
      inputSchema: {
        'type': 'object',
        'properties': {
          'apkPath': {'type': 'string', 'description': 'APK 文件路径'},
          'pattern': {'type': 'string', 'description': '搜索模式'},
          'target': {
            'type': 'string',
            'enum': ['strings', 'resources'],
            'description': '搜索目标：strings=字符串池，resources=资源条目',
            'default': 'strings',
          },
          'type': {
            'type': 'string',
            'description': '资源类型过滤（仅 target=resources 时有效，如 string, drawable, layout）',
          },
          'limit': {'type': 'integer', 'description': '最大返回数量', 'default': 50},
        },
        'required': ['apkPath', 'pattern'],
      },
    ),
    McpToolDefinition(
      name: 'apk_search_manifest_cpp',
      description: '使用 C++ 高性能搜索 AndroidManifest.xml 中的属性和值。'
          '（等价于统一入口 dex_search target=manifest，二选一即可）',
      inputSchema: {
        'type': 'object',
        'properties': {
          'apkPath': {'type': 'string', 'description': 'APK 文件路径'},
          'attrName': {'type': 'string', 'description': '属性名（可选）'},
          'value': {'type': 'string', 'description': '值（可选）'},
          'limit': {'type': 'integer', 'description': '最大返回数量', 'default': 50},
        },
        'required': ['apkPath'],
      },
    ),
    McpToolDefinition(
      name: 'apk_parse_arsc_cpp',
      description: '使用 C++ 高性能解析 resources.arsc，返回资源概要信息',
      inputSchema: {
        'type': 'object',
        'properties': {
          'apkPath': {'type': 'string', 'description': 'APK 文件路径'},
        },
        'required': ['apkPath'],
      },
    ),
    McpToolDefinition(
      name: 'attempt_completion',
      description: '结束任务并展示结果摘要。所有 DEX 操作完成后调用。如有 APK 修改，提醒用户重新签名。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'result': {
            'type': 'string',
            'description': '任务完成的结果摘要。向用户解释你做了什么，以及任何相关的后续建议。',
          },
          'command': {
            'type': 'string',
            'description': '（可选）建议用户执行的操作，例如重新签名 APK 的步骤',
          },
        },
        'required': ['result'],
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
  // 原生 Android 插件（dex_editor），无需 Riverpod [Ref]；在非 Android 平台
  // 调用会返回错误而非崩溃。
  '@aether/dex-editor',
};

/// Servers that run in-process but need Riverpod [Ref] (settings assistant,
/// file editor — both reach app state/providers).
const Set<String> kRefDependentBuiltins = {
  '@aether/settings',
  '@aether/file-editor',
  '@aether/knowledge',
};

/// The tools a built-in MCP server exposes, or an empty list for servers
/// without a static catalog (e.g. external servers, discovered at connect time).
List<McpToolDefinition> builtinToolsFor(String serverName) =>
    kBuiltinMcpTools[serverName] ?? const [];
