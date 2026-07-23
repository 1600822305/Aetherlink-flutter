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
  '@aether/browser': [
    McpToolDefinition(
      name: 'browser_open',
      description:
          '用内置浏览器打开 URL 并等待 JavaScript 渲染完成，返回标题、最终 URL '
          '和首屏正文预览。适用于 fetch 抓不到的 JS 渲染页面（SPA、动态加载）；'
          '静态页面优先用更轻量的 fetch。会话在多次调用间保留（cookies/登录态'
          '不丢失）。连续失败 2-3 次请停下换思路或询问用户，不要反复重试同一 URL。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'url': {
            'type': 'string',
            'format': 'uri',
            'description': '要打开的 URL（仅支持 http/https，内网地址会被拒绝）',
          },
          'timeout_seconds': {
            'type': 'integer',
            'description': '导航超时秒数（默认 30，范围 5-120）',
            'default': 30,
          },
          'session': {
            'type': 'string',
            'description': '可选会话标识（当前版本共享同一浏览器实例，保留参数）',
          },
        },
        'required': ['url'],
      },
    ),
    McpToolDefinition(
      name: 'browser_read',
      description:
          '提取内置浏览器当前页面的正文文本（Readability 提取，取不到回退全文）。'
          '需先用 browser_open 打开页面。支持分块读取：通过 start_index '
          '指定起始位置，实现大页面分段获取。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'selector': {
            'type': 'string',
            'description': '可选 CSS 选择器，只提取该元素的文本',
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
          'session': {
            'type': 'string',
            'description': '可选会话标识（当前版本共享同一浏览器实例，保留参数）',
          },
        },
      },
    ),
    McpToolDefinition(
      name: 'browser_snapshot',
      description:
          '截取内置浏览器当前页面的截图（JPEG），以图片消息注入上下文供多模态'
          '模型查看。需先用 browser_open 打开页面。截图消耗较多 token，'
          '优先用 browser_read 读文本，仅在需要视觉理解（布局/图表/验证页面'
          '状态）时使用。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'full_page': {
            'type': 'boolean',
            'description': '是否截取整页（默认 false 只截视口；整页高度有上限）',
            'default': false,
          },
          'max_width': {
            'type': 'integer',
            'description': '截图最大宽度像素（默认 1024，范围 320-2048）',
            'default': 1024,
          },
          'session': {
            'type': 'string',
            'description': '可选会话标识（当前版本共享同一浏览器实例，保留参数）',
          },
        },
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
      name: 'list_files',
      description: '列出目录内容。两种寻址方式二选一：传 workspace（可配 sub_path）从工作区入口列出；'
          '或传 path（已知目录的不透明句柄，来自之前的列表结果）。支持浅层或递归。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'workspace': {
            'type': 'string',
            'description': '工作区编号（如 "1"）或工作区 ID 或工作区名称（与 path 二选一）',
          },
          'sub_path': {
            'type': 'string',
            'description': '配合 workspace 使用的子目录相对路径（可选，默认根目录）。例如 "src/components"',
          },
          'path': {
            'type': 'string',
            'description': '目录路径（与 workspace 二选一）：相对路径按工作区根目录解析，也可传绝对路径/不透明句柄',
          },
          'recursive': {
            'type': 'boolean',
            'description': '是否递归列出所有子目录，默认 false',
          },
          'max_depth': {
            'type': 'number',
            'description': '递归时的最大深度（可选，默认 3）。仅当 recursive=true 时有效',
          },
          'pattern': {
            'type': 'string',
            'description': '文件名 glob 过滤（可选，支持 * 和 ?），如 "*.dart"。'
                '设置后只返回名称匹配的文件（目录不进结果，递归时仍会下探）',
          },
          'sort': {
            'type': 'string',
            'enum': ['name', 'mtime'],
            'description': '排序方式（可选，默认 name：目录在前按名称）。mtime 为最近修改在前，'
                '适合找「最近在改的文件」',
          },
        },
      },
    ),
    McpToolDefinition(
      name: 'read_file',
      description: '读取文件内容。支持单文件(path)或批量(files 数组)读取。大文件建议指定行范围（1-based，含端点）：'
          'start_line/end_line 可单独使用——只给 start_line 表示读到文件末尾，只给 end_line 表示从第 1 行开始。'
          '超长行会被截断、超大文件会拒绝整读并提示改用行范围分段读取；'
          '同一文件同一范围的重复读取，若文件未变化会返回 unchanged=true 存根（内容以早前结果为准）；'
          '批量读取有总量上限，超出后剩余文件会被标记 skipped，需分批调用。'
          '返回内容默认每行带「N | 」行号前缀（仅供定位，不是文件内容）；'
          '需要原始文本时传 line_numbers=false。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': '单个文件路径（与 files 二选一）；相对路径按工作区根目录解析'},
          'files': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'path': {'type': 'string', 'description': '文件路径（相对路径按工作区根目录解析）'},
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
          'path': {'type': 'string', 'description': '文件路径（相对路径按工作区根目录解析）'},
        },
        'required': ['path'],
      },
    ),
    McpToolDefinition(
      name: 'search_files',
      description: '在目录中搜索文件。支持按文件名或内容搜索，可选正则、glob 路径过滤、大小写开关。'
          '结果按修改时间降序（最近改过的在前）。'
          '内容搜索（content/both）默认返回每个命中文件的 matches：命中行的行号与内容'
          '（每文件默认最多 5 条，可用 max_matches_per_file 调大，命中被截断时带'
          ' matchesTruncated=true；可带上下文行），可直接定位而无需再读整个文件；'
          'output_mode 可切换为仅文件列表或按文件计数。'
          '结果超过 max_results 时返回 hasMore=true 与 nextOffset，用 offset 翻页。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'directory': {'type': 'string', 'description': '搜索的目录路径（相对路径按工作区根目录解析）'},
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
          'max_matches_per_file': {
            'type': 'number',
            'description': '每文件最多返回多少条命中行（1-100，默认 5）。'
                '命中密集时调大以免漏结果',
          },
          'offset': {
            'type': 'number',
            'description': '跳过前 N 个命中文件（翻页用，默认 0）。'
                '搭配上次返回的 nextOffset 使用',
          },
        },
        'required': ['directory', 'query'],
      },
    ),
    McpToolDefinition(
      name: 'get_diagnostics',
      description: '运行项目静态分析并回读诊断（错误/告警清单）。按项目根目录自动选择只读分析命令：'
          'pubspec.yaml→dart analyze、tsconfig.json→npx tsc --noEmit、'
          'go.mod→go vet ./...、Cargo.toml→cargo check。'
          '改完代码后调用以自检，避免把编译错误留给用户。'
          '仅支持可执行命令的工作区后端（本地容器 / SSH）。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'workspace': {
            'type': 'string',
            'description': '工作区编号（如 "1"）或工作区 ID 或工作区名称（可选，默认当前工作区）',
          },
          'sub_path': {
            'type': 'string',
            'description': '项目所在子目录相对路径（可选，默认工作区根目录）。monorepo 时指定具体项目目录',
          },
        },
      },
    ),
    McpToolDefinition(
      name: 'write',
      description:
          '写文件（create-or-overwrite）：传 path，文件存在则覆盖全部内容，'
          '不存在则自动创建（缺失的父目录也会自动创建）。会触发用户确认。'
          '覆盖已有文件前必须先用 read_file 读过它的全文（未读过或只读过行范围会被拒绝），'
          '覆盖成功后返回本次修改的 diff。'
          '务必传入完整内容，不要用 "// rest unchanged" 之类的省略标记（会被拒绝）。'
          '覆盖写入时建议传 line_count 以校验内容是否被截断；已有文件的增量修改请优先用 edit。'
          '若整段内容被代码围栏(```)包裹会自动去除；整体 HTML 转义的内容会自动还原。'
          '文件若在本会话读取后被外部修改会拒绝覆盖，需先 read_file 重读。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {
            'type': 'string',
            'description': '目标文件路径（存在则覆盖，不存在则自动创建，含缺失父目录；'
                '相对路径按工作区根目录解析）',
          },
          'parent_path': {
            'type': 'string',
            'description': '新建文件（旧用法，与 path 二选一）：父目录路径（相对路径按工作区根目录解析，'
                '也可传 list_files 返回的句柄）',
          },
          'name': {'type': 'string', 'description': '新建文件（旧用法）：文件名（含扩展名）'},
          'content': {'type': 'string', 'description': '要写入的完整文件内容'},
          'line_count': {
            'type': 'number',
            'description': '内容的预期行数（可选），用于检测内容是否被意外截断',
          },
          'overwrite': {
            'type': 'boolean',
            'description': '新建时同名文件已存在是否覆盖，默认 false',
          },
        },
        'required': ['content'],
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
            'description': '父目录路径（相对路径按工作区根目录解析，也可传 list_files 返回的句柄）',
          },
          'name': {'type': 'string', 'description': '新目录名'},
        },
        'required': ['parent_path', 'name'],
      },
    ),
    McpToolDefinition(
      name: 'move',
      description: '移动/重命名文件或目录：只传 new_name 为原地改名；传 destination_path 移动到目标父目录下，'
          '可同时改名。会触发用户确认。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': '要移动/重命名的文件或目录路径（相对路径按工作区根目录解析）'},
          'destination_path': {
            'type': 'string',
            'description': '目标父目录路径（相对路径按工作区根目录解析）。省略则仅原地改名（需传 new_name）',
          },
          'new_name': {
            'type': 'string',
            'description': '新名称（不含路径）。与 destination_path 至少传一个',
          },
          'overwrite': {
            'type': 'boolean',
            'description': '目标已存在同名时是否覆盖，默认 false',
          },
        },
        'required': ['path'],
      },
    ),
    McpToolDefinition(
      name: 'copy_file',
      description: '将文件或目录复制到目标父目录下。会触发用户确认。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'source_path': {'type': 'string', 'description': '要复制的文件/目录路径（相对路径按工作区根目录解析）'},
          'destination_path': {
            'type': 'string',
            'description': '目标父目录路径（相对路径按工作区根目录解析）',
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
          'path': {'type': 'string', 'description': '要删除的文件/目录路径（相对路径按工作区根目录解析）'},
          'recursive': {
            'type': 'boolean',
            'description': '删除目录时是否递归删除其内容，默认 false。删除非空目录必须为 true',
          },
        },
        'required': ['path'],
      },
    ),
    McpToolDefinition(
      name: 'edit',
      description: '在文件中精确查找并替换文本（增量修改首选），支持字面量或正则。会触发用户确认。'
          '编辑前必须先用 read_file 读过目标文件（行范围读也可），未读过会被拒绝。'
          'search 需与文件内容完全一致（含缩进/空白，不含 read_file 的行号前缀；'
          '仅弯引号/行尾空白差异会自动按文件实际文本恢复匹配），'
          'replace 必须与 search 不同。'
          '默认只替换一处：search 命中多处时报错不修改（防改错位置），需在 search 中加上下文使其唯一，'
          '或传 replace_all=true 全部替换；命中 0 处也报错。'
          '支持 edits 数组对同一文件做多处替换（每个元素可单独指定 replace_all），'
          '整体原子生效：任一 edit 失败则文件不会被修改。'
          '文件若在本会话读取后被外部修改会拒绝编辑，需先 read_file 重读。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': '目标文件路径（相对路径按工作区根目录解析）'},
          'search': {'type': 'string', 'description': '要查找的文本或正则表达式（与 edits 二选一）'},
          'replace': {'type': 'string', 'description': '替换后的文本（与 edits 二选一）'},
          'edits': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'search': {'type': 'string', 'description': '要查找的文本或正则'},
                'replace': {'type': 'string', 'description': '替换后的文本（需与 search 不同）'},
                'replace_all': {
                  'type': 'boolean',
                  'description': '本条 edit 是否替换所有匹配（省略时沿用顶层 replace_all）',
                },
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
            'description': '是否替换所有匹配，默认 false（命中多处会报错）；edits 元素可用自己的 replace_all 覆盖',
          },
          'case_sensitive': {
            'type': 'boolean',
            'description': '是否区分大小写，默认 true',
          },
        },
        'required': ['path'],
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
  '@aether/terminal': [
    McpToolDefinition(
      name: 'terminal_execute',
      description:
          '在长驻终端会话里执行一条 shell 命令，返回输出和退出码。默认复用同一个持久会话'
          '（像 IDE 终端：cd、环境变量、venv 等状态跨命令保留）。'
          '需要独立环境或并行多个任务时传 session 参数（会话名字）：存在就在该会话里执行，'
          '不存在自动新建，无需单独的创建步骤。'
          '默认目标是内置终端（应用内 Alpine Linux 沙箱）；传 workspace 参数可在'
          ' SSH / Termux 工作区的远端 shell 里执行。'
          '超时不杀命令——命令继续在会话里跑，可用 terminal_session action=output 回看。执行前会请用户确认。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'command': {'type': 'string', 'description': '要执行的 shell 命令'},
          'session': {
            'type': 'string',
            'description': '目标会话名字或 ID（可选；存在就复用、不存在自动新建；不传时复用默认会话）',
          },
          'workspace': {
            'type': 'string',
            'description': '目标工作区（序号 / ID / 名称，可选；默认内置终端沙箱）',
          },
          'cwd': {
            'type': 'string',
            'description': '工作目录（可选；不传时延续会话当前目录，传了则先 cd 过去再执行）',
          },
          'timeout_ms': {
            'type': 'number',
            'description': '超时毫秒数（可选，默认 120000；超时不杀命令，命令继续在会话里跑）',
          },
        },
        'required': ['command'],
      },
    ),
    McpToolDefinition(
      name: 'terminal_session',
      description:
          '管理长驻终端会话（新建会话不在这里：给 terminal_execute 传 session 名字即可自动创建），'
          '用 action 参数区分操作：'
          'list 列出所有会话（sessionId、名称、所属工作区、是否正忙）；'
          'output 回看会话最近输出（如超时后查看长任务进度）；'
          'write 往运行中进程写 stdin（交互式输入，如回答 [y/n]、REPL；执行前会请用户确认）。'
          '不提供关闭操作：会话空闲自动回收，用户也可在终端页手动关闭。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'enum': ['list', 'output', 'write'],
            'description': '操作类型',
          },
          'session_id': {
            'type': 'string',
            'description': '目标会话 ID（output / write 必传）',
          },
          'workspace': {
            'type': 'string',
            'description': '目标工作区（序号 / ID / 名称；list 可选，传了只列该工作区的会话）',
          },
          'tail_chars': {
            'type': 'number',
            'description': '返回末尾多少个字符（output 可选，默认 4000）',
          },
          'input': {'type': 'string', 'description': '要写入 stdin 的内容（write 必传）'},
          'press_enter': {
            'type': 'boolean',
            'description': '是否在末尾追加回车（write 可选，默认 true）',
          },
        },
        'required': ['action'],
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
  '@aether/browser',
  '@aether/metaso-search',
  '@aether/grok-search',
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
