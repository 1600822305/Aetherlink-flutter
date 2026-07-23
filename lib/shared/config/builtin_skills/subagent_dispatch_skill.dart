import 'package:aetherlink_flutter/shared/domain/skill.dart';

/// 内置 skill：子代理派发（spawn_subagent）的完整用法。
const Skill kSubagentDispatchSkill = Skill(
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
);
