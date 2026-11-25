import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/agent_runtime_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_compaction_settings.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_task_runner.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_ui_settings.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_compaction_trigger.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/context_breakdown.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/settings/agent_compaction_settings_page.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/widgets/agent_status.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// 工作台「上下文」tab（对标 CC /context）——环形仪表版：
/// · 顶部环形仪表：已用 / 窗口上限、剩余、距自动压缩还差多少，红色刻度
///   标出压缩触发线；估算与 API 实测分开显示，实测滞后时标黄。
/// · 组成列表：每类可展开，列出占用最多的几条（哪个文件、哪次工具输出）。
/// · 底部操作：立即压缩（复用压缩设置页同款确认流程）、复制分析。
class WorkbenchContextTab extends ConsumerWidget {
  const WorkbenchContextTab({required this.task, super.key});

  final AgentTask task;

  /// 分类色（数据可视化色板，明暗主题下都可辨识）。
  static const _sectionColors = [
    Color(0xFF7C6FE8), // 系统提示
    Color(0xFF4E9AF1), // 工具定义
    Color(0xFF43B77A), // 用户消息
    Color(0xFFE8A13C), // 助手回复
    Color(0xFFD96A6A), // 工具调用与结果
    Color(0xFF9A8A6A), // 压缩摘要
    Color(0xFF4FB3BF), // 图片
  ];

  static Color colorFor(int i) => _sectionColors[i % _sectionColors.length];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final breakdown = ref.watch(agentContextBreakdownProvider(task.id));
    final limit = ref.watch(agentUiSettingsControllerProvider).contextLimit;
    final compaction = ref.watch(agentCompactionSettingsProvider);

    return breakdown.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('分解计算失败：$e', style: theme.textTheme.bodySmall),
      ),
      data: (data) {
        final estimated = data.estimatedTotal;
        if (estimated == 0) {
          return Center(
            child: Text(
              '暂无上下文数据',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
          );
        }
        final api = data.apiContextTokens;
        final stale =
            api > 0 &&
            task.contextTokensRound > 0 &&
            task.contextTokensRound < task.rounds;
        // 仪表以实测为准（实测滞后或缺失时退回估算）。
        final used = api > 0 && !stale ? api : estimated;
        final trigger = limit > 0
            ? compactionTriggerTokens(
                limit,
                triggerRatio: compaction.triggerRatio,
              )
            : 0;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            _GaugeCard(
              sections: data.sections,
              estimated: estimated,
              used: used,
              limit: limit,
              trigger: trigger,
              autoCompact: compaction.autoCompactEnabled,
              api: api,
              apiRound: task.contextTokensRound,
              currentRound: task.rounds,
              stale: stale,
            ),
            if (task.contextHistory.length >= 2) ...[
              const SizedBox(height: 12),
              _TrendCard(
                history: task.contextHistory,
                limit: limit,
                trigger: trigger,
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '组成',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    '点开看明细',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            _Card(
              child: Column(
                children: [
                  for (var i = 0; i < data.sections.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 34,
                        color: theme.dividerColor,
                      ),
                    _SectionTile(
                      section: data.sections[i],
                      color: colorFor(i),
                      total: estimated,
                      onClear: (item) => _clear(context, ref, [item]),
                    ),
                  ],
                ],
              ),
            ),
            if (data.bulkClearable.isNotEmpty ||
                data.manuallyClearedIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ClearCard(
                count: data.bulkClearable.length,
                tokens: data.bulkClearableTokens,
                clearedCount: data.manuallyClearedIds.length,
                onClear: () => _clear(context, ref, data.bulkClearable),
                onRestore: () => _restore(
                  context,
                  ref,
                  data.manuallyClearedIds.toList(),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: task.status == AgentTaskStatus.draft
                        ? null
                        : () => confirmAndCompactNow(context, ref, task),
                    icon: const Icon(LucideIcons.minimize2, size: 16),
                    label: const Text('立即压缩'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _copyReport(
                      context,
                      data,
                      used: used,
                      limit: limit,
                      trigger: trigger,
                    ),
                    icon: const Icon(LucideIcons.copy, size: 16),
                    label: const Text('复制分析'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _clear(
    BuildContext context,
    WidgetRef ref,
    List<ContextItem> items,
  ) async {
    final ids = [
      for (final i in items)
        if (i.clearable && i.eventId != null) i.eventId!,
    ];
    if (ids.isEmpty) return;
    final freed = items.fold(0, (sum, i) => sum + i.estimatedTokens);
    if (ids.length > 1) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('清理大输出'),
          content: Text(
            '将从上下文里移除 ${ids.length} 条较早的工具输出（约 ${formatTokens(freed)}），'
            '只保留调用记录。\n\n'
            '事件流里的原文不受影响，之后可以随时恢复；模型需要时会重新调用工具获取。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('清理'),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }
    try {
      await ref
          .read(agentTaskRunnerProvider.notifier)
          .clearToolOutputs(task.id, ids, freedTokens: freed);
      if (context.mounted) {
        AppToast.success(context, '已清理 ${ids.length} 条，约释放 ${formatTokens(freed)}');
      }
    } catch (e) {
      if (context.mounted) AppToast.error(context, '清理失败：$e');
    }
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return;
    try {
      await ref
          .read(agentTaskRunnerProvider.notifier)
          .restoreToolOutputs(task.id, ids);
      if (context.mounted) AppToast.success(context, '已恢复 ${ids.length} 条工具输出');
    } catch (e) {
      if (context.mounted) AppToast.error(context, '恢复失败：$e');
    }
  }

  Future<void> _copyReport(
    BuildContext context,
    AgentContextBreakdown data, {
    required int used,
    required int limit,
    required int trigger,
  }) async {
    final total = data.estimatedTotal;
    final b = StringBuffer('## 上下文占用\n\n');
    b.writeln(
      limit > 0
          ? '- 已用 ${formatTokens(used)} / ${formatTokens(limit)}'
                '（${(used * 100 / limit).toStringAsFixed(1)}%）'
          : '- 已用 ${formatTokens(used)}',
    );
    if (trigger > 0) b.writeln('- 自动压缩线 ${formatTokens(trigger)}');
    b.writeln('- 估算 ${formatTokens(total)}'
        '${data.apiContextTokens > 0 ? ' · API 实测 ${formatTokens(data.apiContextTokens)}' : ''}');
    b.writeln('\n| 分类 | tokens | 占比 |\n|---|---|---|');
    for (final s in data.sections) {
      final pct = total > 0 ? s.estimatedTokens * 100 / total : 0.0;
      b.writeln(
        '| ${s.label} | ${formatTokens(s.estimatedTokens)} | ${pct.toStringAsFixed(1)}% |',
      );
    }
    await Clipboard.setData(ClipboardData(text: b.toString()));
    if (context.mounted) AppToast.success(context, '已复制上下文分析');
  }
}

/// 「清理大输出」提示卡：有候选时给一键清理；有清理记录时可恢复。
class _ClearCard extends StatelessWidget {
  const _ClearCard({
    required this.count,
    required this.tokens,
    required this.clearedCount,
    required this.onClear,
    required this.onRestore,
  });

  final int count;
  final int tokens;
  final int clearedCount;
  final VoidCallback onClear;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Icon(LucideIcons.eraser, size: 18, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count > 0
                        ? '$count 条较早的大输出，约 ${formatTokens(tokens)}'
                        : '没有可清理的大输出',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    clearedCount > 0
                        ? '已手动清理 $clearedCount 条 · 原文仍在事件流里'
                        : '文件读取、终端、搜索等可重新获取的输出',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (clearedCount > 0)
              TextButton(onPressed: onRestore, child: const Text('恢复')),
            if (count > 0)
              FilledButton.tonal(onPressed: onClear, child: const Text('清理')),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

// ===== 环形仪表 =====

class _GaugeCard extends StatelessWidget {
  const _GaugeCard({
    required this.sections,
    required this.estimated,
    required this.used,
    required this.limit,
    required this.trigger,
    required this.autoCompact,
    required this.api,
    required this.apiRound,
    required this.currentRound,
    required this.stale,
  });

  final List<ContextSection> sections;
  final int estimated;
  final int used;
  final int limit;
  final int trigger;
  final bool autoCompact;
  final int api;
  final int apiRound;
  final int currentRound;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasLimit = limit > 0;
    final ratio = hasLimit ? used / limit : 0.0;
    final remaining = hasLimit ? math.max(0, limit - used) : 0;
    final toTrigger = trigger > 0 ? trigger - used : 0;

    // 状态色：未到压缩线 90% 为正常，之后黄，超线红。
    final Color stateColor;
    final String stateText;
    if (!hasLimit) {
      stateColor = cs.onSurfaceVariant;
      stateText = '未设置上下文窗口';
    } else if (trigger > 0 && toTrigger <= 0) {
      stateColor = cs.error;
      stateText = autoCompact ? '已达压缩线，下一轮将自动压缩' : '已超压缩线（自动压缩已关闭）';
    } else if (trigger > 0 && used >= trigger * 0.9) {
      stateColor = const Color(0xFFCA8A04);
      stateText = '距自动压缩还有 ${formatTokens(toTrigger)}';
    } else {
      stateColor = const Color(0xFF16A34A);
      stateText = trigger > 0
          ? '距自动压缩还有 ${formatTokens(toTrigger)}'
          : '剩余 ${formatTokens(remaining)}';
    }

    // 环上各段按「占窗口比例」画；没有窗口上限时按占估算总量画满一圈。
    final denom = hasLimit ? math.max(limit, estimated) : estimated;
    final segments = [
      for (var i = 0; i < sections.length; i++)
        if (sections[i].estimatedTokens > 0)
          (
            WorkbenchContextTab.colorFor(i),
            sections[i].estimatedTokens / denom,
          ),
    ];

    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
        child: Column(
          children: [
            SizedBox(
              width: 172,
              height: 172,
              child: CustomPaint(
                painter: _RingPainter(
                  segments: segments,
                  track: cs.onSurface.withValues(alpha: 0.07),
                  marker: hasLimit && trigger > 0 ? trigger / limit : null,
                  markerColor: cs.error,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasLimit
                            ? '${(ratio * 100).clamp(0, 999).toStringAsFixed(0)}%'
                            : formatTokens(used),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasLimit
                            ? '${formatTokens(used)} / ${formatTokens(limit)}'
                            : 'tokens',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: stateColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    hasLimit && toTrigger > 0
                        ? '剩余 ${formatTokens(remaining)} · $stateText'
                        : stateText,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: stateColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Metric(label: '估算', value: formatTokens(estimated)),
                const SizedBox(width: 8),
                _Metric(
                  label: apiRound > 0 ? 'API 实测 · 第$apiRound轮' : 'API 实测',
                  value: api > 0 ? formatTokens(api) : '—',
                  warn: stale,
                ),
              ],
            ),
            if (stale) ...[
              const SizedBox(height: 8),
              Text(
                '实测来自第$apiRound轮（当前第$currentRound轮），之后供应商未回报 usage，'
                '仪表暂按估算显示。',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: const Color(0xFFCA8A04),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.warn = false});

  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: warn ? const Color(0xFFCA8A04) : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.segments,
    required this.track,
    required this.markerColor,
    this.marker,
  });

  /// (颜色, 占整圈比例)。
  final List<(Color, double)> segments;
  final Color track;
  final Color markerColor;

  /// 压缩线位置（占整圈比例），null 不画。
  final double? marker;

  static const double _stroke = 14;
  static const double _gap = 0.004; // 段间留缝（占整圈比例）

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - _stroke / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.butt;

    canvas.drawCircle(center, radius, paint..color = track);

    var start = -math.pi / 2;
    var acc = 0.0;
    for (final (color, fraction) in segments) {
      final f = math.min(fraction, 1 - acc);
      if (f <= 0) break;
      final sweep = math.max(0.0, f - _gap) * 2 * math.pi;
      canvas.drawArc(rect, start, sweep, false, paint..color = color);
      start += f * 2 * math.pi;
      acc += f;
    }

    final m = marker;
    if (m != null && m > 0 && m < 1) {
      final angle = -math.pi / 2 + m * 2 * math.pi;
      final dir = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + dir * (radius - _stroke / 2 - 3),
        center + dir * (radius + _stroke / 2 + 3),
        Paint()
          ..color = markerColor
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.marker != marker ||
      old.track != track ||
      old.segments.length != segments.length ||
      !_sameSegments(old.segments);

  bool _sameSegments(List<(Color, double)> other) {
    for (var i = 0; i < segments.length; i++) {
      if (segments[i] != other[i]) return false;
    }
    return true;
  }
}

// ===== 趋势曲线 =====

/// 按轮次画上下文占用曲线：红色虚线是自动压缩线，明显回落处标「压缩」
/// （LLM 压缩或手动清理都会让占用骤降）。
class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.history,
    required this.limit,
    required this.trigger,
  });

  final List<ContextSample> history;
  final int limit;
  final int trigger;

  /// 相邻两次采样回落超过这个比例视为发生了压缩 / 清理。
  static const double _kDropRatio = 0.2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final last = history.last;
    final prev = history[history.length - 2];
    final delta = last.tokens - prev.tokens;
    final drops = <int>[
      for (var i = 1; i < history.length; i++)
        if (history[i].tokens < history[i - 1].tokens * (1 - _kDropRatio)) i,
    ];
    final peak = history.fold(0, (m, s) => math.max(m, s.tokens));

    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '增长趋势',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '本轮 ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${delta >= 0 ? '+' : '−'}${formatTokens(delta.abs())}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: delta > 0
                        ? cs.error
                        : const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '峰值 ${formatTokens(peak)}'
              '${drops.isNotEmpty ? ' · 压缩 / 清理 ${drops.length} 次' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 120,
              width: double.infinity,
              child: CustomPaint(
                painter: _TrendPainter(
                  history: history,
                  drops: drops,
                  maxY: math.max(
                    peak,
                    trigger > 0 ? trigger : (limit > 0 ? limit : peak),
                  ),
                  trigger: trigger,
                  line: cs.primary,
                  fill: cs.primary.withValues(alpha: 0.12),
                  grid: theme.dividerColor,
                  triggerColor: cs.error,
                  dropColor: cs.onSurfaceVariant,
                  labelStyle: theme.textTheme.bodySmall!.copyWith(fontSize: 9),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '第 ${history.first.round} 轮',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10.5,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  '第 ${last.round} 轮',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10.5,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.history,
    required this.drops,
    required this.maxY,
    required this.trigger,
    required this.line,
    required this.fill,
    required this.grid,
    required this.triggerColor,
    required this.dropColor,
    required this.labelStyle,
  });

  final List<ContextSample> history;
  final List<int> drops;
  final int maxY;
  final int trigger;
  final Color line;
  final Color fill;
  final Color grid;
  final Color triggerColor;
  final Color dropColor;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2 || maxY <= 0) return;
    const top = 12.0;
    final h = size.height - top;
    final firstRound = history.first.round;
    final span = math.max(1, history.last.round - firstRound);
    final top10 = maxY * 1.08;
    Offset at(ContextSample s) => Offset(
      (s.round - firstRound) / span * size.width,
      top + h - (s.tokens / top10) * h,
    );

    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()..color = grid,
    );

    if (trigger > 0) {
      final y = top + h - (trigger / top10) * h;
      final dash = Paint()
        ..color = triggerColor.withValues(alpha: 0.8)
        ..strokeWidth = 1;
      for (var x = 0.0; x < size.width; x += 7) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 4, size.width), y),
          dash,
        );
      }
      _label(
        canvas,
        '自动压缩 ${formatTokens(trigger)}',
        Offset(size.width, y - 2),
        triggerColor,
        alignRight: true,
      );
    }

    final path = Path()..moveTo(at(history.first).dx, at(history.first).dy);
    for (final s in history.skip(1)) {
      final o = at(s);
      path.lineTo(o.dx, o.dy);
    }
    final area = Path.from(path)
      ..lineTo(at(history.last).dx, size.height)
      ..lineTo(at(history.first).dx, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    for (final i in drops) {
      final x = (at(history[i - 1]).dx + at(history[i]).dx) / 2;
      final dash = Paint()
        ..color = dropColor.withValues(alpha: 0.6)
        ..strokeWidth = 1;
      for (var y = top; y < size.height; y += 5) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 2.5), dash);
      }
      _label(canvas, '压缩↓', Offset(x + 3, size.height - 12), dropColor);
    }

    canvas.drawCircle(at(history.last), 3.5, Paint()..color = line);
  }

  void _label(
    Canvas canvas,
    String text,
    Offset anchor,
    Color color, {
    bool alignRight = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: labelStyle.copyWith(color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(alignRight ? anchor.dx - tp.width : anchor.dx, anchor.dy - tp.height),
    );
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.history != history ||
      old.maxY != maxY ||
      old.trigger != trigger ||
      old.line != line;
}

// ===== 分类明细 =====

class _SectionTile extends StatefulWidget {
  const _SectionTile({
    required this.section,
    required this.color,
    required this.total,
    required this.onClear,
  });

  final ContextSection section;
  final Color color;
  final int total;
  final ValueChanged<ContextItem> onClear;

  @override
  State<_SectionTile> createState() => _SectionTileState();
}

class _SectionTileState extends State<_SectionTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = widget.section;
    final percent = widget.total > 0
        ? s.estimatedTokens * 100 / widget.total
        : 0.0;
    final expandable = s.topItems.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: expandable ? () => setState(() => _open = !_open) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.label, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: (percent / 100).clamp(0, 1),
                          minHeight: 3,
                          color: widget.color,
                          backgroundColor: cs.onSurface.withValues(alpha: 0.06),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${formatTokens(s.estimatedTokens)} · ${percent.toStringAsFixed(1)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                SizedBox(
                  width: 20,
                  child: expandable
                      ? Icon(
                          _open
                              ? LucideIcons.chevronUp
                              : LucideIcons.chevronDown,
                          size: 15,
                          color: cs.onSurfaceVariant,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(34, 0, 32, 10),
            child: Column(
              children: [
                for (final item in s.topItems)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: theme.dividerColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.label.isEmpty ? '（空）' : item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatTokens(item.estimatedTokens),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11.5,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        if (item.clearable) ...[
                          const SizedBox(width: 10),
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => widget.onClear(item),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Text(
                                '清理',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11.5,
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
