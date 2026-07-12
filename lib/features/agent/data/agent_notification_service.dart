import 'dart:io' show Platform;

import 'package:flutter/scheduler.dart' hide Priority;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 智能体审批系统通知（设计初稿 §6.3）：App 在后台时审批挂起弹高优通知，
/// 点击回到 App 并选中对应话题（审批卡就在事件流里）；审批被裁决/顶替时
/// 自动撤下通知。前台时不打扰——审批卡本来就内嵌在事件流。
class AgentNotificationService {
  factory AgentNotificationService() => _instance;
  AgentNotificationService._();
  static final AgentNotificationService _instance =
      AgentNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// 通知点击回调：payload 是 taskId，由 application 层接上「选中话题」。
  void Function(String taskId)? onSelectTask;

  static final bool _supported = Platform.isAndroid || Platform.isIOS;

  static const String _channelId = 'agent_approval';
  static const String _channelName = '智能体审批';
  static const String _channelDescription = '智能体任务等待授权时提醒';

  /// 每任务至多一条挂起审批 → 通知 id 从 taskId 稳定派生。
  static int _idFor(String taskId) => 0x4A00 | (taskId.hashCode & 0xFFFF);

  bool get _appInBackground =>
      SchedulerBinding.instance.lifecycleState != AppLifecycleState.resumed;

  Future<void> _ensureInit() async {
    if (_initialized || !_supported) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final taskId = response.payload;
        if (taskId != null && taskId.isNotEmpty) onSelectTask?.call(taskId);
      },
    );
    _initialized = true;
  }

  /// 审批挂起：App 在后台时弹通知（前台不弹，审批卡已内嵌事件流）。
  Future<void> showApprovalRequest({
    required String taskId,
    required String taskTitle,
    required String toolName,
  }) async {
    if (!_supported || !_appInBackground) return;
    await _ensureInit();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        showWhen: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );
    await _plugin.show(
      _idFor(taskId),
      '等待授权：$toolName',
      '「$taskTitle」在等你批准后继续',
      details,
      payload: taskId,
    );
  }

  /// 审批已裁决/被顶替：撤下该任务的通知。
  Future<void> cancelApprovalRequest(String taskId) async {
    if (!_supported || !_initialized) return;
    await _plugin.cancel(_idFor(taskId));
  }
}
