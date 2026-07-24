import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/agent_runtime_access.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/context_breakdown.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/widgets/agent_status.dart';

/// 工作台「上下文」tab（对标 CC /context）：按系统提示 / 工具定义 /
/// 消息重放各部分展示估算 token 占用，配比例条 + 明细列表。
class WorkbenchContextTab extends ConsumerWidget {
  const WorkbenchContextTab({required this.task, super.key});

  final AgentTask task;

  static const _sectionColors = [
    Color(0xFF7C6FE8), // 系统提示
    Color(0xFF4E9AF1), // 工具定义
    Color(0xFF43B77A), // 用户消息
    Color(0xFFE8A13C), // 助手回复
    Color(0xFFD96A6A), // 工具调用与结果
    Color(0xFF9A8A6A), // 压缩摘要
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final breakdown = ref.watch(agentContextBreakdownProvider(task.id));
    return breakdown.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text('分解计算失败：$e', style: theme.textTheme.bodySmall)),
      data: (data) {
        final total = data.estimatedTotal;
        // API 实测可能滞后：供应商不回 usage 时沿用旧值，标注
        // 测量轮次避免与当前估算直接对比造成误解。
        final stale =
            data.apiContextTokens > 0 &&
            task.contextTokensRound > 0 &&
            task.contextTokensRound < task.rounds;
        if (total == 0) {
          return Center(
            child: Text(
              '暂无上下文数据',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '估算总量 ${formatTokens(total)} tokens'
              '${data.apiContextTokens > 0 ? ' · API 实测 ${formatTokens(data.apiContextTokens)}'
                        '${task.contextTokensRound > 0 ? '（第${task.contextTokensRound}轮）' : ''}' : ''}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '按当前请求组成估算（字符启发式），实际计量以 API 为准。'
              '${stale ? '\n⚠ API 实测来自第${task.contextTokensRound}轮'
                        '（当前第${task.rounds}轮）：之后供应商未回报 usage，'
                        '该值可能已滞后。' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    for (var i = 0; i < data.sections.length; i++)
                      if (data.sections[i].estimatedTokens > 0)
                        Expanded(
                          flex: data.sections[i].estimatedTokens,
                          child: ColoredBox(
                            color: _sectionColors[i % _sectionColors.length],
                          ),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < data.sections.length; i++)
              _SectionRow(
                section: data.sections[i],
                color: _sectionColors[i % _sectionColors.length],
                total: total,
              ),
          ],
        );
      },
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.section,
    required this.color,
    required this.total,
  });

  final ContextSection section;
  final Color color;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final percent = total > 0 ? section.estimatedTokens * 100 / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(section.label, style: theme.textTheme.bodyMedium),
          ),
          Text(
            '${formatTokens(section.estimatedTokens)} · '
            '${percent.toStringAsFixed(1)}%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
