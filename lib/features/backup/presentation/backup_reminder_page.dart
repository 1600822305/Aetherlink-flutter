import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/backup/application/backup_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/widgets/app_select_field.dart';

/// Detail page for backup reminder settings.
class BackupReminderPage extends ConsumerStatefulWidget {
  const BackupReminderPage({super.key});

  @override
  ConsumerState<BackupReminderPage> createState() => _BackupReminderPageState();
}

class _BackupReminderPageState extends ConsumerState<BackupReminderPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(backupControllerProvider);
    final controller = ref.read(backupControllerProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const ModelSettingsAppBar(title: '备份提醒'),
      body: ListView(
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
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFF59E0B,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          LucideIcons.bell,
                          size: 16,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '定期提醒',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '定期提醒你进行备份，保护数据安全',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CustomSwitch(
                        value: state.reminderEnabled,
                        onChanged: (v) async {
                          if (v && state.reminderMinutesOfDay == null) {
                            await controller.saveReminderSchedule(
                              enabled: true,
                              intervalDays: state.reminderIntervalDays,
                              minutesOfDay: 10 * 60,
                            );
                          } else {
                            await controller.setReminderEnabled(v);
                          }
                        },
                      ),
                    ],
                  ),
                  if (state.reminderEnabled) ...[
                    const SizedBox(height: 14),
                    Divider(height: 1, color: theme.dividerColor),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildIntervalSelector(
                            controller,
                            state,
                            theme,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildTimeSelector(controller, state, theme),
                      ],
                    ),
                    if (state.lastBackupAt != null ||
                        state.nextReminderAt != null) ...[
                      const SizedBox(height: 12),
                      if (state.lastBackupAt != null)
                        _infoRow(
                          theme,
                          LucideIcons.clock,
                          '上次备份',
                          _formatDate(state.lastBackupAt),
                        ),
                      if (state.nextReminderAt != null)
                        _infoRow(
                          theme,
                          LucideIcons.calendarClock,
                          '下次提醒',
                          _formatDate(state.nextReminderAt),
                        ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntervalSelector(
    BackupController controller,
    BackupState state,
    ThemeData theme,
  ) {
    return AppSelectField<int>(
      label: '间隔',
      value: state.reminderIntervalDays,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      options: const [
        AppSelectOption(value: 1, label: '每天'),
        AppSelectOption(value: 3, label: '每 3 天'),
        AppSelectOption(value: 7, label: '每周'),
        AppSelectOption(value: 14, label: '每两周'),
        AppSelectOption(value: 30, label: '每月'),
      ],
      onChanged: (v) {
        controller.saveReminderSchedule(
          enabled: true,
          intervalDays: v,
          minutesOfDay: state.reminderMinutesOfDay ?? 10 * 60,
        );
      },
    );
  }

  Widget _buildTimeSelector(
    BackupController controller,
    BackupState state,
    ThemeData theme,
  ) {
    final minutes = state.reminderMinutesOfDay ?? 10 * 60;
    final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    return OutlinedButton.icon(
      icon: const Icon(LucideIcons.clock, size: 16),
      label: Text(time.format(context)),
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
    );
  }

  Widget _infoRow(ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
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

// =============================================================================
// Shared Widget
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
