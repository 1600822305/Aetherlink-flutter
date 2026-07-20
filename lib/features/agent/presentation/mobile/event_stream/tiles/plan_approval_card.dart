import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/markdown_access.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_approval_registry.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/event_rail.dart';

/// 方案审批卡（exit_plan_mode，对标 CC ExitPlanMode 审批）：渲染模型
/// 提交的方案全文，可先编辑再批准（编辑版回填给模型作为最终方案）；
/// 「批准并免审执行」切 Auto 模式（工作区内写/命令直通）；拒绝可附
/// 修改意见（回填给模型留在计划模式修订）。无挂起（重启后的历史卡）
/// 时按钮禁用，续跑任务会重建审批。
class PlanApprovalCard extends ConsumerStatefulWidget {
  const PlanApprovalCard(
      {required this.event, required this.taskId, super.key});

  final ToolCallEvent event;
  final String taskId;

  @override
  ConsumerState<PlanApprovalCard> createState() => _PlanApprovalCardState();
}

class _PlanApprovalCardState extends ConsumerState<PlanApprovalCard> {
  bool _editing = false;
  late final TextEditingController _planController =
      TextEditingController(text: _plan);

  @override
  void dispose() {
    _planController.dispose();
    super.dispose();
  }

  String get _plan {
    try {
      final args = jsonDecode(widget.event.argsDetail ?? '{}');
      if (args is Map<String, dynamic>) {
        final plan = args['plan'];
        if (plan is String && plan.trim().isNotEmpty) return plan.trim();
      }
    } catch (_) {}
    return widget.event.argsDetail ?? '';
  }

  /// 编辑框里的方案与原文不同时作为 editedPlan 随裁决回传。
  String? get _editedPlan {
    final text = _planController.text.trim();
    if (text.isEmpty || text == _plan) return null;
    return text;
  }

  void _respond(AgentApprovalDecision decision) {
    ref
        .read(agentApprovalRegistryProvider.notifier)
        .respond(widget.taskId, decision);
  }

  Future<void> _reject() async {
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
    _respond(AgentApprovalDecision(
      approved: false,
      reason: reason.isEmpty ? '用户拒绝了方案，请修订后重新提交' : reason,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final pending =
        ref.watch(agentApprovalRegistryProvider)[widget.taskId];
    final active =
        pending != null && pending.call.name == widget.event.toolName;

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    _editing ? '编辑方案（批准时以编辑版为准）' : '方案待批准',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (active)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: _editing ? '预览' : '编辑方案',
                    icon: Icon(
                      _editing ? LucideIcons.eye : LucideIcons.pencil,
                      size: 16,
                    ),
                    onPressed: () => setState(() => _editing = !_editing),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_editing)
              TextField(
                controller: _planController,
                maxLines: null,
                minLines: 6,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.5,
                ),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              )
            else
              AppMarkdown(
                content: _editedPlan ?? _plan,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: active
                      ? () => _respond(AgentApprovalDecision(
                            approved: true,
                            editedPlan: _editedPlan,
                          ))
                      : null,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(LucideIcons.check, size: 16),
                  label: const Text('批准，开始执行'),
                ),
                FilledButton.tonalIcon(
                  onPressed: active
                      ? () => _respond(AgentApprovalDecision(
                            approved: true,
                            editedPlan: _editedPlan,
                            autoAccept: true,
                          ))
                      : null,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(LucideIcons.zap, size: 16),
                  label: const Text('批准并免审执行'),
                ),
                OutlinedButton(
                  onPressed: active ? _reject : null,
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
