import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/markdown_access.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_approval_registry.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/event_rail.dart';

/// 方案审批卡（exit_plan_mode，对标 CC ExitPlanMode 审批）：渲染模型
/// 提交的方案全文，批准后退出计划模式开始执行，拒绝可附修改意见
/// （回填给模型留在计划模式修订）。无挂起（重启后的历史卡）时按钮
/// 禁用，续跑任务会重新发起。
class PlanApprovalCard extends ConsumerWidget {
  const PlanApprovalCard({required this.event, required this.taskId, super.key});

  final ToolCallEvent event;
  final String taskId;

  String get _plan {
    try {
      final args = jsonDecode(event.argsDetail ?? '{}');
      if (args is Map<String, dynamic>) {
        final plan = args['plan'];
        if (plan is String && plan.trim().isNotEmpty) return plan.trim();
      }
    } catch (_) {}
    return event.argsDetail ?? '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final pending = ref.watch(agentApprovalRegistryProvider)[taskId];
    final active = pending != null && pending.call.name == event.toolName;

    void respond(AgentApprovalDecision decision) {
      ref
          .read(agentApprovalRegistryProvider.notifier)
          .respond(taskId, decision);
    }

    Future<void> reject() async {
      final controller = TextEditingController();
      final reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('拒绝方案'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            minLines: 2,
            decoration: const InputDecoration(
              hintText: '修改意见（可选）：希望方案怎么调整',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('拒绝并返回修订'),
            ),
          ],
        ),
      );
      if (reason == null) return;
      respond(AgentApprovalDecision(
        approved: false,
        reason: reason.isEmpty ? '用户拒绝了方案，请修订后重新提交' : reason,
      ));
    }

    return EventRail(
      node: Icon(LucideIcons.clipboardCheck, size: 14, color: primary),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary.withValues(alpha: 0.4)),
          color: primary.withValues(alpha: 0.04),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '方案待批准',
              style: theme.textTheme.labelMedium?.copyWith(
                color: primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            AppMarkdown(
              content: _plan,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: active
                      ? () =>
                          respond(const AgentApprovalDecision(approved: true))
                      : null,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(LucideIcons.check, size: 16),
                  label: const Text('批准，开始执行'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: active ? reject : null,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('拒绝'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
