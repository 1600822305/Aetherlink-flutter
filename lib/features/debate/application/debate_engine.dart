import 'dart:async';

import 'package:aetherlink_flutter/features/debate/domain/debate_chat_port.dart';
import 'package:aetherlink_flutter/features/debate/domain/debate_models.dart';
import 'package:aetherlink_flutter/features/debate/domain/debate_verdict.dart';

/// 一次辩论的运行参数（保存的设置 + 开始面板的快速覆写合成）。
class DebateRunConfig {
  const DebateRunConfig({
    required this.topic,
    required this.roles,
    this.maxRounds = 3,
    this.turnGapSeconds = 3,
    this.historyWindow = 6,
    this.maxCharsPerTurn = 200,
    this.moderatorEnabled = true,
    this.summaryEnabled = true,
    this.verdictEnabled = false,
  });

  final String topic;
  final List<DebateRole> roles;
  final int maxRounds;
  final int turnGapSeconds;
  final int historyWindow;
  final int maxCharsPerTurn;
  final bool moderatorEnabled;
  final bool summaryEnabled;

  /// 裁决模式：总结阶段额外产出结构化裁决卡片（胜方 + 四维评分）。
  final bool verdictEnabled;

  /// 参与轮流发言的角色：总结角色只在总结阶段出场；主持人可被覆写关掉。
  List<DebateRole> get speakingRoles => [
    for (final r in roles)
      if (r.stance != DebateStance.summary &&
          (moderatorEnabled || r.stance != DebateStance.moderator))
        r,
  ];
}

/// 结构化的发言记录（web 用扁平字符串数组，这里保留轮次/角色结构）。
class DebateTurnRecord {
  const DebateTurnRecord({
    required this.round,
    required this.role,
    required this.content,
  });

  final int round;
  final DebateRole role;
  final String content;
}

enum DebateOutcome { completed, stopped }

typedef DebateProgressCallback =
    void Function(int round, DebateRole? speaking);

/// AI 辩论引擎：web `useAIDebate.ts` 的核心循环迁移成可单测的纯 Dart 类。
///
/// 流程：开场通告 → 逐轮按顺序让各角色发言（每次发言以该角色的模型流式
/// 写入一条助手消息）→ 主持人回复含 `[DEBATE_END]` 且 ≥2 轮时收束 →
/// 总结（优先总结角色，其次任意配模型的角色，都没有则输出本地降级文案）。
/// 任意阶段可 [stop]：中断当前流式请求与轮间等待。
class DebateEngine {
  DebateEngine({required this.port, this.onProgress});

  /// 主持人用于收束辩论的专属指令。
  static const String endDirective = '[DEBATE_END]';

  /// 用户插话在历史里的伪角色（不参与排班，只进上下文）。
  static const DebateRole audienceRole = DebateRole(
    id: 'debate-audience',
    name: '场外观众（用户插话）',
    description: '旁听辩论的用户',
    systemPrompt: '',
    stance: DebateStance.neutral,
  );

  final DebateChatPort port;
  final DebateProgressCallback? onProgress;

  final List<DebateTurnRecord> _history = [];
  bool _stopped = false;
  int _currentRound = 0;
  Completer<void>? _waiter;

  bool get isStopped => _stopped;
  List<DebateTurnRecord> get history => List.unmodifiable(_history);

  /// 用户插话：作为「场外发言」追加进历史，后续角色的上下文会包含它；
  /// 不改变发言排班。
  void injectUserMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _stopped) return;
    _history.add(
      DebateTurnRecord(
        round: _currentRound,
        role: audienceRole,
        content: trimmed,
      ),
    );
  }

  /// 停止辩论：中断正在进行的流式请求与轮间等待。
  void stop() {
    if (_stopped) return;
    _stopped = true;
    _waiter?.complete();
    _waiter = null;
    port.cancelActiveStream();
  }

  Future<DebateOutcome> run(DebateRunConfig config) async {
    final roles = config.speakingRoles;
    if (roles.isEmpty) {
      await port.announce('⚠️ **无法开始辩论**\n\n没有可发言的辩论角色。');
      return DebateOutcome.completed;
    }

    await port.announce(_openingMessage(config, roles));
    await _wait(const Duration(seconds: 1));
    if (_stopped) return DebateOutcome.stopped;

    var round = 1;
    while (round <= config.maxRounds && !_stopped) {
      _currentRound = round;
      for (final role in roles) {
        if (_stopped) break;
        onProgress?.call(round, role);

        final result = await port.speak(
          DebateSpeakRequest(
            role: role,
            round: round,
            system: role.systemPrompt,
            prompt: buildContext(config, role, round),
            header: '**第$round轮 - ${role.name}** (${role.stance.label})',
            metadata: _turnMetadata(role, round),
          ),
        );
        if (_stopped) break;

        if (result.succeeded) {
          _history.add(
            DebateTurnRecord(round: round, role: role, content: result.text!),
          );
        } else if (result.failed) {
          await port.announce(
            '⚠️ **${role.name}** 本轮发言失败'
            '${role.hasModel ? '' : '（未配置模型）'}，已跳过。',
          );
        }

        // 主持人收束：回复含专属指令且至少已进行 2 轮。
        if (result.succeeded &&
            role.stance == DebateStance.moderator &&
            round >= 2 &&
            result.text!.contains(endDirective)) {
          await _wait(const Duration(seconds: 2));
          if (_stopped) return DebateOutcome.stopped;
          await _conclude(config);
          return DebateOutcome.completed;
        }

        await _wait(Duration(seconds: config.turnGapSeconds));
      }
      round++;
    }

    if (_stopped) return DebateOutcome.stopped;
    await _conclude(config);
    return DebateOutcome.completed;
  }

  /// 构建某角色本次发言的完整上下文（迁移 web `buildDebateContext`，
  /// 历史窗口与字数约束改为可配置）。
  String buildContext(DebateRunConfig config, DebateRole role, int round) {
    final buffer = StringBuffer()
      ..writeln('你是${role.name}，${role.description}')
      ..writeln()
      ..writeln(role.systemPrompt)
      ..writeln()
      ..writeln('当前是第$round轮辩论。')
      ..writeln()
      ..writeln('辩论主题：${config.topic}')
      ..writeln();

    if (_history.isNotEmpty) {
      buffer.writeln('之前的发言：');
      final start = _history.length > config.historyWindow
          ? _history.length - config.historyWindow
          : 0;
      var hasAudience = false;
      for (final turn in _history.sublist(start)) {
        buffer.writeln('${turn.role.name}：${turn.content}');
        if (identical(turn.role, audienceRole)) hasAudience = true;
      }
      buffer.writeln();
      if (hasAudience) {
        buffer
          ..writeln('💬 以上发言中包含「场外观众（用户插话）」的提问或引导，请在保持自身立场的前提下适当回应。')
          ..writeln();
      }
    }

    if (role.stance == DebateStance.moderator) {
      buffer
        ..writeln('📊 **辩论进度提醒**：')
        ..writeln('- 当前轮数：第$round轮')
        ..writeln('- 总发言数：${_history.length}条');
      if (round < 2) {
        buffer.writeln('- 状态：辩论刚开始，请推动讨论深入，不要急于结束');
      } else if (round < 3) {
        buffer.writeln('- 状态：辩论进行中，继续引导各方深入交流');
      } else {
        buffer.writeln('- 状态：可以考虑是否已充分讨论，必要时可建议结束');
      }
      buffer
        ..writeln()
        ..writeln('🔚 **重要提醒**：如果你认为辩论已经充分进行，各方观点都得到了充分表达，可以在回应的最后添加专属停止指令：')
        ..writeln('**$endDirective** - 这是系统识别的结束指令，添加此指令后辩论将立即结束并进入总结阶段。')
        ..writeln();
    }

    buffer.write(
      '请基于你的角色立场和以上内容进行回应，保持专业和理性。'
      '回应应该简洁明了，不超过${config.maxCharsPerTurn}字。',
    );
    return buffer.toString();
  }

  Future<void> _conclude(DebateRunConfig config) async {
    onProgress?.call(0, null);
    if (!config.summaryEnabled) {
      if (config.verdictEnabled) {
        await _announceVerdict(config);
        return;
      }
      await port.announce('🏁 **AI辩论结束**\n\n感谢各位AI角色的精彩辩论！');
      return;
    }

    // 优先专门的总结角色，其次任意配置了模型的角色。
    final summaryRole = _pickSummaryRole(config);

    if (summaryRole == null) {
      await port.announce(_fallbackSummary(config, '未找到任何配置了模型的角色，无法调用 AI 生成总结。'));
      return;
    }

    final result = await port.speak(
      DebateSpeakRequest(
        role: summaryRole,
        round: 0,
        system: '你是一位专业的辩论分析师，擅长客观分析和总结辩论内容。请提供深入、平衡的分析。',
        prompt: _summaryPrompt(config),
        header: '🏁 **AI辩论总结**',
        metadata: _turnMetadata(summaryRole, 0, phase: 'summary'),
      ),
    );
    if (_stopped) return;
    if (!result.succeeded) {
      await port.announce(_fallbackSummary(config, 'AI 总结生成失败。'));
      return;
    }
    if (config.verdictEnabled) {
      await _announceVerdict(config, judge: summaryRole);
      if (_stopped) return;
    }
    await port.announce('🏁 **AI辩论结束**\n\n感谢各位AI角色的精彩辩论！');
  }

  /// 裁决模式：静默让裁判模型输出 JSON，解析后以卡片通告呈现；
  /// 生成或解析失败时只提示，不阻断收尾。
  Future<void> _announceVerdict(
    DebateRunConfig config, {
    DebateRole? judge,
  }) async {
    judge ??= _pickSummaryRole(config);
    if (judge == null) {
      await port.announce('⚖️ 裁决生成失败：未找到配置了模型的角色。');
      return;
    }
    final result = await port.generate(
      DebateSpeakRequest(
        role: judge,
        round: 0,
        system: '你是一位专业的辩论评判，只输出 JSON，不输出任何其它文字。',
        prompt: _verdictPrompt(config),
        header: '',
        metadata: _turnMetadata(judge, 0, phase: 'verdict'),
      ),
    );
    if (_stopped) return;
    final verdict = result.succeeded
        ? DebateVerdict.tryParse(result.text!)
        : null;
    if (verdict == null) {
      await port.announce('⚖️ 裁决生成失败（模型未返回有效的裁决 JSON）。');
      return;
    }
    await port.announce(
      verdict.toMarkdown(config.topic),
      metadata: _turnMetadata(judge, 0, phase: 'verdict'),
    );
  }

  String _verdictPrompt(DebateRunConfig config) {
    final record = StringBuffer();
    for (final turn in _history) {
      record.write('\n${turn.role.name}：${turn.content}\n');
    }
    final sides = [
      for (final r in config.speakingRoles)
        if (r.stance == DebateStance.pro ||
            r.stance == DebateStance.con ||
            r.stance == DebateStance.neutral)
          '"${r.name}"',
    ].join('、');
    return '''请作为中立评判，对以下辩论做出结构化裁决。

辩论主题：${config.topic}

完整辩论记录：
$record

参评角色：$sides

严格只输出一个 JSON 对象（不要代码围栏之外的文字），结构如下：
{
  "winner": "获胜角色名，无法分出胜负时填「平局」",
  "rationale": "一段简短的裁决理由（100字以内）",
  "scores": [
    {"name": "角色名", "logic": 1-10, "evidence": 1-10, "rebuttal": 1-10, "expression": 1-10}
  ],
  "clashPoints": ["关键交锋点1", "关键交锋点2"]
}
评分维度：logic=逻辑严密度、evidence=证据充分度、rebuttal=反驳有效性、expression=表达清晰度。''';
  }

  DebateRole? _pickSummaryRole(DebateRunConfig config) {
    for (final r in config.roles) {
      if (r.stance == DebateStance.summary && r.hasModel) return r;
    }
    for (final r in config.roles) {
      if (r.hasModel) return r;
    }
    return null;
  }

  String _summaryPrompt(DebateRunConfig config) {
    final record = StringBuffer('辩论主题：${config.topic}\n');
    for (final turn in _history) {
      record.write('\n${turn.role.name}：${turn.content}\n');
    }
    return '''请对以下AI辩论进行客观、专业的总结分析：

**辩论主题：** ${config.topic}

**完整辩论记录：**
$record

请提供一个结构化的总结，包括：

1. **主要观点梳理**：各方的核心论点和支撑论据
2. **分歧点分析**：双方争议的焦点和根本分歧
3. **论证质量评估**：各方论证的逻辑性和说服力
4. **共识点识别**：可能达成一致的观点或原则
5. **深度思考**：对辩论主题的进一步思考和启发
6. **结论建议**：基于辩论内容的平衡性建议

请保持客观中立，避免偏向任何一方，重点分析论证过程和思维逻辑。''';
  }

  String _fallbackSummary(DebateRunConfig config, String reason) {
    final start = _history.length > 6 ? _history.length - 6 : 0;
    final recent = _history.sublist(start);
    final record = recent.isEmpty
        ? '暂无有效角色发言记录。'
        : [
            for (var i = 0; i < recent.length; i++)
              '${i + 1}. ${recent[i].role.name}：${recent[i].content}',
          ].join('\n');
    return '''🏁 **AI辩论结束**

**辩论主题：** ${config.topic}

**总结状态：** 使用本地模板总结（$reason）

**已记录发言数：** ${_history.length} 条

**最近发言摘录：**
$record

**建议：** 在 AI 辩论设置中为「总结分析师」角色配置模型，下次将自动生成完整的 AI 总结。''';
  }

  String _openingMessage(DebateRunConfig config, List<DebateRole> roles) {
    final roleLines = [
      for (final r in roles) '• **${r.name}** (${r.stance.label})',
    ].join('\n');
    return '🎯 **AI辩论开始**\n\n'
        '**辩论主题：** ${config.topic}\n\n'
        '**参与角色：**\n$roleLines\n\n'
        '**最大轮数：** ${config.maxRounds}\n\n---\n\n让我们开始辩论！';
  }

  Map<String, dynamic> _turnMetadata(
    DebateRole role,
    int round, {
    String phase = 'turn',
  }) => {
    'debate': {
      'phase': phase,
      'round': round,
      'roleId': role.id,
      'roleName': role.name,
      'stance': role.stance.storageValue,
    },
  };

  /// 可中断的等待：stop() 会立即结束等待。
  Future<void> _wait(Duration duration) async {
    if (_stopped || duration <= Duration.zero) return;
    final waiter = Completer<void>();
    _waiter = waiter;
    final timer = Timer(duration, () {
      if (!waiter.isCompleted) waiter.complete();
    });
    await waiter.future;
    timer.cancel();
    if (identical(_waiter, waiter)) _waiter = null;
  }
}
