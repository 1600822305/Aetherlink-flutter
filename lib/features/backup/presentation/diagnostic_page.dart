import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/backup/application/backup_controller.dart';
import 'package:aetherlink_flutter/features/backup/data/database_diagnostic_service.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// Detail page for database diagnostics.
class DiagnosticPage extends ConsumerStatefulWidget {
  const DiagnosticPage({super.key});

  @override
  ConsumerState<DiagnosticPage> createState() => _DiagnosticPageState();
}

class _DiagnosticPageState extends ConsumerState<DiagnosticPage> {
  DiagnosticResult? _result;
  bool _isRunning = false;

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(backupControllerProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const ModelSettingsAppBar(title: '数据库诊断'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _Card(
            child: Column(
              children: [
                _ActionRow(
                  icon: LucideIcons.heartPulse,
                  accent: const Color(0xFF2563EB),
                  label: _isRunning ? '诊断中...' : '运行健康检查',
                  description: '检查数据库完整性，查找孤立数据',
                  onTap: _isRunning ? null : () => _runDiagnostic(controller),
                ),
                if (!(_result?.isHealthy ?? true))
                  Column(
                    children: [
                      Divider(height: 1, color: theme.dividerColor),
                      _ActionRow(
                        icon: LucideIcons.wrench,
                        accent: const Color(0xFFF59E0B),
                        label: '修复问题',
                        description: '清理孤立消息和消息块',
                        onTap: _isRunning
                            ? null
                            : () => _performRepair(controller),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            _buildResultCard(theme),
          ],
        ],
      ),
    );
  }

  Future<void> _runDiagnostic(BackupController controller) async {
    setState(() => _isRunning = true);
    try {
      final result = await controller.runDiagnostic();
      if (mounted) {
        setState(() {
          _result = result;
          _isRunning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRunning = false);
        AppToast.error(context, '诊断失败: $e');
      }
    }
  }

  Future<void> _performRepair(BackupController controller) async {
    setState(() => _isRunning = true);
    try {
      final result = await controller.repairDatabase();
      if (!mounted) return;
      setState(() => _isRunning = false);
      AppToast.success(
        context,
        '修复完成: 清理了 ${result.orphanedMessagesRemoved} 条孤立消息, '
        '${result.orphanedBlocksRemoved} 个孤立消息块',
      );
      _runDiagnostic(controller);
    } catch (e) {
      if (mounted) {
        setState(() => _isRunning = false);
        AppToast.error(context, '修复失败: $e');
      }
    }
  }

  Widget _buildResultCard(ThemeData theme) {
    final result = _result!;
    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.isHealthy
                      ? LucideIcons.circleCheck
                      : LucideIcons.triangleAlert,
                  color: result.isHealthy ? Colors.green : Colors.orange,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  result.isHealthy ? '数据库健康' : '发现问题',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _statRow(theme, '数据库大小', result.databaseSizeDisplay),
            _statRow(theme, '对话数', '${result.topicCount}'),
            _statRow(theme, '消息数', '${result.messageCount}'),
            _statRow(theme, '消息块数', '${result.messageBlockCount}'),
            _statRow(theme, '服务商数', '${result.providerCount}'),
            _statRow(theme, '助手数', '${result.assistantCount}'),
            _statRow(theme, '分组数', '${result.groupCount}'),
            if (result.orphanedMessages > 0)
              _statRow(
                theme,
                '孤立消息',
                '${result.orphanedMessages}',
                isWarning: true,
              ),
            if (result.orphanedBlocks > 0)
              _statRow(
                theme,
                '孤立消息块',
                '${result.orphanedBlocks}',
                isWarning: true,
              ),
            if (result.issues.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...result.issues.map(
                (i) => Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.alertCircle,
                        size: 14,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          i,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statRow(
    ThemeData theme,
    String label,
    String value, {
    bool isWarning = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 13)),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isWarning ? Colors.orange : null,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Shared Widgets
// =============================================================================

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.accent,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      height: 1.3,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
