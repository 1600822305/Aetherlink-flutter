import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/settings/application/mobile_background_settings_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/mobile_background_settings.dart';
import 'package:aetherlink_flutter/shared/services/mobile_background.dart';

/// 后台执行设置（基本设置 → 后台执行）：前台服务 + WakeLock 开关、完成通知、
/// 悬浮窗与系统权限入口。权限只在点击对应按钮时申请。
class BackgroundExecutionSettingsPage extends ConsumerStatefulWidget {
  const BackgroundExecutionSettingsPage({super.key});

  @override
  ConsumerState<BackgroundExecutionSettingsPage> createState() =>
      _BackgroundExecutionSettingsPageState();
}

class _BackgroundExecutionSettingsPageState
    extends ConsumerState<BackgroundExecutionSettingsPage> {
  final _coordinator = MobileBackgroundCoordinator.instance;

  @override
  void initState() {
    super.initState();
    _coordinator.addListener(_onStatus);
    unawaited(_coordinator.refreshStatus());
  }

  @override
  void dispose() {
    _coordinator.removeListener(_onStatus);
    super.dispose();
  }

  void _onStatus() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(mobileBackgroundSettingsControllerProvider);
    final controller = ref.read(
      mobileBackgroundSettingsControllerProvider.notifier,
    );
    final status = _coordinator.status;
    final lastError = status.text('lastError');

    return Scaffold(
      appBar: ModelSettingsAppBar(
        title: '后台执行',
        onBack: () => context.canPop()
            ? context.pop()
            : context.go(AppRouter.settingsPath),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_coordinator.supported)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                '后台执行仅支持 Android。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ModelSettingsCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SwitchRow(
                  label: '后台继续执行',
                  description: '聊天生成或智能体任务运行时启动前台服务并保持 CPU 唤醒，'
                      '切后台/息屏也不中断',
                  value: settings.androidEnabled,
                  onChanged: controller.setEnabled,
                ),
                Divider(height: 1, color: theme.dividerColor),
                _SwitchRow(
                  label: '完成通知',
                  description: 'App 在后台时任务结束弹通知，点击回到对应会话',
                  value: settings.notificationsEnabled,
                  onChanged: controller.setNotificationsEnabled,
                ),
                Divider(height: 1, color: theme.dividerColor),
                _SwitchRow(
                  label: '隐私模式',
                  description: '通知与悬浮窗不显示会话标题和进度详情',
                  value: settings.privacyMode,
                  onChanged: controller.setPrivacyMode,
                ),
                Divider(height: 1, color: theme.dividerColor),
                _SwitchRow(
                  label: '后台悬浮窗',
                  description: '在其他应用上方显示任务进度，可拖动，点击回到会话，长按关闭',
                  value: settings.overlayEnabled,
                  onChanged: controller.setOverlayEnabled,
                ),
                if (settings.overlayEnabled) ...[
                  Divider(height: 1, color: theme.dividerColor),
                  _SwitchRow(
                    label: '圆形悬浮球',
                    description: '只显示图标与进度环',
                    value:
                        settings.overlayAppearance.isIconOnly &&
                        !settings.overlayAppearance.showBackground,
                    onChanged: (v) => controller.setOverlayAppearance(
                      v
                          ? BackgroundOverlayAppearance.circle
                          : const BackgroundOverlayAppearance(),
                    ),
                  ),
                  Divider(height: 1, color: theme.dividerColor),
                  _VisibilityRow(
                    value: settings.completionVisibility,
                    onChanged: controller.setCompletionVisibility,
                  ),
                ],
                if (status.flag('liveUpdatesSupported')) ...[
                  Divider(height: 1, color: theme.dividerColor),
                  _SwitchRow(
                    label: '实时更新通知',
                    description: 'Android 16 起在状态栏以实时活动样式展示进度',
                    value: settings.liveUpdatesEnabled,
                    onChanged: controller.setLiveUpdatesEnabled,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          ModelSettingsCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _PermissionRow(
                  label: '通知权限',
                  granted: status.flag('notificationsAuthorized'),
                  onTap: () => _coordinator.requestPermission('notifications'),
                ),
                Divider(height: 1, color: theme.dividerColor),
                _PermissionRow(
                  label: '忽略电池优化',
                  granted: status.flag('batteryExempt'),
                  onTap: () => _coordinator.requestPermission('battery'),
                ),
                Divider(height: 1, color: theme.dividerColor),
                _PermissionRow(
                  label: '悬浮窗权限',
                  granted: status.flag('overlayAuthorized'),
                  onTap: () => _coordinator.requestPermission('overlay'),
                ),
                Divider(height: 1, color: theme.dividerColor),
                _PermissionRow(
                  label: '自启动 / 后台运行（厂商设置）',
                  onTap: () => _coordinator.openSettings('autostart'),
                ),
              ],
            ),
          ),
          if (lastError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '最近错误：$lastError',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
          const SizedBox(width: 12),
          CustomSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _VisibilityRow extends StatelessWidget {
  const _VisibilityRow({required this.value, required this.onChanged});

  final BackgroundCompletionVisibility value;
  final ValueChanged<BackgroundCompletionVisibility> onChanged;

  static String _label(BackgroundCompletionVisibility v) => switch (v) {
    BackgroundCompletionVisibility.immediate => '立即隐藏',
    BackgroundCompletionVisibility.oneMinute => '1 分钟',
    BackgroundCompletionVisibility.fiveMinutes => '5 分钟',
    BackgroundCompletionVisibility.untilForeground => '直到回到 App',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '完成后悬浮窗保留',
              style: theme.textTheme.titleSmall?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          DropdownButton<BackgroundCompletionVisibility>(
            value: value,
            underline: const SizedBox.shrink(),
            items: [
              for (final v in BackgroundCompletionVisibility.values)
                DropdownMenuItem(value: v, child: Text(_label(v))),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.label,
    required this.onTap,
    this.granted,
  });

  final String label;
  final VoidCallback onTap;
  final bool? granted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = granted;
    return ListTile(
      dense: true,
      title: Text(label, style: theme.textTheme.bodyMedium),
      trailing: Text(
        state == null
            ? '去设置'
            : state
            ? '已授权'
            : '去授权',
        style: theme.textTheme.bodySmall?.copyWith(
          color: state == true
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.primary,
        ),
      ),
      onTap: onTap,
    );
  }
}
