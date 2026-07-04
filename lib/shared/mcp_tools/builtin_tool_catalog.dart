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
      description: '列出指定目录的内容。path 为 get_workspace_files 返回的目录路径（不透明句柄）。',
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
          '范围读取会返回 rangeHash，可配合 apply_diff 的乐观锁。'
          '返回内容默认每行带「N | 」行号前缀（仅供定位，不是文件内容）；'
          '需要原始文本时传 line_numbers=false。',
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
          'line_numbers': {
            'type': 'boolean',
            'description': '是否在每行前加「N | 」行号前缀，默认 true',
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
      description: '在目录中搜索文件。支持按文件名或内容搜索，可选正则、glob 路径过滤、大小写开关。'
          '内容搜索（content/both）默认返回每个命中文件的 matches：命中行的行号与内容'
          '（每文件最多 5 条，可带上下文行），可直接定位而无需再读整个文件；'
          'output_mode 可切换为仅文件列表或按文件计数。',
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
          'glob': {
            'type': 'string',
            'description': 'glob 路径过滤，如 "*.dart" 或 "src/**/*.ts"'
                '（* 不跨目录、** 跨目录、? 单字符；含 / 时按相对路径匹配，否则按文件名）',
          },
          'use_regex': {
            'type': 'boolean',
            'description': 'query 是否按正则解释，默认 false',
          },
          'case_sensitive': {
            'type': 'boolean',
            'description': '内容匹配是否区分大小写，默认 false',
          },
          'context_lines': {
            'type': 'number',
            'description': '每条命中行附带前后 N 行上下文（0-10，默认 0）',
          },
          'output_mode': {
            'type': 'string',
            'enum': ['content', 'files_with_matches', 'count'],
            'description': '输出模式：content(命中行，默认), files_with_matches(仅文件列表), count(每文件命中行数)',
          },
          'max_results': {
            'type': 'number',
            'description': '最多返回多少个文件（1-1000，默认 200）',
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
      name: 'create_directory',
      description: '在指定父目录下新建目录。会触发用户确认。同名目录已存在时直接返回其路径（不报错）。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'parent_path': {
            'type': 'string',
            'description': '父目录的完整路径（不透明句柄，来自 list_files / get_workspace_files）',
          },
          'name': {'type': 'string', 'description': '新目录名'},
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
          '一个 diff 可包含多个 SEARCH/REPLACE 块，按顺序应用且原子生效：'
          '任一块定位失败则整个 diff 不写入——同一文件的多处修改优先合并到一次调用。'
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
      description: '在文件中查找并替换文本，支持字面量或正则。会触发用户确认。'
          '默认只替换一处：search 命中多处时报错不修改（防改错位置），需在 search 中加上下文使其唯一，'
          '或传 replace_all=true 全部替换；命中 0 处也报错。'
          '支持 edits 数组对同一文件做多处替换，整体原子生效：任一 edit 失败则文件不会被修改。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': '目标文件的完整路径'},
          'search': {'type': 'string', 'description': '要查找的文本或正则表达式（与 edits 二选一）'},
          'replace': {'type': 'string', 'description': '替换后的文本（与 edits 二选一）'},
          'edits': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'search': {'type': 'string', 'description': '要查找的文本或正则'},
                'replace': {'type': 'string', 'description': '替换后的文本'},
              },
              'required': ['search', 'replace'],
            },
            'description': '多处替换列表（与 search/replace 二选一），按顺序应用，全成或全不改',
          },
          'is_regex': {
            'type': 'boolean',
            'description': 'search 是否按正则解释，默认 false',
          },
          'replace_all': {
            'type': 'boolean',
            'description': '是否替换所有匹配，默认 false（命中多处会报错）',
          },
          'case_sensitive': {
            'type': 'boolean',
            'description': '是否区分大小写，默认 true',
          },
        },
        'required': ['path'],
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
          '返回的 className 统一为点分格式（com.example.Foo），可直接传给 dex_read_class 等工具。',
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
          '- target=strings：DEX 字符串池（用 filter 过滤）；\n'
          '- target=files：APK 内文本文件搜索（用 query 作为 pattern）；\n'
          '- target=arsc：resources.arsc 搜索（arscTarget=strings/resources）；\n'
          '- target=manifest：AndroidManifest 属性/值搜索（用 attrName/value）。\n'
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
      name: 'dex_read_class',
      description:
          '读取类的 Smali 代码（统一入口，均返回 Smali 文本）：\n'
          '- 不传 methodName：读整类 Smali。支持限制返回字符数（控制 token）；'
          '传入 maxChars/offset 时返回 JSON，含 totalChars(总字符数)、returnedLength、'
          'hasMore(是否还有后续)、nextOffset(下一页 offset)、nextCursor(分页游标)，'
          '据此翻页无需自己计算；把 nextCursor 原样回传到 cursor 即可取下一页。\n'
          '- 传 methodName：只读该类中的单个方法（大类只看特定方法时用）。\n'
          '需要类的字段/方法列表（结构化轮廓）请改用 dex_outline_class。',
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
                '类名（点分/L描述符/斜杠任意格式均可，内部自动转换），'
                '如 "com.example.MainActivity" 或 "Lcom/example/MainActivity;"',
          },
          'methodName': {
            'type': 'string',
            'description': '可选：仅读取该方法（如 "onCreate" 或 "<init>"）；'
                '不传则读整类',
          },
          'methodSignature': {
            'type': 'string',
            'description': '可选，配合 methodName 区分重载方法，如 "(Landroid/os/Bundle;)V"',
          },
          'locator': {
            'type': 'string',
            'description': '统一定位符，可替代 className，如 "dex_class:com.example.Foo"',
          },
          'maxChars': {
            'type': 'integer',
            'description': '最大返回字符数（用于限制 token），0 表示不限制。仅读整类时生效',
            'default': 0,
          },
          'offset': {
            'type': 'integer',
            'description': '字符偏移量（用于分页获取大文件）。仅读整类时生效',
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
          '适合在读取全量 Smali(dex_read_class) 前先了解类结构，省 token。',
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
      name: 'dex_find_xrefs',
      description:
          '查找交叉引用（统一入口，跨全部 DEX）。用 target 选择对象：\n'
          '- target=method：查方法调用点，基于类继承分析(CHA)。每条含 sourceClass/'
          'sourceMethod/sourceMethodSignature、invokeType(invoke-virtual/super/direct/'
          'static/interface)、targetOwner、instruction、codeAddress、matchReason、'
          'certainty（exact=静态绑定/确切引用，改动必生效；possible=虚/接口分发才可能落到）。'
          '顶层 summary 汇总 total/exact/possible。需要 methodName（可选 methodSignature/resolution）。\n'
          '- target=field：查字段访问点，理解类继承。每条含 accessType(iget/iput/sget/sput 及'
          ' -wide/-object 变体)、access(read|write)、isStatic、fieldOwner、fieldType、'
          'instruction、codeAddress、matchReason。需要 fieldName（可选 fieldType/access）。\n'
          '- target=class：查类型引用，覆盖指令级(new-instance/check-cast/instance-of/'
          'const-class/new-array 等)与声明级(extends/implements/字段与方法签名类型)。每条含'
          ' refKind、detail、codeAddress?、arrayDepth、dexFile。只需 className。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'target': {
            'type': 'string',
            'enum': ['method', 'field', 'class'],
            'description': '交叉引用对象（默认 method）：method=方法调用点；'
                'field=字段访问点；class=类型引用点',
          },
          'sessionId': {
            'type': 'string',
            'description': '会话 ID（dex_open 返回）。也可直接填 APK 路径，'
                '系统会自动复用或按 apkPath 重建该会话，避免 "Session not found"。',
          },
          'className': {'type': 'string', 'description': '类名，如 com.example.Foo'},
          'methodName': {'type': 'string', 'description': 'target=method 时必填：方法名'},
          'methodSignature': {
            'type': 'string',
            'description': 'target=method 可选：方法签名(参数+返回)，如 "(Landroid/os/Bundle;)V"，'
                '用于区分重载；slot/dispatch 模式在方法有重载时必须提供',
          },
          'resolution': {
            'type': 'string',
            'enum': ['exact', 'slot', 'dispatch'],
            'description': 'target=method 的方法解析模式（默认 dispatch）：'
                'exact=只匹配完全相等的方法引用；'
                'slot=同一 vtable 槽位的整个 override 家族（父/子覆写）；'
                'dispatch=运行时可能分发到该实现的所有多态调用点（找 hook 点最有用）',
          },
          'fieldName': {'type': 'string', 'description': 'target=field 时必填：字段名'},
          'fieldType': {
            'type': 'string',
            'description': 'target=field 可选：字段类型描述符（如 "I"、"Ljava/lang/String;"），'
                '用于区分同名字段；同名多字段时必须提供',
          },
          'access': {
            'type': 'string',
            'enum': ['read', 'write', 'all'],
            'description': 'target=field 的访问过滤（默认 all）：read=只读(iget/sget)；'
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
        'required': ['sessionId', 'target'],
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
      description:
          '编译修改后的 Smali 代码并保存 DEX 到 APK。用户需要自行签名 APK。\n'
          '- scope=current（默认）：仅保存指定会话（需 sessionId，也可填 apkPath）。\n'
          '- scope=all：一次性保存所有有改动的会话（同时改多个 APK 时用），无需 sessionId；'
          '逐会话保存，单个失败不影响其余，返回每个会话的 saved/skipped/failed 结果。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'scope': {
            'type': 'string',
            'enum': ['current', 'all'],
            'description': '保存范围（默认 current）：current=仅当前会话；all=全部有改动的会话',
          },
          'sessionId': {
            'type': 'string',
            'description': 'scope=current 时必填：会话 ID（dex_open 返回）。也可直接填 APK 路径，'
                '系统会自动复用或按 apkPath 重建该会话，避免 "Session not found"。',
          },
        },
      },
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
      name: 'apk_edit_manifest',
      description:
          '修改 AndroidManifest.xml 并保存到 APK（统一入口）。用 mode 选择编辑方式：\n'
          '- mode=replace_all（默认）：整体替换，读 newManifest（新的完整 XML）。'
          '支持改包名/版本/权限/组件等一切结构性改动。\n'
          '- mode=patch：快速改已存在的标量属性，无需完整 XML（直接改二进制 AXML），读 patches。'
          '仅支持对已存在属性的 set；新增/删除元素或权限等结构性改动请用 mode=replace_all。\n'
          '- mode=find_replace：在二进制 AXML 中精准替换字符串，读 replacements。\n'
          '修改后的 APK 需要重新签名。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'apkPath': {'type': 'string', 'description': 'APK 文件路径'},
          'mode': {
            'type': 'string',
            'enum': ['replace_all', 'patch', 'find_replace'],
            'description': '编辑方式（默认 replace_all）：replace_all=整体替换(newManifest)；'
                'patch=改标量属性(patches)；find_replace=字符串替换(replacements)',
          },
          'newManifest': {
            'type': 'string',
            'description': 'mode=replace_all 时必填：新的 AndroidManifest.xml 完整内容',
          },
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
            'description': 'mode=patch 时必填：标量属性修改列表',
          },
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
            'description': 'mode=find_replace 时必填：字符串替换列表',
          },
        },
        'required': ['apkPath', 'mode'],
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
      name: 'apk_file',
      description:
          '对 APK 内文件的读/增/删（统一入口）。用 op 选择动作，filePath 始终必填：\n'
          '- op=read（默认）：读取文件内容。默认返回原始内容（文本或 Base64）；'
          '大文件用 maxBytes 限制单次字节数，返回 hasMore/nextOffset/nextCursor，'
          '把 nextCursor 原样回传到 cursor 即可续读，无需自己算 offset。'
          '传 decodeXml=true 可把二进制 AXML 自动解码为可读 XML；'
          '传 sessionId 则优先读该编辑会话中未保存的改动（目前主要是 .dex），否则读磁盘 APK。\n'
          '- op=add：添加或替换文件（如注入 assets、so 库），必填 content；\n'
          '- op=delete：删除文件（如广告资源、无用 so 库）。\n'
          'add/delete 后 APK 需要重新签名。'
          '（读 res/ 下资源、需按资源语义定位时可改用 apk_get_resource。）',
      inputSchema: {
        'type': 'object',
        'properties': {
          'apkPath': {'type': 'string', 'description': 'APK 文件路径'},
          'op': {
            'type': 'string',
            'enum': ['read', 'add', 'delete'],
            'description': '操作类型（默认 read）：read=读取；add=添加/替换；delete=删除',
          },
          'filePath': {
            'type': 'string',
            'description':
                '文件路径（如 "classes.dex", "lib/arm64-v8a/libnative.so", "assets/config.json"）',
          },
          'locator': {
            'type': 'string',
            'description': '统一定位符，可替代 filePath，如 "apk_file:assets/config.json"',
          },
          'content': {
            'type': 'string',
            'description': 'op=add 时必填：文件内容（文本直接传内容，二进制传 Base64 编码）',
          },
          'isBase64': {
            'type': 'boolean',
            'description': 'op=add 时：content 是否为 Base64 编码',
            'default': false,
          },
          'asBase64': {
            'type': 'boolean',
            'description': 'op=read 时：是否以 Base64 编码返回（用于二进制文件）',
            'default': false,
          },
          'decodeXml': {
            'type': 'boolean',
            'description': 'op=read 时：内容为二进制 AXML 则解码为可读 XML（默认 false 返回原始字节）',
            'default': false,
          },
          'sessionId': {
            'type': 'string',
            'description': 'op=read 时可选：传入活跃编辑会话，优先读其中未保存的改动（目前主要是 .dex），不传则读磁盘 APK',
          },
          'maxBytes': {
            'type': 'integer',
            'description': 'op=read 时：单次最大读取字节数（0 表示不限制，上限 1MB）',
            'default': 0,
          },
          'offset': {
            'type': 'integer',
            'description': 'op=read 时：字节偏移量（一般用 cursor 翻页，无需手填）',
            'default': 0,
          },
          'cursor': {
            'type': 'string',
            'description': 'op=read 时：分页游标，回传上一次返回的 nextCursor 即可续读下一段',
          },
        },
        'required': ['apkPath', 'op', 'filePath'],
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
  '@aether/terminal': [
    McpToolDefinition(
      name: 'terminal_execute',
      description:
          '在终端里执行一条 shell 命令，返回 stdout / stderr / 退出码。默认目标是内置终端'
          '（应用内 Alpine Linux 沙箱）；传 workspace 参数可在 SSH / Termux 工作区的远端 shell 里执行。'
          '适合一次性命令（如 apk add、cat、python 脚本）。每次调用都是独立进程，不保留 shell 状态；'
          '需要保留状态（cd、环境变量、后台任务）时用 terminal_session_* 系列。执行前会请用户确认。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'command': {'type': 'string', 'description': '要执行的 shell 命令'},
          'workspace': {
            'type': 'string',
            'description': '目标工作区（序号 / ID / 名称，可选；不传时在内置终端沙箱里执行）',
          },
          'cwd': {
            'type': 'string',
            'description': '工作目录（可选；内置终端默认 /root，指定工作区时默认其根目录）',
          },
          'timeout_ms': {
            'type': 'number',
            'description': '超时毫秒数（可选，默认 120000）',
          },
        },
        'required': ['command'],
      },
    ),
    McpToolDefinition(
      name: 'terminal_session_create',
      description:
          '新建一个长驻终端会话（持久 shell）。默认在内置 Alpine 沙箱里；传 workspace 参数可在'
          ' SSH / Termux 工作区的远端开会话。会话保留 cd / 环境变量 / 后台进程等状态，'
          '空闲 10 分钟自动回收。返回 sessionId 供 terminal_session_exec 等使用。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': '会话名称（可选）'},
          'workspace': {
            'type': 'string',
            'description': '目标工作区（序号 / ID / 名称，可选；不传时在内置终端沙箱里开会话）',
          },
          'cwd': {
            'type': 'string',
            'description': '初始工作目录（可选；内置终端默认 /root，指定工作区时默认其根目录）',
          },
        },
      },
    ),
    McpToolDefinition(
      name: 'terminal_session_list',
      description: '列出当前所有长驻终端会话（sessionId、名称、所属工作区、是否正忙、最近使用时间）。',
      inputSchema: {'type': 'object', 'properties': {}},
    ),
    McpToolDefinition(
      name: 'terminal_session_exec',
      description:
          '在指定长驻会话里执行一条命令并等待结束（保留 shell 状态）。不传 session_id 时自动复用/新建'
          '默认会话（可配合 workspace 参数指定在哪个工作区）。'
          '超时不杀命令——命令继续在会话里跑，可用 terminal_session_output 回看。执行前会请用户确认。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'command': {'type': 'string', 'description': '要执行的 shell 命令'},
          'session_id': {
            'type': 'string',
            'description': '目标会话 ID（可选，默认复用空闲会话）',
          },
          'workspace': {
            'type': 'string',
            'description': '不传 session_id 时的目标工作区（序号 / ID / 名称，可选；默认内置终端）',
          },
          'timeout_ms': {
            'type': 'number',
            'description': '等待毫秒数（可选，默认 120000）',
          },
        },
        'required': ['command'],
      },
    ),
    McpToolDefinition(
      name: 'terminal_session_output',
      description: '回看指定会话最近的输出（如超时后查看长任务进度）。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'session_id': {'type': 'string', 'description': '目标会话 ID'},
          'tail_chars': {
            'type': 'number',
            'description': '返回末尾多少个字符（可选，默认 4000）',
          },
        },
        'required': ['session_id'],
      },
    ),
    McpToolDefinition(
      name: 'terminal_session_close',
      description: '关闭指定长驻会话并结束其中的进程。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'session_id': {'type': 'string', 'description': '目标会话 ID'},
        },
        'required': ['session_id'],
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
  '@aether/terminal',
};

/// The tools a built-in MCP server exposes, or an empty list for servers
/// without a static catalog (e.g. external servers, discovered at connect time).
List<McpToolDefinition> builtinToolsFor(String serverName) =>
    kBuiltinMcpTools[serverName] ?? const [];
