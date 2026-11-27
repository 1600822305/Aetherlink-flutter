import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/settings/application/llm_auto_retry_controller.dart';
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
        padding: EdgeInsets.fromLTRB(
          12,
          12,
          12,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          if (!_coordinator.supported)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
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
                  description: '切后台或锁屏时，聊天与智能体任务不中断',
                  value: settings.androidEnabled,
                  onChanged: controller.setEnabled,
                ),
                Divider(height: 1, color: theme.dividerColor),
                _SwitchRow(
                  label: '完成通知',
                  description: '后台任务结束时通知，点击回到会话',
                  value: settings.notificationsEnabled,
                  onChanged: controller.setNotificationsEnabled,
                ),
                Divider(height: 1, color: theme.dividerColor),
                _SwitchRow(
                  label: '隐私模式',
                  description: '通知与悬浮窗不显示标题和进度',
                  value: settings.privacyMode,
                  onChanged: controller.setPrivacyMode,
                ),
                Divider(height: 1, color: theme.dividerColor),
                _SwitchRow(
                  label: '后台悬浮窗',
                  description: '在其他应用上方显示任务进度',
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
                    description: 'Android 16 起在状态栏显示实时进度',
                    value: settings.liveUpdatesEnabled,
                    onChanged: controller.setLiveUpdatesEnabled,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          ModelSettingsCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SwitchRow(
                  label: '聊天请求失败自动重试',
                  description: '网络断开或服务繁忙时自动重试',
                  value: ref.watch(chatLlmAutoRetryProvider),
                  onChanged: ref.read(chatLlmAutoRetryProvider.notifier).set,
                  info: _kAutoRetryInfo,
                ),
                Divider(height: 1, color: theme.dividerColor),
                _SwitchRow(
                  label: '终端后台保持运行',
                  description: '锁屏后终端命令继续执行，更耗电',
                  value: settings.terminalKeepAlive,
                  onChanged: controller.setTerminalKeepAlive,
                  info: _kTerminalKeepAliveInfo,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
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
    this.info,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// 功能说明：非空时标题旁显示 ⓘ，点击弹出说明。
  final _FeatureInfo? info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
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
                        ),
                      ),
                    ),
                    if (info != null)
                      InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _showFeatureInfo(context, label, info!),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
                          child: Icon(
                            Icons.info_outline,
                            size: 15,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    height: 1.3,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          CustomSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// 功能说明：分段的标题 + 正文。
class _FeatureInfo {
  const _FeatureInfo(this.sections);

  final List<(String, String)> sections;
}

Future<void> _showFeatureInfo(
  BuildContext context,
  String title,
  _FeatureInfo info,
) {
  final theme = Theme.of(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, (heading, body)) in info.sections.indexed) ...[
              if (i > 0) const SizedBox(height: 12),
              Text(
                heading,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

const _kAutoRetryInfo = _FeatureInfo([
  (
    '作用',
    '普通聊天请求失败时，在还没收到任何回复内容前自动重新请求，'
        '最多重试 3 次，间隔约 1 秒、2 秒、4 秒。等待期间消息里会显示'
        '「网络中断，N 秒后重试（1/3）」，可随时停止。',
  ),
  (
    '会重试的情况',
    '网络断开、连接被重置、请求超时；服务器返回 408、425、429、500、502、'
        '503、504、529；错误信息含「繁忙」「限流」「稍后」等。',
  ),
  (
    '不会重试的情况',
    '已经开始输出回复后的错误（避免重复内容）；余额不足、额度用尽、'
        'Key 无效、无权限等；你手动停止。',
  ),
  ('智能体', '智能体任务始终自动重试，不受这个开关影响。'),
]);

const _kTerminalKeepAliveInfo = _FeatureInfo([
  (
    '作用',
    '切到后台或锁屏后，终端里正在跑的命令继续执行，不会因为手机休眠而暂停，'
        '适合 npm install、编译这类长命令。',
  ),
  (
    '什么时候生效',
    '终端页有已连接的会话，或 AI 正在终端里执行命令时生效；都没有时自动'
        '撤销，不占用资源。有智能体任务在跑时，任务本身已经保活，开不开都一样。',
  ),
  (
    '耗电',
    '生效期间会保持 CPU 唤醒，比关闭时更耗电。终端页开着会话但不用时也会'
        '保持唤醒，不用时建议关闭终端会话。',
  ),
  (
    '通知',
    '生效时只显示一条「终端运行中」常驻通知；点通知里的「停止」可临时取消'
        '本次保活（不会结束终端会话）。',
  ),
  (
    '前提',
    '需要先开启「后台继续执行」；锁屏后网络是否可用还取决于是否允许'
        '「不受电池优化限制」。',
  ),
]);

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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
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
      visualDensity: const VisualDensity(vertical: -2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
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
