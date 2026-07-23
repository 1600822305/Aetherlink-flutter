import 'package:aetherlink_flutter/shared/domain/skill.dart';

/// The built-in skill catalog, ported from the web
/// `src/shared/config/builtinSkills/*` (the per-file `Skill` definitions
/// aggregated by `builtinSkills`). Adding a new built-in skill is a matter of
/// adding an entry here.
///
/// UI-only milestone: the SKILL.md `content` bodies (consumed only by the
/// editor) aren't ported yet, and `enabled` is a display default — the real
/// enabled state will come from the persisted store once the feature is wired.
const List<Skill> kBuiltinSkills = [
  // —— 编程开发 ——
  Skill(
    id: 'builtin-code-review',
    name: '代码审查',
    description: '审查代码变更，检查潜在bug、代码风格、性能问题和安全隐患',
    emoji: '💻',
    tags: ['编程', '审查'],
    source: SkillSource.builtin,
    version: '1.0.0',
    author: 'AetherLink',
    enabled: true,
  ),
  Skill(
    id: 'builtin-unit-testing',
    name: '单元测试',
    description: '为代码生成全面的单元测试，覆盖正常路径、边界条件和异常场景',
    emoji: '🧪',
    tags: ['编程', '测试', '质量'],
    source: SkillSource.builtin,
    version: '1.0.0',
    author: 'AetherLink',
    enabled: true,
  ),
  Skill(
    id: 'builtin-debugging',
    name: 'Bug 诊断',
    description: '系统化分析和定位代码Bug，提供根因分析和修复建议',
    emoji: '🐛',
    tags: ['编程', '调试', '排错'],
    source: SkillSource.builtin,
    version: '1.0.0',
    author: 'AetherLink',
    enabled: true,
  ),
  Skill(
    id: 'builtin-refactoring',
    name: '代码重构',
    description: '识别代码异味并提供重构方案，提升代码可读性、可维护性和性能',
    emoji: '♻️',
    tags: ['编程', '重构', '质量'],
    source: SkillSource.builtin,
    version: '1.0.0',
    author: 'AetherLink',
    enabled: true,
  ),
  Skill(
    id: 'builtin-git-assistant',
    name: 'Git 助手',
    description: '生成规范的 commit message 和 PR 描述，遵循 Conventional Commits 规范',
    emoji: '🔀',
    tags: ['Git', '编程', '规范'],
    source: SkillSource.builtin,
    version: '1.0.0',
    author: 'AetherLink',
    enabled: true,
  ),
  Skill(
    id: 'builtin-api-design',
    name: 'API 设计',
    description: '设计 RESTful API，遵循最佳实践，包括路由设计、状态码、错误处理和版本管理',
    emoji: '🔗',
    tags: ['API', '设计', '后端'],
    source: SkillSource.builtin,
    version: '1.0.0',
    author: 'AetherLink',
    enabled: true,
  ),
  Skill(
    id: 'builtin-sql-optimization',
    name: 'SQL 优化',
    description: '分析SQL查询性能，提供索引建议、执行计划分析和查询重写方案',
    emoji: '🗄️',
    tags: ['数据库', 'SQL', '性能'],
    source: SkillSource.builtin,
    version: '1.0.0',
    author: 'AetherLink',
    enabled: true,
  ),
  // —— 写作办公 ——
  Skill(
    id: 'builtin-doc-writing',
    name: '文档写作',
    description: '按照结构化模板撰写技术文档，包括 API 文档、设计文档和用户指南',
    emoji: '📝',
    tags: ['写作', '文档'],
    source: SkillSource.builtin,
    version: '1.0.0',
    author: 'AetherLink',
    enabled: true,
  ),
  Skill(
    id: 'builtin-creative-writing',
    name: '创意写作',
    description: '辅助创意文案撰写，包括营销文案、故事创作、社交媒体内容等',
    emoji: '✨',
    tags: ['写作', '创意', '文案'],
    source: SkillSource.builtin,
    version: '1.0.0',
    author: 'AetherLink',
    enabled: true,
  ),
  Skill(
    id: 'builtin-meeting-notes',
    name: '会议纪要',
    description: '将会议内容整理为结构化纪要，包括议题、决策、待办事项和负责人',
    emoji: '📋',
    tags: ['办公', '会议', '纪要'],
    source: SkillSource.builtin,
    version: '1.0.0',
    author: 'AetherLink',
    enabled: true,
  ),
  // —— 数据与信息 ——
  Skill(
    id: 'builtin-data-analysis',
    name: '数据分析',
    description: '分析数据集，生成统计摘要、趋势分析和可视化建议',
    emoji: '📊',
    tags: ['数据', '分析', '统计'],
    source: SkillSource.builtin,
    version: '1.0.0',
    author: 'AetherLink',
    enabled: true,
  ),
  Skill(
    id: 'builtin-web-summary',
    name: '网页摘要',
    description: '提取和总结网页内容的关键信息，生成结构化摘要',
    emoji: '🌐',
    tags: ['阅读', '摘要', '网页'],
    source: SkillSource.builtin,
    version: '1.0.0',
    author: 'AetherLink',
    enabled: true,
  ),
  Skill(
    id: 'builtin-news-analysis',
    name: '新闻分析',
    description: '搜索、汇总和深度分析指定日期或主题的新闻事件，提供多角度解读',
    emoji: '📰',
    tags: ['新闻', '分析', '时事', '搜索'],
    source: SkillSource.builtin,
    version: '1.0.0',
    author: 'AetherLink',
    enabled: true,
  ),
  // —— 语言工具 ——
  Skill(
    id: 'builtin-translation',
    name: '专业翻译',
    description: '在中英日韩等语言之间进行高质量翻译，保留原文语气和专业术语',
    emoji: '🌍',
    tags: ['翻译', '语言', '国际化'],
    source: SkillSource.builtin,
    version: '1.0.0',
    author: 'AetherLink',
    enabled: true,
  ),
  // —— 智能体 ——
  Skill(
    id: 'builtin-subagent-dispatch',
    name: '子代理派发',
    description: '智能体派发子代理（spawn_subagent）的完整用法：类型选择、'
        'prompt 写法、并行执行与后台模式',
    emoji: '🤖',
    tags: ['智能体', '子代理'],
    source: SkillSource.builtin,
    version: '1.0.0',
    author: 'AetherLink',
    enabled: true,
    content: '''
## 何时派子代理

会产生大量中间输出的专项活（大范围搜索/调研、跑一串命令看结果）派子代理干，
噪音留在子代理的独立上下文里，只把最终结论带回主上下文。
简单一两次工具调用能搞定的不要派——派发本身有开销。

## 类型选择（type 参数）

- `explore`：只读探索（搜索/读文件/调研）。跑只读约束，零审批，随时可派。
- `bash`：终端执行（跑命令、看输出）。沿用当前会话模式与审批规则；
  Ask/Plan 只读模式下不可派。
- `fork`：分身。子代理开局自带本对话的摘录（用户/助手消息、工具调用
  一行摘要），prompt 只写指令不用重述背景。适合"结论要、中间噪音
  不要"的调研或验证；工具与模式同父任务。
- 自定义档案：环境上下文若列出「自定义子代理档案」，type 直接填档案名，
  子代理按该档案的专属提示词工作。只读档案零审批；可写档案沿用当前
  模式与审批规则（Ask/Plan 下不可派可写档案）。档案 frontmatter 可
  声明 `tools`（工具分组白名单）、`model`（指定模型）、`maxTurns`
  （轮数上限）、`memory: true`（持久记忆，跨任务累积经验到工作区
  `.aetherlink/agent-memory/<name>.md`）。

## prompt 写法

fork 之外的类型没有本对话的记忆，prompt 必须自带全部必要上下文：
- 交代背景（在哪个目录/仓库、任务目标是什么）；
- 说清要做什么、边界在哪；
- 说明期望返回的结论形态（如"列出文件路径+每处一句结论"）。

fork 的 prompt 是指令：只写要做什么、范围边界，不用再交代背景。

description 参数填 3~8 个词的一句话标题（展示用）。

## 并行与后台

- 同一轮发多个 spawn_subagent 调用即并行执行；互不依赖的子任务尽量并行派。
- `background=true` 后台跑：工具立即返回不阻塞你继续干活，子代理完成后
  结论会回填工具结果并以消息注入对话。适合不依赖其结论就能继续推进的
  子任务；需要马上用结论的用前台（默认）。

## 注意

- 子代理只回传最终结论，中间过程不进你的上下文（用户可在界面展开回看）。
- 子代理内不能再派子代理。''',
  ),
  Skill(
    id: 'builtin-browser',
    name: '内置浏览器',
    description: '内置浏览器工具（@aether/browser）的完整用法：fetch 与 browser '
        '的选择、语义快照与 @N 定位、交互与等待纪律、browser_run 批量脚本',
    emoji: '🌏',
    tags: ['浏览器', '网页', '自动化'],
    source: SkillSource.builtin,
    version: '1.0.0',
    author: 'AetherLink',
    enabled: true,
    content: '''
## 何时用浏览器

- 静态页面/API/文档：优先用 `fetch`——更快更省。
- 只有 JS 渲染页面（SPA、动态加载）、需要登录态/cookies、需要交互
  （点击/填表/搜索）时才升级到 browser 工具。
- browser 会话在多次调用间保留（cookies/登录态不丢失）。

## 标准工作流

1. `browser_open(url)` 打开页面（返回标题 + 首屏预览）。
2. `browser_snapshot_dom` 看语义快照：标题结构 + 可见交互元素，每个元素
   带 `@N` 编号、角色、名称、状态。比截图省 token，优先用它而非截图。
3. 用 `@N` 定位交互：`browser_click(target: "@3")` /
   `browser_input(target: "@2", text: "...", submit: true)`。
   target 也支持 `role:button:登录` 和 CSS 选择器。
4. **@N 生命周期**：页面导航或重新快照后旧编号一律失效，交互结果里
   会提示；失效后重新 `browser_snapshot_dom`。
5. 只在需要视觉理解（布局/图表/验证渲染）时用 `browser_snapshot` 截图。

## 先等待，再动作，后验证

- 动态页面点击前用 `browser_wait(selector: ...)` 等元素出现，
  不要盲目重试点击。
- click/input 返回"是否触发导航 + 当前标题/URL"——每步动作后核对
  这个结果再走下一步，不要假设动作已生效。
- `browser_wait` 超时返回"未成立"而非报错：把它当分支条件用
  （成立→继续；未成立→重新快照换策略）。

## browser_run：一次调用完成多步

页内多步"读→判→点→等→验"用 `browser_run` 一段脚本完成，比逐个调用
单步工具更快更省 token。脚本内可用 `aether` 助手（都是页内操作）：

```
browser_run(script: `
  const rows = [...document.querySelectorAll('article')].map(a => ({
    title: a.querySelector('h2')?.innerText,
    href: a.querySelector('a')?.href,
  }));
  const hit = rows.find(r => r.title?.includes('Flutter'));
  if (!hit) return { rows };
  await aether.fill('role:textbox:搜索', 'Flutter');
  await aether.press('Enter');
  const ok = await aether.waitFor({ selector: '.results', timeoutMs: 8000 });
  return { ok, count: document.querySelectorAll('.result').length };
`)
```

- 纪律：先把可预测的观察/动作/验证**编码进一段脚本**再调用，
  不要一步一调；`return` 只带结论数据，不要整页 HTML。
- 动作触发页面导航会中断脚本——跨页任务拆成多次调用
  （脚本走到导航为止，导航后重新快照再继续）。
- `aether.waitFor` 超时返回 false 不抛异常，用返回值分支。

## 省 token 纪律

- 结果只要结论：browser_read 用 selector/分块，browser_run 用 return
  精简数据；避免重复快照同一未变化的页面。
- 连续失败 2-3 次停下换思路（换定位方式/重新快照/询问用户），
  不要反复重试同一操作。''',
  ),
  // —— 工具集成 ——
  Skill(
    id: 'builtin-mcp-bridge',
    name: 'MCP 工具大师',
    description: '智能发现和调用当前可用的 MCP 工具服务器，无需手动配置即可使用所有已启用的工具能力',
    emoji: '🔌',
    tags: ['MCP', '工具', '自动化'],
    source: SkillSource.builtin,
    version: '1.0.0',
    author: 'AetherLink',
    enabled: true,
  ),
];
