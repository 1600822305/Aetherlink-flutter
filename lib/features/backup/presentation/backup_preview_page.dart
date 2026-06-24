import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/backup/application/backup_controller.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_config.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_file_item.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_manifest.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

/// Preview page for a local backup file.
/// Shows manifest details (stats, time, device, options) and offers restore.
class BackupPreviewPage extends ConsumerStatefulWidget {
  final BackupFileItem item;

  const BackupPreviewPage({super.key, required this.item});

  @override
  ConsumerState<BackupPreviewPage> createState() => _BackupPreviewPageState();
}

class _BackupPreviewPageState extends ConsumerState<BackupPreviewPage> {
  BackupManifest? _manifest;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadManifest();
  }

  Future<void> _loadManifest() async {
    final controller = ref.read(backupControllerProvider.notifier);
    final filePath = widget.item.href.toFilePath();
    final manifest = await controller.peekBackupManifest(filePath);
    if (!mounted) return;
    setState(() {
      _manifest = manifest;
      _loading = false;
      _error = manifest == null ? '无法读取备份文件信息' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(backupControllerProvider);
    final isWorking = state.status == BackupStatus.working;

    ref.listen(backupControllerProvider, (prev, next) {
      if (next.status == BackupStatus.success ||
          next.status == BackupStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: next.status == BackupStatus.error
                ? theme.colorScheme.error
                : null,
          ),
        );
        final controller = ref.read(backupControllerProvider.notifier);
        Future.delayed(const Duration(seconds: 2), controller.clearStatus);
      }
    });

    return Scaffold(
      appBar: const ModelSettingsAppBar(title: '备份详情'),
      body: Stack(
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                )
              : _buildContent(theme),
          if (isWorking)
            Container(
              color: Colors.black26,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(state.message),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final manifest = _manifest!;
    final stats = manifest.stats;
    final options = manifest.options;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        // File info card
        _Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        widget.item.isAuto
                            ? LucideIcons.shieldCheck
                            : LucideIcons.archive,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.displayName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.item.sizeDisplay,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Manifest info card
        _Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '备份信息',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: LucideIcons.calendar,
                  label: '创建时间',
                  value: _formatDateTime(manifest.createdAt),
                ),
                _InfoRow(
                  icon: LucideIcons.smartphone,
                  label: '设备',
                  value: manifest.deviceInfo.isNotEmpty
                      ? manifest.deviceInfo
                      : '未知设备',
                ),
                _InfoRow(
                  icon: LucideIcons.code,
                  label: '应用版本',
                  value: 'v${manifest.appVersion}',
                ),
                _InfoRow(
                  icon: LucideIcons.database,
                  label: '数据版本',
                  value: 'Schema v${manifest.schemaVersion}',
                ),
                if (manifest.checksum.isNotEmpty)
                  _InfoRow(
                    icon: LucideIcons.shieldCheck,
                    label: '校验',
                    value: manifest.checksum.length > 20
                        ? '${manifest.checksum.substring(0, 20)}...'
                        : manifest.checksum,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Data stats card
        _Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '数据统计',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildStatsGrid(theme, stats),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Backup options card
        _Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '备份范围',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _OptionChip(label: '聊天记录', included: options.includeMessages),
                const SizedBox(height: 6),
                _OptionChip(label: '模型配置', included: options.includeProviders),
                const SizedBox(height: 6),
                _OptionChip(
                  label: '用户设置与助手',
                  included: options.includeSettings,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Restore button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(LucideIcons.upload, size: 18),
            label: const Text('从此备份恢复'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _confirmRestore(),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildStatsGrid(ThemeData theme, BackupStats stats) {
    final items = <_StatItem>[];
    if (stats.topics > 0) {
      items.add(_StatItem(label: '对话', count: stats.topics));
    }
    if (stats.messages > 0) {
      items.add(_StatItem(label: '消息', count: stats.messages));
    }
    if (stats.messageBlocks > 0) {
      items.add(_StatItem(label: '消息块', count: stats.messageBlocks));
    }
    if (stats.assistants > 0) {
      items.add(_StatItem(label: '助手', count: stats.assistants));
    }
    if (stats.providers > 0) {
      items.add(_StatItem(label: '服务商', count: stats.providers));
    }
    if (stats.groups > 0) {
      items.add(_StatItem(label: '分组', count: stats.groups));
    }
    if (stats.settings > 0) {
      items.add(_StatItem(label: '设置项', count: stats.settings));
    }

    if (items.isEmpty) {
      return Text(
        '无数据',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(
                '${item.count}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _confirmRestore() async {
    final mode = await showDialog<RestoreMode>(
      context: context,
      builder: (context) => _RestoreModeDialog(manifest: _manifest),
    );
    if (mode == null) return;

    final controller = ref.read(backupControllerProvider.notifier);
    final filePath = widget.item.href.toFilePath();
    await controller.restoreFromLocal(filePath, mode);
  }

  String _formatDateTime(String isoString) {
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return isoString;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// =============================================================================
// Restore Mode Dialog
// =============================================================================

class _RestoreModeDialog extends StatefulWidget {
  final BackupManifest? manifest;
  const _RestoreModeDialog({this.manifest});

  @override
  State<_RestoreModeDialog> createState() => _RestoreModeDialogState();
}

class _RestoreModeDialogState extends State<_RestoreModeDialog> {
  RestoreMode _mode = RestoreMode.overwrite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('选择恢复模式'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<RestoreMode>(
            title: const Text('覆盖模式'),
            subtitle: const Text('清空当前数据，完整恢复'),
            value: RestoreMode.overwrite,
            groupValue: _mode,
            onChanged: (v) => setState(() => _mode = v!),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<RestoreMode>(
            title: const Text('合并模式'),
            subtitle: const Text('保留当前数据，追加新内容'),
            value: RestoreMode.merge,
            groupValue: _mode,
            onChanged: (v) => setState(() => _mode = v!),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                LucideIcons.shieldCheck,
                size: 16,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '恢复前会自动备份当前数据',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _mode),
          child: const Text('确认恢复'),
        ),
      ],
    );
  }
}

// =============================================================================
// Helper Widgets
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  final String label;
  final bool included;

  const _OptionChip({required this.label, required this.included});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = included
        ? const Color(0xFF059669)
        : theme.colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Icon(
          included ? LucideIcons.circleCheck : LucideIcons.circleMinus,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: included ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          included ? '已包含' : '未包含',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StatItem {
  final String label;
  final int count;
  const _StatItem({required this.label, required this.count});
}
