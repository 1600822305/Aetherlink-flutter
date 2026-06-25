import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/backup/application/backup_controller.dart';
import 'package:aetherlink_flutter/features/backup/data/webdav_auto_sync_service.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_config.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_file_item.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

/// Detail page for cloud backup (WebDAV + S3) with top tab navigation.
class CloudBackupPage extends ConsumerStatefulWidget {
  const CloudBackupPage({super.key});

  @override
  ConsumerState<CloudBackupPage> createState() => _CloudBackupPageState();
}

class _CloudBackupPageState extends ConsumerState<CloudBackupPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  late final TextEditingController _urlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _pathController;
  late final TextEditingController _s3EndpointController;
  late final TextEditingController _s3RegionController;
  late final TextEditingController _s3BucketController;
  late final TextEditingController _s3AccessKeyController;
  late final TextEditingController _s3SecretKeyController;
  late final TextEditingController _s3PrefixController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });

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
    _tabController.dispose();
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
      appBar: const ModelSettingsAppBar(title: '云备份'),
      body: Stack(
        children: [
          Column(
            children: [
              // Pill segmented control — same style as 语音功能 / MCP 服务器
              // settings: rounded grey track + white card indicator (1px shadow).
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: theme.colorScheme.onSurface,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(
                      height: 32,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.server, size: 15),
                          SizedBox(width: 5),
                          Text('WebDAV'),
                        ],
                      ),
                    ),
                    Tab(
                      height: 32,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.cloud, size: 15),
                          SizedBox(width: 5),
                          Text('S3'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildWebDavTab(controller, state, theme),
                    _buildS3Tab(controller, state, theme),
                  ],
                ),
              ),
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
  // WebDAV Tab
  // ---------------------------------------------------------------------------

  Widget _buildWebDavTab(
    BackupController controller,
    BackupState state,
    ThemeData theme,
  ) {
    final isWorking = state.status == BackupStatus.working;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        _Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '服务器配置',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: '服务器地址',
                    hintText: 'https://dav.example.com',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: (_) => _saveWebDavConfig(controller),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: '用户名',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
                        onChanged: (_) => _saveWebDavConfig(controller),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: '密码',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
                        obscureText: true,
                        onChanged: (_) => _saveWebDavConfig(controller),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _pathController,
                  decoration: const InputDecoration(
                    labelText: '备份路径',
                    hintText: 'aetherlink_backups',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: (_) => _saveWebDavConfig(controller),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            children: [
              _ActionRow(
                icon: LucideIcons.wifi,
                accent: const Color(0xFF0EA5E9),
                label: '测试连接',
                description: '验证 WebDAV 服务器配置是否正确',
                onTap: isWorking ? null : controller.testWebDavConnection,
              ),
              Divider(height: 1, color: theme.dividerColor),
              _ActionRow(
                icon: LucideIcons.cloudUpload,
                accent: const Color(0xFF2563EB),
                label: '备份到 WebDAV',
                description: '将数据上传到 WebDAV 服务器',
                onTap: isWorking || !state.webDavConfig.isConfigured
                    ? null
                    : controller.backupToWebDav,
              ),
              Divider(height: 1, color: theme.dividerColor),
              _ActionRow(
                icon: LucideIcons.cloudDownload,
                accent: const Color(0xFF059669),
                label: '从 WebDAV 恢复',
                description: '从远程备份文件恢复数据',
                onTap: isWorking || !state.webDavConfig.isConfigured
                    ? null
                    : () => _showRemoteFileList(controller),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildAutoSyncSection(controller, state, theme),
      ],
    );
  }

  Widget _buildAutoSyncSection(
    BackupController controller,
    BackupState state,
    ThemeData theme,
  ) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    LucideIcons.refreshCw,
                    size: 16,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '自动同步',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                CustomSwitch(
                  value: state.autoSyncEnabled,
                  onChanged: !state.webDavConfig.isConfigured
                      ? null
                      : (v) {
                          controller.saveAutoSyncSettings(
                            enabled: v,
                            intervalMinutes: state.autoSyncIntervalMinutes,
                            maxBackups: state.autoSyncMaxBackups,
                          );
                        },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '定期自动备份到 WebDAV 服务器',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (state.autoSyncEnabled) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '同步间隔',
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                    ),
                  ),
                  DropdownButton<int>(
                    value:
                        kAutoSyncIntervalOptions.contains(
                          state.autoSyncIntervalMinutes,
                        )
                        ? state.autoSyncIntervalMinutes
                        : kAutoSyncIntervalOptions.first,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                    items: kAutoSyncIntervalOptions
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(_intervalLabel(m)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      controller.saveAutoSyncSettings(
                        enabled: state.autoSyncEnabled,
                        intervalMinutes: v,
                        maxBackups: state.autoSyncMaxBackups,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '保留备份数',
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                    ),
                  ),
                  DropdownButton<int>(
                    value: state.autoSyncMaxBackups.clamp(1, 20),
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                    items: [3, 5, 10, 15, 20]
                        .map(
                          (n) =>
                              DropdownMenuItem(value: n, child: Text('$n 个')),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      controller.saveAutoSyncSettings(
                        enabled: state.autoSyncEnabled,
                        intervalMinutes: state.autoSyncIntervalMinutes,
                        maxBackups: v,
                      );
                    },
                  ),
                ],
              ),
              if (state.lastAutoSyncAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  '上次同步: ${_formatDateTime(state.lastAutoSyncAt!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: state.status == BackupStatus.working
                      ? null
                      : controller.triggerAutoSyncNow,
                  icon: const Icon(LucideIcons.upload, size: 14),
                  label: const Text('立即同步'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _intervalLabel(int minutes) {
    if (minutes < 60) return '$minutes 分钟';
    if (minutes < 1440) return '${minutes ~/ 60} 小时';
    return '${minutes ~/ 1440} 天';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // S3 Tab
  // ---------------------------------------------------------------------------

  Widget _buildS3Tab(
    BackupController controller,
    BackupState state,
    ThemeData theme,
  ) {
    final isWorking = state.status == BackupStatus.working;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        _Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '存储配置',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '支持 AWS S3、R2、MinIO',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _s3EndpointController,
                  decoration: const InputDecoration(
                    labelText: 'Endpoint',
                    hintText: 'https://s3.amazonaws.com',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: (_) => _saveS3Config(controller),
                ),
                const SizedBox(height: 10),
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
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
                        onChanged: (_) => _saveS3Config(controller),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _s3BucketController,
                        decoration: const InputDecoration(
                          labelText: 'Bucket',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
                        onChanged: (_) => _saveS3Config(controller),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _s3AccessKeyController,
                        decoration: const InputDecoration(
                          labelText: 'Access Key ID',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
                        onChanged: (_) => _saveS3Config(controller),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _s3SecretKeyController,
                        decoration: const InputDecoration(
                          labelText: 'Secret Key',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
                        obscureText: true,
                        onChanged: (_) => _saveS3Config(controller),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _s3PrefixController,
                  decoration: const InputDecoration(
                    labelText: '前缀/目录',
                    hintText: 'aetherlink_backups',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: (_) => _saveS3Config(controller),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Path Style',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      '自托管/MinIO 推荐开启',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    CustomSwitch(
                      value: state.s3Config.pathStyle,
                      onChanged: (v) {
                        controller.updateS3Config(
                          state.s3Config.copyWith(pathStyle: v),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            children: [
              _ActionRow(
                icon: LucideIcons.wifi,
                accent: const Color(0xFF0EA5E9),
                label: '测试连接',
                description: '验证 S3 存储配置是否正确',
                onTap: isWorking ? null : controller.testS3Connection,
              ),
              Divider(height: 1, color: theme.dividerColor),
              _ActionRow(
                icon: LucideIcons.cloudUpload,
                accent: const Color(0xFF2563EB),
                label: '备份到 S3',
                description: '将数据上传到 S3 存储',
                onTap: isWorking || !state.s3Config.isConfigured
                    ? null
                    : controller.backupToS3,
              ),
              Divider(height: 1, color: theme.dividerColor),
              _ActionRow(
                icon: LucideIcons.cloudDownload,
                accent: const Color(0xFF059669),
                label: '从 S3 恢复',
                description: '从远程备份文件恢复数据',
                onTap: isWorking || !state.s3Config.isConfigured
                    ? null
                    : () => _showS3FileList(controller),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Config helpers
  // ---------------------------------------------------------------------------

  void _saveWebDavConfig(BackupController controller) {
    controller.updateWebDavConfig(
      WebDavConfig(
        url: _urlController.text,
        username: _usernameController.text,
        password: _passwordController.text,
        path: _pathController.text.isEmpty
            ? 'aetherlink_backups'
            : _pathController.text,
      ),
    );
  }

  void _saveS3Config(BackupController controller) {
    controller.updateS3Config(
      S3Config(
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
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Remote file selection
  // ---------------------------------------------------------------------------

  Future<void> _showRemoteFileList(BackupController controller) async {
    await controller.loadRemoteBackups();
    if (!mounted) return;

    final state = ref.read(backupControllerProvider);
    if (state.remoteBackups.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('远程没有备份文件')));
      return;
    }

    final selected = await showModalBottomSheet<BackupFileItem>(
      context: context,
      builder: (context) => _RemoteFileListSheet(files: state.remoteBackups),
    );
    if (selected == null || !mounted) return;

    final mode = await _showRestoreDialog();
    if (mode == null) return;

    await controller.restoreFromWebDav(selected, mode);
  }

  Future<void> _showS3FileList(BackupController controller) async {
    await controller.loadS3Backups();
    if (!mounted) return;

    final state = ref.read(backupControllerProvider);
    if (state.s3Backups.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('S3 没有备份文件')));
      return;
    }

    final selected = await showModalBottomSheet<BackupFileItem>(
      context: context,
      builder: (context) => _RemoteFileListSheet(files: state.s3Backups),
    );
    if (selected == null || !mounted) return;

    final mode = await _showRestoreDialog();
    if (mode == null) return;

    await controller.restoreFromS3(selected, mode);
  }

  Future<RestoreMode?> _showRestoreDialog() {
    return showDialog<RestoreMode>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择恢复模式'),
        content: const Text('覆盖模式会清除现有数据再恢复；\n合并模式会保留现有数据，仅添加新数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, RestoreMode.merge),
            child: const Text('合并'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, RestoreMode.overwrite),
            child: const Text('覆盖'),
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
            child: Text('选择要恢复的备份', style: theme.textTheme.titleMedium),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: files.length,
              itemBuilder: (context, index) {
                final item = files[index];
                return ListTile(
                  leading: const Icon(LucideIcons.fileArchive, size: 20),
                  title: Text(
                    item.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${item.sizeDisplay} | ${_formatDate(item.lastModified)}',
                  ),
                  dense: true,
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
