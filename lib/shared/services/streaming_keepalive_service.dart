import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// 平台操作缝（可注入）：真实实现走 flutter_foreground_task，
/// 测试注入假实现验证启动失败重试/回前台补启的编排逻辑。
abstract class KeepAlivePlatformOps {
  Future<bool> isRunningService();
  Future<bool> ensureNotificationPermission();
  Future<bool> startService({required String title, required String text});
  Future<void> stopService();
}

class _ForegroundTaskOps implements KeepAlivePlatformOps {
  static const String _channelId = 'aetherlink_streaming';
  static const int _serviceId = 451;

  bool _initialized = false;

  void _ensureInit() {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: '正在生成回复',
        channelDescription: '在后台保持 AI 回复生成不被系统中断',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _initialized = true;
  }

  @override
  Future<bool> isRunningService() {
    _ensureInit();
    return FlutterForegroundTask.isRunningService;
  }

  @override
  Future<bool> ensureNotificationPermission() async {
    _ensureInit();
    var permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      permission = await FlutterForegroundTask.requestNotificationPermission();
    }
    return permission == NotificationPermission.granted;
  }

  @override
  Future<bool> startService({
    required String title,
    required String text,
  }) async {
    _ensureInit();
    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: [ForegroundServiceTypes.dataSync],
      notificationTitle: title,
      notificationText: text,
    );
    if (result is ServiceRequestFailure) {
      debugPrint('StreamingKeepAliveService: 前台服务启动失败 ${result.error}');
      return false;
    }
    return true;
  }

  @override
  Future<void> stopService() => FlutterForegroundTask.stopService();
}

/// Keeps the app process alive while an LLM reply is streaming so that switching
/// the app to the background doesn't let Android suspend the process / cut the
/// network mid-generation (the conversation keeps going in the background).
///
/// Backed by an Android foreground service with an ongoing notification. On iOS
/// this is best-effort — the OS only grants a short background grace period and
/// will suspend the app afterwards, which no app-level code can override.
///
/// 服务启动可能失败（通知权限未授予、系统前台服务限制、被 OEM 杀掉等），
/// 失败不再静默吞掉：持有方还在时，App 回到前台即重试补启，保证下次
/// 切后台前保活已就位。
class StreamingKeepAliveService {
  StreamingKeepAliveService._();

  /// 持有方 → 通知文案（chat 流式 / agent 任务共用同一个前台服务）：
  /// 全部释放才真正停服务，防一方结束把另一方的保活拆掉。
  static final Map<String, ({String title, String text})> _holders = {};

  static KeepAlivePlatformOps _ops = _ForegroundTaskOps();
  static AppLifecycleListener? _lifecycleListener;
  static Future<void>? _inflight;

  static bool get _supported =>
      debugSupportedOverride ?? (Platform.isAndroid || Platform.isIOS);

  @visibleForTesting
  static bool? debugSupportedOverride;

  @visibleForTesting
  static set debugOps(KeepAlivePlatformOps ops) => _ops = ops;

  @visibleForTesting
  static void debugReset() {
    _holders.clear();
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    _inflight = null;
    _ops = _ForegroundTaskOps();
    debugSupportedOverride = null;
  }

  /// Start keeping the process alive. No-op when not running on a mobile
  /// platform or when the service is already running.
  static Future<void> begin() =>
      acquire('chat', title: '正在生成回复…', text: 'AetherLink 正在后台继续生成 AI 回复');

  /// Stop keeping the process alive. No-op when nothing is running.
  static Future<void> end() => release('chat');

  /// [holder] 声明需要保活；服务未跑时以给定通知文案启动，已跑则只记数
  /// （先到者的文案保留）。
  static Future<void> acquire(
    String holder, {
    required String title,
    required String text,
  }) async {
    if (!_supported) return;
    _holders[holder] = (title: title, text: text);
    _lifecycleListener ??= AppLifecycleListener(
      onResume: () => unawaited(ensureService()),
    );
    await ensureService();
  }

  /// [holder] 释放保活；所有持有方都释放后才停服务。
  static Future<void> release(String holder) async {
    if (!_supported) return;
    _holders.remove(holder);
    if (_holders.isNotEmpty) return;
    if (!await _ops.isRunningService()) return;
    await _ops.stopService();
  }

  /// 持有方还在但服务没跑（启动失败 / 中途被系统停掉）时补启。
  /// 幂等且串行：并发调用共享同一次尝试。
  @visibleForTesting
  static Future<void> ensureService() {
    final inflight = _inflight;
    if (inflight != null) return inflight;
    final attempt = _ensureServiceOnce().whenComplete(() => _inflight = null);
    _inflight = attempt;
    return attempt;
  }

  static Future<void> _ensureServiceOnce() async {
    if (_holders.isEmpty) return;
    try {
      if (await _ops.isRunningService()) return;
      await _ops.ensureNotificationPermission();
      final spec = _holders.values.first;
      await _ops.startService(title: spec.title, text: spec.text);
    } catch (e) {
      debugPrint('StreamingKeepAliveService: 保活服务启动异常 $e');
    }
  }
}
