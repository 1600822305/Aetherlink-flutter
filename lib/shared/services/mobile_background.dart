import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:aetherlink_flutter/shared/domain/mobile_background_settings.dart';

enum BackgroundTaskPhase {
  requesting,
  generating,
  thinking,
  tool,
  waitingApproval,
  compacting,
}

enum BackgroundTaskOutcome { completed, failed, cancelled, interrupted }

class MobileBackgroundStatus {
  const MobileBackgroundStatus([this.values = const {}]);

  final Map<String, dynamic> values;
  bool flag(String key) => values[key] == true;
  String text(String key) => values[key]?.toString() ?? '';
}

class _BackgroundTask {
  _BackgroundTask({
    required this.id,
    required this.conversationId,
    required this.title,
    required this.cancel,
    required this.startedAt,
  });

  final String id;
  final String conversationId;
  final String title;
  final Future<void> Function() cancel;
  final DateTime startedAt;
  BackgroundTaskPhase phase = BackgroundTaskPhase.requesting;
  String toolName = '';
  int tokens = 0;
  bool interrupted = false;
}

/// Dart half of the Android background runtime (port of kelivo's
/// `MobileBackgroundCoordinator`). Chat streams and agent tasks register here;
/// native code receives whole snapshots on one serial channel and runs the
/// WakeLock-holding foreground service only while a task is active. A late
/// update/finish cannot resurrect a removed run.
class MobileBackgroundCoordinator extends ChangeNotifier
    with WidgetsBindingObserver {
  MobileBackgroundCoordinator({
    TargetPlatform? platform,
    MethodChannel? channel,
  }) : platform = platform ?? defaultTargetPlatform,
       _hostSupported = platform != null || (!kIsWeb && Platform.isAndroid),
       _channel = channel ?? const MethodChannel('aetherlink/mobile_background');

  static final instance = MobileBackgroundCoordinator();
  final TargetPlatform platform;
  // Host-side unit tests report android as defaultTargetPlatform; only a real
  // Android process (or an explicit test platform) reaches the channel.
  final bool _hostSupported;
  final MethodChannel _channel;
  final Map<String, _BackgroundTask> _tasks = {};
  MobileBackgroundSettings _settings = const MobileBackgroundSettings();
  MobileBackgroundSettings get settings => _settings;
  MobileBackgroundStatus status = const MobileBackgroundStatus();
  String? lastError;
  int? _overlayProgressColor;
  bool _initialized = false;
  bool _foreground = true;
  bool get isForeground => _foreground;
  bool get supported =>
      _hostSupported && !kIsWeb && platform == TargetPlatform.android;

  /// Receives the conversation id of a tapped notification / overlay. Wired by
  /// the app shell, which owns routing.
  void Function(String conversationId)? openConversation;
  String? _pendingConversation;
  Future<void>? _tail;
  Timer? _updateTimer;
  int _revision = 0;

  @visibleForTesting
  Set<String> get activeTaskIds => Set.unmodifiable(_tasks.keys);

  bool isActive(String id) => _tasks.containsKey(id);

  Future<void> initialize() async {
    if (!supported || _initialized) return;
    _initialized = true;
    _foreground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler(_handleNativeCall);
    await _enqueue(() async {
      final pending = await _channel.invokeMethod<String>(
        'takePendingConversation',
      );
      if (pending != null) _open(pending);
    });
  }

  void setConversationOpener(void Function(String conversationId) opener) {
    openConversation = opener;
    final pending = _pendingConversation;
    _pendingConversation = null;
    if (pending != null) opener(pending);
  }

  void _open(String id) {
    final opener = openConversation;
    if (opener == null) {
      _pendingConversation = id;
    } else {
      opener(id);
    }
  }

  Future<void> configure(
    MobileBackgroundSettings settings, {
    Color? overlayProgressColor,
  }) async {
    // Settings-only updates retain the latest resolved Flutter theme color.
    final progressColor =
        overlayProgressColor?.toARGB32() ?? _overlayProgressColor;
    final changed =
        jsonEncode(_settings.toJson()) != jsonEncode(settings.toJson()) ||
        _overlayProgressColor != progressColor;
    _settings = settings;
    _overlayProgressColor = progressColor;
    await initialize();
    if (changed) await _sync();
  }

  Future<void> start({
    required String id,
    required String conversationId,
    required String title,
    required Future<void> Function() cancel,
  }) async {
    if (!supported || _tasks.containsKey(id)) return;
    _tasks[id] = _BackgroundTask(
      id: id,
      conversationId: conversationId,
      title: title,
      cancel: cancel,
      startedAt: DateTime.now(),
    );
    await initialize();
    await _sync();
  }

  void update(
    String id, {
    required BackgroundTaskPhase phase,
    int? tokens,
    String toolName = '',
  }) {
    final task = _tasks[id];
    if (task == null) return;
    if (task.phase == phase &&
        task.toolName == toolName &&
        (tokens == null || tokens == task.tokens)) {
      return;
    }
    task.phase = phase;
    task.toolName = toolName;
    if (tokens != null) task.tokens = tokens;
    _updateTimer ??= Timer(const Duration(milliseconds: 500), () {
      _updateTimer = null;
      unawaited(_sync());
    });
  }

  Future<void> finish(String id, BackgroundTaskOutcome outcome) async {
    final task = _tasks.remove(id);
    if (task == null) return;
    if (task.interrupted) outcome = BackgroundTaskOutcome.interrupted;
    _cancelUpdateTimer();
    final snapshot = _snapshot(
      terminal: {
        ..._taskMap(task),
        'outcome': outcome.name,
        'detail': _outcomeText(outcome),
        'finishedAt': DateTime.now().millisecondsSinceEpoch,
      },
    );
    await _enqueue(() async {
      if (_settings.notificationsEnabled &&
          outcome != BackgroundTaskOutcome.cancelled &&
          !_foreground) {
        try {
          await _channel.invokeMethod<void>('notifyCompleted', {
            'conversationId': task.conversationId,
            'title': _settings.privacyMode || task.title.trim().isEmpty
                ? _kAppName
                : task.title,
            'body': _outcomeText(outcome),
          });
        } catch (error) {
          _recordError(error);
        }
      }
      await _sendSnapshot(snapshot);
    });
  }

  static const String _kAppName = 'AetherLink';

  String _outcomeText(BackgroundTaskOutcome outcome) => switch (outcome) {
    BackgroundTaskOutcome.completed => '任务已完成',
    BackgroundTaskOutcome.failed => '任务失败',
    BackgroundTaskOutcome.cancelled => '任务已取消',
    BackgroundTaskOutcome.interrupted => '后台任务被系统中断',
  };

  String _phaseText(BackgroundTaskPhase phase) => switch (phase) {
    BackgroundTaskPhase.requesting => '正在请求…',
    BackgroundTaskPhase.generating => '正在生成…',
    BackgroundTaskPhase.thinking => '正在思考…',
    BackgroundTaskPhase.tool => '正在调用工具',
    BackgroundTaskPhase.waitingApproval => '等待授权',
    BackgroundTaskPhase.compacting => '正在压缩上下文…',
  };

  Map<String, Object?> _taskMap(_BackgroundTask task) {
    final detail = _phaseText(task.phase);
    return {
      'id': task.id,
      'conversationId': task.conversationId,
      'title': _settings.privacyMode ? _kAppName : task.title,
      'detail': _settings.privacyMode
          ? '运行中'
          : task.toolName.isNotEmpty &&
                (task.phase == BackgroundTaskPhase.tool ||
                    task.phase == BackgroundTaskPhase.waitingApproval)
          ? '$detail：${task.toolName}'
          : detail,
      'tokens': _settings.privacyMode ? 0 : task.tokens,
      'startedAt': task.startedAt.millisecondsSinceEpoch,
    };
  }

  Future<void> _sync() {
    _cancelUpdateTimer();
    final snapshot = _snapshot();
    return _enqueue(() => _sendSnapshot(snapshot));
  }

  Map<String, dynamic> _snapshot({Map<String, Object?>? terminal}) => {
    'revision': ++_revision,
    'settings': {
      ..._settings.toJson(),
      'completionSeconds': _settings.completionVisibility.seconds,
      'overlayProgressColor': _overlayProgressColor,
    },
    'tasks': _tasks.values.map(_taskMap).toList(),
    'terminal': terminal,
    'labels': {
      'app': _kAppName,
      'working': '运行中',
      'tasks': '个后台任务',
      'results': '后台任务结果',
      'stop': '停止任务',
      'close': '关闭',
    },
  };

  Future<void> _sendSnapshot(Map<String, dynamic> snapshot) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'sync',
      snapshot,
    );
    if (result != null) {
      status = MobileBackgroundStatus(result);
      notifyListeners();
    }
  }

  Future<void> refreshStatus() => _enqueue(() async {
    final result = await _channel.invokeMapMethod<String, dynamic>('getStatus');
    if (result != null) status = MobileBackgroundStatus(result);
    notifyListeners();
  });

  /// Called only by explicit settings actions. Neither sync nor status requests
  /// permissions, including when the app is reopened with enabled settings.
  Future<void> requestPermission(String permission) =>
      _settingsAction('requestPermission', permission);

  Future<void> openSettings(String destination) =>
      _settingsAction('openSettings', destination);

  Future<void> _settingsAction(String method, String argument) async {
    if (!supported) return;
    await initialize();
    try {
      await _channel.invokeMethod<void>(method, argument);
    } catch (error) {
      _recordError(error);
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method == 'openConversation') {
      final id = call.arguments as String?;
      if (id != null && id.isNotEmpty) _open(id);
    } else if (call.method == 'cancelTasks' || call.method == 'interrupted') {
      final args = Map<String, dynamic>.from(call.arguments as Map? ?? {});
      final ids = (args['ids'] as List? ?? []).cast<String>().toSet();
      final tasks = _tasks.values.where((t) => ids.contains(t.id)).toList();
      if (call.method == 'interrupted') {
        _recordError(
          (args['reason'] as Object?) ?? 'background_interrupted',
        );
        for (final task in tasks) {
          task.interrupted = true;
        }
      }
      // A channel callback must not wait for cancellation to call back into the
      // same native sync queue.
      for (final task in tasks) {
        unawaited(task.cancel().catchError(_recordError));
      }
    } else if (call.method == 'statusChanged') {
      unawaited(refreshStatus());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      unawaited(_sync());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _foreground = false;
    }
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    if (!supported) return Future<void>.value();
    final previous = _tail;
    final next = previous == null
        ? Future<void>.sync(operation)
        : previous.then((_) => operation());
    return _tail = next.catchError(_recordError);
  }

  void _recordError(Object error) {
    lastError = error.toString();
    debugPrint('[MobileBackground] $error');
    notifyListeners();
  }

  void _cancelUpdateTimer() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  @visibleForTesting
  Future<void> flush() async {
    if (_updateTimer != null) await _sync();
    await _tail;
  }

  @override
  void dispose() {
    _cancelUpdateTimer();
    if (_initialized) {
      WidgetsBinding.instance.removeObserver(this);
      _channel.setMethodCallHandler(null);
    }
    super.dispose();
  }
}
