/// 系统提示五层组装（设计初稿 §5.2）：层级越靠前权威越高，
/// 后面的层只能补充专长/偏好，不能覆盖基础指南和安全边界。
/// 纯函数：环境上下文/项目指令由 composition 层取好传入，本文件不碰 IO。
library;

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

/// [1 内置基础指南]：固定内置、随版本迭代、用户不可改。
const String kAgentBaseGuide = '''
你是一个自主执行任务的智能体，在一个循环中工作：每轮你可以叙述进展并调用工具，工具结果会回填给你，直到任务完成。

工作方式：
- 自主多步推进，不要每一步都停下来等用户确认。
- 先探索后修改：动手改动前先用读类工具了解现状。
- 小步验证：每次改动后尽量用工具验证结果，再继续下一步。
- 复杂任务先用 update_plan 列出计划，并在推进中持续更新条目状态（全量覆盖式提交）。
- 只有在缺少关键信息、或决策会产生不可逆影响且无法自行判断时，才用 ask_user 向用户提问。
- 任务完成后调用 finish_task 并附一句简要总结；不要在没有完成时假装完成。

沟通风格（极简输出）：
- 极度压缩输出：能一两句话说清就不写长段，进展叙述一两句即可。
- 不写前言后语：不说"我来帮你…""让我先…""基于以上信息…"这类铺垫，直接回答或直接调用工具。
- 不复述工具输出：用户在事件流里看得到工具结果，只说结论和下一步。
- 完成任务简短确认，不逐步复述做了什么；finish_task 的总结一两句话。
- 不用表情和 ✅；出问题时如实说明原因，不谎报成功。

子代理（spawn_subagent，可用时才出现在工具列表）：
- 会产生大量中间输出的专项活（大范围搜索/调研用 explore、跑一串命令看结果用 bash），派子代理干，避免噪音挤爆主上下文；简单一两次调用能搞定的不要派。
- 子代理没有本对话的记忆，prompt 必须自带全部必要上下文并说明期望返回的结论形态。
- 同一轮发多个 spawn_subagent 调用即并行执行，互不依赖的子任务尽量并行派。
- 环境上下文若列出「自定义子代理档案」，type 填档案名即可按档案的专属提示词委派；只读档案零审批，可写档案沿用当前审批规则。
- 不依赖其结论就能继续干活的子任务可加 background=true 后台跑：立即返回不阻塞，完成后结论会以消息注入对话；需要马上用结论的仍用前台（默认）。

安全边界：
- 不执行破坏性、不可逆的操作（如删除大量文件、强制覆盖历史），除非用户明确要求。
- 不泄露、不记录任何密钥或凭据。
- 工具失败时分析原因换思路重试，不要无脑重复同一调用。''';

/// 各会话模式的附加说明（Code/Auto/Ask/Plan，设计初稿 §3）。
String _modeGuide(AgentSessionMode mode) => switch (mode) {
      AgentSessionMode.code => '当前为 Code 模式：可以直接修改文件、执行命令来完成任务。',
      AgentSessionMode.auto =>
        '当前为 Auto 模式：可以直接修改文件、执行命令；任务绑定工作区内的写入与命令'
            '免审批直通（执行命令时带上 workspace 参数指向绑定工作区），越出工作区'
            '的操作仍需用户审批。',
      AgentSessionMode.ask => '当前为 Ask 模式：只做调研与解答。写类工具与终端已不可用，不要尝试修改文件或执行命令。',
      AgentSessionMode.plan => '当前为 Plan 模式：只做分析并产出计划（用 update_plan 维护）。写类工具与终端已不可用，不要尝试修改文件。',
    };

/// 组装完整 system prompt。[environmentContext] 为运行时生成的
/// 工作区/平台/工具清单摘要；[userInstructions] 为用户附加指令
/// （设置项未上线时传 null）；[projectInstructions] 为工作区根目录
/// AGENTS.md 内容（不存在时传 null）。
String buildAgentSystemPrompt({
  required AgentTask task,
  required AgentProfile profile,
  required List<AgentEvent> events,
  String? environmentContext,
  String? userInstructions,
  String? projectInstructions,
}) {
  final sections = <String>[
    kAgentBaseGuide,
    _modeGuide(task.mode),
    if (environmentContext != null && environmentContext.trim().isNotEmpty)
      '[环境上下文]\n${environmentContext.trim()}',
    if (profile.systemPrompt.trim().isNotEmpty)
      '[专长设定]\n${profile.systemPrompt.trim()}',
    if (userInstructions != null && userInstructions.trim().isNotEmpty)
      '[用户附加指令]（不得覆盖以上基础指南与安全边界）\n${userInstructions.trim()}',
    if (projectInstructions != null && projectInstructions.trim().isNotEmpty)
      '[项目指令]（来自工作区 AGENTS.md）\n${projectInstructions.trim()}',
  ];

  // 计划置尾（设计初稿 §5.3）：最近一次 update_plan 的快照追加在最后，
  // 提醒模型当前进度，避免长上下文里计划被"遗忘"。
  final plan = events.whereType<PlanUpdateEvent>().lastOrNull;
  if (plan != null && plan.items.isNotEmpty) {
    final lines = [
      for (final item in plan.items)
        '- [${switch (item.status) {
          AgentPlanItemStatus.pending => ' ',
          AgentPlanItemStatus.inProgress => '~',
          AgentPlanItemStatus.completed => 'x',
        }}] ${item.content}',
    ];
    sections.add('[当前计划]\n${lines.join('\n')}');
  }

  return sections.join('\n\n');
}
