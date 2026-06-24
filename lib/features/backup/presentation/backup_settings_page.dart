import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/backup/application/backup_controller.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_config.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_file_item.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_manifest.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

import 'cloud_backup_page.dart';
import 'import_data_page.dart';
import 'backup_reminder_page.dart';
import 'diagnostic_page.dart';

/// Entry page for data management / backup settings.
/// Redesigned to match the web version's flat layout with all primary actions
/// accessible directly, plus a dedicated "精细化备份" (selective backup) feature.
class BackupSettingsPage extends ConsumerStatefulWidget {
  const BackupSettingsPage({super.key});

  @override
  ConsumerState<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends ConsumerState<BackupSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(backupControllerProvider);
    final controller = ref.read(backupControllerProvider.notifier);
    final theme = Theme.of(context);

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
        Future.delayed(const Duration(seconds: 2), controller.clearStatus);
      }
    });

    final isWorking = state.status == BackupStatus.working;

    return Scaffold(
      appBar: const ModelSettingsAppBar(title: '数据管理'),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              _buildBackupRestoreCard(theme, controller, state, isWorking),
              const SizedBox(height: 16),
              _buildCloudBackupCard(theme, isWorking),
              const SizedBox(height: 16),
              _buildDataMigrationCard(theme, isWorking),
              const SizedBox(height: 16),
              _buildMaintenanceCard(theme, state, isWorking),
              if (state.localBackups.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildBackupHistoryCard(theme, state, controller),
              ],
            ],
          ),
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

  // ---------------------------------------------------------------------------
  // 备份与恢复
  // ---------------------------------------------------------------------------

  Widget _buildBackupRestoreCard(
    ThemeData theme,
    BackupController controller,
    BackupState state,
    bool isWorking,
  ) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: '备份与恢复',
            description: '创建本地备份或从备份文件恢复数据',
          ),
          Divider(height: 1, color: theme.dividerColor),
          _ActionRow(
            icon: LucideIcons.download,
            accent: const Color(0xFF2563EB),
            label: '创建完整备份',
            description: '将所有数据导出为 ZIP 文件并分享',
            onTap: isWorking ? null : controller.createAndShareBackup,
          ),
          Divider(height: 1, color: theme.dividerColor),
          _ActionRow(
            icon: LucideIcons.settings,
            accent: const Color(0xFF9333EA),
            label: '精细化备份',
            description: '选择需要备份的数据类型，按需导出',
            trailing: _RecommendedChip(),
            onTap: isWorking ? null : () => _showSelectiveBackupDialog(controller),
          ),
          Divider(height: 1, color: theme.dividerColor),
          _ActionRow(
            icon: LucideIcons.upload,
            accent: const Color(0xFF059669),
            label: '从文件恢复',
            description: '从本地 ZIP 备份文件恢复数据',
            onTap: isWorking ? null : () => _pickAndRestore(controller),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 云备份
  // ---------------------------------------------------------------------------

  Widget _buildCloudBackupCard(ThemeData theme, bool isWorking) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: '云备份',
            description: '通过 WebDAV 或 S3 将数据同步到云端',
          ),
          Divider(height: 1, color: theme.dividerColor),
          _NavigationRow(
            icon: LucideIcons.cloud,
            accent: const Color(0xFF0891B2),
            label: 'WebDAV / S3 云备份',
            description: '配置云存储并管理远程备份',
            onTap: isWorking ? null : () => _push(const CloudBackupPage()),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 数据迁移
  // ---------------------------------------------------------------------------

  Widget _buildDataMigrationCard(ThemeData theme, bool isWorking) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: '数据迁移',
            description: '从其他应用导入聊天记录和配置',
          ),
          Divider(height: 1, color: theme.dividerColor),
          _NavigationRow(
            icon: LucideIcons.folderInput,
            accent: const Color(0xFFD97706),
            label: '导入第三方数据',
            description: '支持 ChatboxAI / Cherry Studio 格式',
            onTap: isWorking ? null : () => _push(const ImportDataPage()),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 维护
  // ---------------------------------------------------------------------------

  Widget _buildMaintenanceCard(
    ThemeData theme,
    BackupState state,
    bool isWorking,
  ) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: '维护',
            description: '数据库诊断与备份提醒设置',
          ),
          Divider(height: 1, color: theme.dividerColor),
          _NavigationRow(
            icon: LucideIcons.bell,
            accent: const Color(0xFF8B5CF6),
            label: '备份提醒',
            description: state.reminderEnabled
                ? '已开启 · 每 ${state.reminderIntervalDays} 天提醒'
                : '未开启',
            onTap: isWorking ? null : () => _push(const BackupReminderPage()),
          ),
          Divider(height: 1, color: theme.dividerColor),
          _NavigationRow(
            icon: LucideIcons.database,
            accent: const Color(0xFF0D9488),
            label: '数据库诊断',
            description: '检查数据完整性，修复孤立数据',
            onTap: isWorking ? null : () => _push(const DiagnosticPage()),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 本地备份历史
  // ---------------------------------------------------------------------------

  Widget _buildBackupHistoryCard(
    ThemeData theme,
    BackupState state,
    BackupController controller,
  ) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: '本地备份历史',
            description: '最近的备份文件',
          ),
          Divider(height: 1, color: theme.dividerColor),
          ...state.localBackups.map((item) => _BackupFileRow(
                item: item,
                theme: theme,
                onDelete: () => controller.deleteLocalBackup(item.displayName),
              )),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _push(Widget page) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => page,
      ),
    );
  }

  Future<void> _pickAndRestore(BackupController controller) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    final manifest = await controller.peekBackupManifest(path);

    if (!mounted) return;

    final mode = await showDialog<RestoreMode>(
      context: context,
      builder: (context) => _RestoreConfirmDialog(manifest: manifest),
    );
    if (mode == null) return;

    await controller.restoreFromLocal(path, mode);
  }

  void _showSelectiveBackupDialog(BackupController controller) {
    showDialog(
      context: context,
      builder: (context) => _SelectiveBackupDialog(controller: controller),
    );
  }
}

// =============================================================================
// Selective Backup Dialog (精细化备份)
// =============================================================================

class _SelectiveBackupDialog extends StatefulWidget {
  final BackupController controller;
  const _SelectiveBackupDialog({required this.controller});

  @override
  State<_SelectiveBackupDialog> createState() => _SelectiveBackupDialogState();
}

class _SelectiveBackupDialogState extends State<_SelectiveBackupDialog> {
  bool _includeMessages = true;
  bool _includeProviders = true;
  bool _includeSettings = true;

  bool get _anySelected =>
      _includeMessages || _includeProviders || _includeSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF9333EA).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(LucideIcons.settings, size: 18, color: Color(0xFF9333EA)),
          ),
          const SizedBox(width: 12),
          const Text('精细化备份'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择需要备份的数据类型，可以根据需要单独备份部分数据。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _SelectiveOption(
              icon: LucideIcons.messageSquare,
              accent: const Color(0xFF2563EB),
              label: '聊天记录',
              description: '所有对话、消息和消息块数据',
              value: _includeMessages,
              onChanged: (v) => setState(() => _includeMessages = v),
            ),
            const SizedBox(height: 10),
            _SelectiveOption(
              icon: LucideIcons.settings,
              accent: const Color(0xFF9333EA),
              label: '模型配置',
              description: '服务商、模型列表和相关配置',
              value: _includeProviders,
              recommended: true,
              onChanged: (v) => setState(() => _includeProviders = v),
            ),
            const SizedBox(height: 10),
            _SelectiveOption(
              icon: LucideIcons.sliders,
              accent: const Color(0xFFF59E0B),
              label: '用户设置与助手',
              description: '应用设置、助手配置和分组信息',
              value: _includeSettings,
              onChanged: (v) => setState(() => _includeSettings = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          icon: const Icon(LucideIcons.download, size: 16),
          label: const Text('开始备份'),
          onPressed: _anySelected
              ? () {
                  Navigator.pop(context);
                  widget.controller.createSelectiveBackup(
                    includeMessages: _includeMessages,
                    includeProviders: _includeProviders,
                    includeSettings: _includeSettings,
                  );
                }
              : null,
        ),
      ],
    );
  }
}

/// A single option row in the selective backup dialog.
class _SelectiveOption extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String label;
  final String description;
  final bool value;
  final bool recommended;
  final ValueChanged<bool> onChanged;

  const _SelectiveOption({
    required this.icon,
    required this.accent,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
    this.recommended = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value ? accent : theme.dividerColor,
            width: value ? 1.5 : 1,
          ),
          color: value ? accent.withValues(alpha: 0.04) : Colors.transparent,
        ),
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
                  Row(
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (recommended) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '推荐',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CustomSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Restore Confirm Dialog
// =============================================================================

class _RestoreConfirmDialog extends StatefulWidget {
  final BackupManifest? manifest;
  const _RestoreConfirmDialog({this.manifest});

  @override
  State<_RestoreConfirmDialog> createState() => _RestoreConfirmDialogState();
}

class _RestoreConfirmDialogState extends State<_RestoreConfirmDialog> {
  RestoreMode _mode = RestoreMode.overwrite;

  @override
  Widget build(BuildContext context) {
    final manifest = widget.manifest;
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('确认恢复数据？'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (manifest != null) ...[
              Text('备份信息:', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              _infoRow('创建时间', manifest.createdAt.split('T').first),
              _infoRow('数据版本', 'v${manifest.schemaVersion}'),
              _infoRow('对话数', '${manifest.stats.topics}'),
              _infoRow('消息数', '${manifest.stats.messages}'),
              _infoRow('助手数', '${manifest.stats.assistants}'),
              const SizedBox(height: 16),
            ],
            Text('恢复模式:', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
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
                Icon(LucideIcons.shieldCheck,
                    size: 16, color: theme.colorScheme.secondary),
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ',
              style:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

// =============================================================================
// Shared UI Components
// =============================================================================

/// A rounded, bordered surface card matching the project's settings style.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
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

/// A section header with title and description.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.description});
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: theme.colorScheme.onSurface.withValues(alpha: 0.015),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 12.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// An action row: tinted icon + label/description + optional trailing.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.accent,
    required this.label,
    required this.description,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String description;
  final VoidCallback? onTap;
  final Widget? trailing;

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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 6),
                        trailing!,
                      ],
                    ],
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

/// A navigation row: same as action row but with a trailing chevron.
class _NavigationRow extends StatelessWidget {
  const _NavigationRow({
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
            const SizedBox(width: 8),
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// A "推荐" (recommended) chip shown next to the selective backup option.
class _RecommendedChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF9333EA);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        '推荐',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: accent,
        ),
      ),
    );
  }
}

/// A backup file row in the history section.
class _BackupFileRow extends StatelessWidget {
  final BackupFileItem item;
  final ThemeData theme;
  final VoidCallback onDelete;

  const _BackupFileRow({
    required this.item,
    required this.theme,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(
            item.isAuto ? LucideIcons.shieldCheck : LucideIcons.archive,
            size: 18,
            color: item.isAuto
                ? theme.colorScheme.secondary
                : theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${item.sizeDisplay} | ${_formatDate(item.lastModified)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2, size: 16),
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
