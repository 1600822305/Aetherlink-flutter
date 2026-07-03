/// 结构化裁决（P1 增强，web 版没有）：辩论结束后由总结模型输出 JSON，
/// 解析成 获胜方 + 四维评分 + 关键交锋点 的裁决卡片。
library;

import 'dart:convert';

/// 一方（或一个角色）的四维评分，1-10。
class DebateSideScore {
  const DebateSideScore({
    required this.name,
    this.logic = 0,
    this.evidence = 0,
    this.rebuttal = 0,
    this.expression = 0,
  });

  factory DebateSideScore.fromJson(Map<String, dynamic> json) =>
      DebateSideScore(
        name: json['name']?.toString() ?? '',
        logic: _score(json['logic']),
        evidence: _score(json['evidence']),
        rebuttal: _score(json['rebuttal']),
        expression: _score(json['expression']),
      );

  final String name;
  final int logic;
  final int evidence;
  final int rebuttal;
  final int expression;

  int get total => logic + evidence + rebuttal + expression;

  static int _score(Object? value) {
    final n = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    return n.clamp(0, 10);
  }
}

/// 一次辩论的裁决结果。
class DebateVerdict {
  const DebateVerdict({
    required this.winner,
    this.rationale = '',
    this.scores = const <DebateSideScore>[],
    this.clashPoints = const <String>[],
  });

  factory DebateVerdict.fromJson(Map<String, dynamic> json) => DebateVerdict(
    winner: json['winner']?.toString() ?? '',
    rationale: json['rationale']?.toString() ?? '',
    scores: [
      for (final s in (json['scores'] as List? ?? const []))
        if (s is Map) DebateSideScore.fromJson(s.cast<String, dynamic>()),
    ],
    clashPoints: [
      for (final p in (json['clashPoints'] as List? ?? const []))
        if ('$p'.trim().isNotEmpty) '$p'.trim(),
    ],
  );

  /// 获胜方名称；模型可回答「平局」。
  final String winner;
  final String rationale;
  final List<DebateSideScore> scores;
  final List<String> clashPoints;

  bool get isValid => winner.trim().isNotEmpty;

  /// 从模型输出中提取第一个 `{...}` JSON 对象并解析；容忍 ```json 围栏与
  /// 前后闲话，解析失败返回 null（调用方降级为普通总结）。
  static DebateVerdict? tryParse(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      if (decoded is! Map) return null;
      final verdict = DebateVerdict.fromJson(decoded.cast<String, dynamic>());
      return verdict.isValid ? verdict : null;
    } on FormatException {
      return null;
    }
  }

  /// 渲染成聊天里的裁决卡片 Markdown。
  String toMarkdown(String topic) {
    final buffer = StringBuffer()
      ..writeln('⚖️ **辩论裁决**')
      ..writeln()
      ..writeln('**辩题：** $topic')
      ..writeln()
      ..writeln('🏆 **胜方：$winner**');
    if (rationale.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('> ${rationale.trim().replaceAll('\n', '\n> ')}');
    }
    if (scores.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('| 角色 | 逻辑 | 证据 | 反驳 | 表达 | 总分 |')
        ..writeln('| --- | :-: | :-: | :-: | :-: | :-: |');
      for (final s in scores) {
        buffer.writeln(
          '| ${s.name} | ${s.logic} | ${s.evidence} | ${s.rebuttal} '
          '| ${s.expression} | **${s.total}** |',
        );
      }
    }
    if (clashPoints.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('**关键交锋点：**');
      for (final p in clashPoints) {
        buffer.writeln('- $p');
      }
    }
    return buffer.toString().trimRight();
  }
}
