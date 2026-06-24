import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/backup/application/backup_controller.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_config.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_file_item.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_manifest.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

/// Main page for backup & restore settings.
class BackupSettingsPage extends ConsumerStatefulWidget {
  const BackupSettingsPage({super.key});

  @override
  ConsumerState<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends ConsumerState<BackupSettingsPage> {
  // WebDAV controllers
  late final TextEditingController _urlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _pathController;
  // S3 controllers
  late final TextEditingController _s3EndpointController;
  late final TextEditingController _s3RegionController;
  late final TextEditingController _s3BucketController;
  late final TextEditingController _s3AccessKeyController;
  late final TextEditingController _s3SecretKeyController;
  late final TextEditingController _s3PrefixController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(backupControllerProvider);
    final config = state.webDavConfig;
    _urlController = TextEditingController(text: config.url);
    _usernameController = TextEditingController(text: config.username);
    _passwordController = TextEditingController(text: config.password);
    _pathController = TextEditingController(text: config.path);
    final s3 = state.s3Config;
    _s3EndpointController = TextEditingController(text: s3.endpoint);
    _s3RegionController = TextEditingController(text: s3.region);
    _s3BucketController = TextEditingController(text: s3.bucket);
    _s3AccessKeyController = TextEditingController(text: s3.accessKeyId);
    _s3SecretKeyController = TextEditingController(text: s3.secretAccessKey);
    _s3PrefixController = TextEditingController(text: s3.prefix);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _pathController.dispose();
    _s3EndpointController.dispose();
    _s3RegionController.dispose();
    _s3BucketController.dispose();
    _s3AccessKeyController.dispose();
    _s3SecretKeyController.dispose();
    _s3PrefixController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(backupControllerProvider);
    final controller = ref.read(backupControllerProvider.notifier);
    final theme = Theme.of(context);

    // Show snackbar on status changes.
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

    return Scaffold(
      appBar: const ModelSettingsAppBar(title: '备份与恢复'),
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
              _buildLocalBackupSection(controller, state, theme),
              const SizedBox(height: 16),
              _buildWebDavSection(controller, state, theme),
              const SizedBox(height: 16),
              _buildS3Section(controller, state, theme),
              const SizedBox(height: 16),
              _buildReminderSection(controller, state, theme),
              const SizedBox(height: 16),
              _buildLocalBackupListSection(state, controller, theme),
            ],
          ),
          if (state.status == BackupStatus.working)
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
  // Local backup section
  // ---------------------------------------------------------------------------

  Widget _buildLocalBackupSection(
    BackupController controller,
    BackupState state,
    ThemeData theme,
  ) {
    return ModelSettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '本地备份',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(LucideIcons.download, size: 18),
              label: const Text('创建备份'),
              onPressed: state.status == BackupStatus.working
                  ? null
                  : controller.createAndShareBackup,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(LucideIcons.upload, size: 18),
              label: const Text('从文件恢复'),
              onPressed: state.status == BackupStatus.working
                  ? null
                  : () => _pickAndRestore(controller),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndRestore(BackupController controller) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    // Peek at manifest for confirmation dialog.
    BackupManifest? manifest;
    try {
      manifest = await controller.pickAndPeekBackup();
    } catch (_) {}

    if (!mounted) return;

    // Show restore confirmation dialog.
    final mode = await _showRestoreDialog(manifest);
    if (mode == null) return;

    await controller.restoreFromLocal(path, mode);
  }

  Future<RestoreMode?> _showRestoreDialog(BackupManifest? manifest) {
    return showDialog<RestoreMode>(
      context: context,
      builder: (context) => _RestoreConfirmDialog(manifest: manifest),
    );
  }

  // ---------------------------------------------------------------------------
  // WebDAV section
  // ---------------------------------------------------------------------------

  Widget _buildWebDavSection(
    BackupController controller,
    BackupState state,
    ThemeData theme,
  ) {
    return ModelSettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WebDAV 云备份',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: '服务器地址',
              hintText: 'https://dav.example.com',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => _saveWebDavConfig(controller),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: '用户名',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => _saveWebDavConfig(controller),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: '密码',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            obscureText: true,
            onChanged: (_) => _saveWebDavConfig(controller),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pathController,
            decoration: const InputDecoration(
              labelText: '备份路径',
              hintText: 'aetherlink_backups',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => _saveWebDavConfig(controller),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(LucideIcons.wifi, size: 18),
                  label: const Text('测试连接'),
                  onPressed: state.status == BackupStatus.working
                      ? null
                      : controller.testWebDavConnection,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(LucideIcons.cloudUpload, size: 18),
                  label: const Text('备份'),
                  onPressed: state.status == BackupStatus.working ||
                          !state.webDavConfig.isConfigured
                      ? null
                      : controller.backupToWebDav,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(LucideIcons.cloudDownload, size: 18),
              label: const Text('从 WebDAV 恢复'),
              onPressed: state.status == BackupStatus.working ||
                      !state.webDavConfig.isConfigured
                  ? null
                  : () => _showRemoteFileList(controller),
            ),
          ),
        ],
      ),
    );
  }

  void _saveWebDavConfig(BackupController controller) {
    controller.updateWebDavConfig(WebDavConfig(
      url: _urlController.text,
      username: _usernameController.text,
      password: _passwordController.text,
      path: _pathController.text.isEmpty
          ? 'aetherlink_backups'
          : _pathController.text,
    ));
  }

  // ---------------------------------------------------------------------------
  // S3 section
  // ---------------------------------------------------------------------------

  Widget _buildS3Section(
    BackupController controller,
    BackupState state,
    ThemeData theme,
  ) {
    return ModelSettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'S3 云存储备份',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '支持 AWS S3、Cloudflare R2、MinIO 等兼容服务',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _s3EndpointController,
            decoration: const InputDecoration(
              labelText: 'Endpoint',
              hintText: 'https://s3.amazonaws.com',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => _saveS3Config(controller),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _s3RegionController,
                  decoration: const InputDecoration(
                    labelText: 'Region',
                    hintText: 'us-east-1',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => _saveS3Config(controller),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _s3BucketController,
                  decoration: const InputDecoration(
                    labelText: 'Bucket',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => _saveS3Config(controller),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _s3AccessKeyController,
            decoration: const InputDecoration(
              labelText: 'Access Key ID',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => _saveS3Config(controller),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _s3SecretKeyController,
            decoration: const InputDecoration(
              labelText: 'Secret Access Key',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            obscureText: true,
            onChanged: (_) => _saveS3Config(controller),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _s3PrefixController,
            decoration: const InputDecoration(
              labelText: '前缀/目录',
              hintText: 'aetherlink_backups',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => _saveS3Config(controller),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Path Style'),
            subtitle: const Text('自托管/MinIO 推荐开启'),
            value: state.s3Config.pathStyle,
            onChanged: (v) {
              controller.updateS3Config(state.s3Config.copyWith(pathStyle: v));
            },
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(LucideIcons.wifi, size: 18),
                  label: const Text('测试连接'),
                  onPressed: state.status == BackupStatus.working
                      ? null
                      : controller.testS3Connection,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(LucideIcons.cloudUpload, size: 18),
                  label: const Text('备份'),
                  onPressed: state.status == BackupStatus.working ||
                          !state.s3Config.isConfigured
                      ? null
                      : controller.backupToS3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(LucideIcons.cloudDownload, size: 18),
              label: const Text('从 S3 恢复'),
              onPressed: state.status == BackupStatus.working ||
                      !state.s3Config.isConfigured
                  ? null
                  : () => _showS3FileList(controller),
            ),
          ),
        ],
      ),
    );
  }

  void _saveS3Config(BackupController controller) {
    controller.updateS3Config(S3Config(
      endpoint: _s3EndpointController.text,
      region: _s3RegionController.text.isEmpty
          ? 'us-east-1'
          : _s3RegionController.text,
      bucket: _s3BucketController.text,
      accessKeyId: _s3AccessKeyController.text,
      secretAccessKey: _s3SecretKeyController.text,
      prefix: _s3PrefixController.text.isEmpty
          ? 'aetherlink_backups'
          : _s3PrefixController.text,
      pathStyle: ref.read(backupControllerProvider).s3Config.pathStyle,
    ));
  }

  Future<void> _showS3FileList(BackupController controller) async {
    await controller.loadS3Backups();
    if (!mounted) return;

    final state = ref.read(backupControllerProvider);
    if (state.s3Backups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('S3 没有备份文件')),
      );
      return;
    }

    final selected = await showModalBottomSheet<BackupFileItem>(
      context: context,
      builder: (context) => _RemoteFileListSheet(files: state.s3Backups),
    );
    if (selected == null || !mounted) return;

    final mode = await _showRestoreDialog(null);
    if (mode == null) return;

    await controller.restoreFromS3(selected, mode);
  }

  // ---------------------------------------------------------------------------
  // Reminder section
  // ---------------------------------------------------------------------------

  Widget _buildReminderSection(
    BackupController controller,
    BackupState state,
    ThemeData theme,
  ) {
    return ModelSettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '备份提醒',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '定期提醒你进行备份，保护数据安全',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('启用备份提醒'),
            value: state.reminderEnabled,
            onChanged: (v) async {
              if (v && state.reminderMinutesOfDay == null) {
                // Default to 10:00 if no time set.
                await controller.saveReminderSchedule(
                  enabled: true,
                  intervalDays: state.reminderIntervalDays,
                  minutesOfDay: 10 * 60,
                );
              } else {
                await controller.setReminderEnabled(v);
              }
            },
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          if (state.reminderEnabled) ...[
            const SizedBox(height: 12),
            _buildIntervalSelector(controller, state, theme),
            const SizedBox(height: 12),
            _buildTimeSelector(controller, state, theme),
            const SizedBox(height: 12),
            if (state.lastBackupAt != null)
              _reminderInfoRow(
                theme,
                '上次备份',
                _formatDate(state.lastBackupAt),
              ),
            if (state.nextReminderAt != null)
              _reminderInfoRow(
                theme,
                '下次提醒',
                _formatDate(state.nextReminderAt),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildIntervalSelector(
    BackupController controller,
    BackupState state,
    ThemeData theme,
  ) {
    return Row(
      children: [
        Text('间隔: ', style: theme.textTheme.bodyMedium),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<int>(
            value: state.reminderIntervalDays,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(value: 1, child: Text('每天')),
              DropdownMenuItem(value: 3, child: Text('每 3 天')),
              DropdownMenuItem(value: 7, child: Text('每周')),
              DropdownMenuItem(value: 14, child: Text('每两周')),
              DropdownMenuItem(value: 30, child: Text('每月')),
            ],
            onChanged: (v) {
              if (v == null) return;
              controller.saveReminderSchedule(
                enabled: true,
                intervalDays: v,
                minutesOfDay: state.reminderMinutesOfDay ?? 10 * 60,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSelector(
    BackupController controller,
    BackupState state,
    ThemeData theme,
  ) {
    final minutes = state.reminderMinutesOfDay ?? 10 * 60;
    final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    return Row(
      children: [
        Text('提醒时间: ', style: theme.textTheme.bodyMedium),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: time,
            );
            if (picked == null) return;
            final newMinutes = picked.hour * 60 + picked.minute;
            await controller.saveReminderSchedule(
              enabled: true,
              intervalDays: state.reminderIntervalDays,
              minutesOfDay: newMinutes,
            );
          },
          child: Text(time.format(context)),
        ),
      ],
    );
  }

  Widget _reminderInfoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: theme.textTheme.bodySmall),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRemoteFileList(BackupController controller) async {
    await controller.loadRemoteBackups();
    if (!mounted) return;

    final state = ref.read(backupControllerProvider);
    if (state.remoteBackups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('远程没有备份文件')),
      );
      return;
    }

    final selected = await showModalBottomSheet<BackupFileItem>(
      context: context,
      builder: (context) => _RemoteFileListSheet(files: state.remoteBackups),
    );
    if (selected == null || !mounted) return;

    final mode = await _showRestoreDialog(null);
    if (mode == null) return;

    await controller.restoreFromWebDav(selected, mode);
  }

  // ---------------------------------------------------------------------------
  // Local backup history section
  // ---------------------------------------------------------------------------

  Widget _buildLocalBackupListSection(
    BackupState state,
    BackupController controller,
    ThemeData theme,
  ) {
    if (state.localBackups.isEmpty) return const SizedBox.shrink();

    return ModelSettingsCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '本地备份历史',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...state.localBackups.map((item) => ListTile(
                dense: true,
                leading: Icon(
                  item.isAuto ? LucideIcons.shieldCheck : LucideIcons.archive,
                  size: 20,
                  color: item.isAuto
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.primary,
                ),
                title: Text(
                  item.displayName,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${item.sizeDisplay} | ${_formatDate(item.lastModified)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(LucideIcons.trash2, size: 18),
                  onPressed: () =>
                      controller.deleteLocalBackup(item.displayName),
                ),
              )),
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

// ---------------------------------------------------------------------------
// Restore confirmation dialog
// ---------------------------------------------------------------------------

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
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Remote file list bottom sheet
// ---------------------------------------------------------------------------

class _RemoteFileListSheet extends StatelessWidget {
  final List<BackupFileItem> files;
  const _RemoteFileListSheet({required this.files});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '选择要恢复的备份',
              style: theme.textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: files.length,
              itemBuilder: (context, index) {
                final item = files[index];
                return ListTile(
                  leading:
                      const Icon(LucideIcons.fileArchive, size: 20),
                  title: Text(
                    item.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${item.sizeDisplay} | ${_formatDate(item.lastModified)}',
                  ),
                  onTap: () => Navigator.pop(context, item),
                );
              },
            ),
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
