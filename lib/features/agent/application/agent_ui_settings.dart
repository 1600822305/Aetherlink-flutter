import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

part 'agent_ui_settings.g.dart';

/// 会话上下文长度上限（token）的持久化键。
const String kAgentContextLimitKey = 'agent_context_limit';

/// 智能体界面偏好的持久化键（执行设置/事件流显示）。
const String kAgentDefaultModeKey = 'agent_default_mode';
const String kAgentAutoCollapseKey = 'agent_auto_collapse_work_sessions';
const String kAgentFollowAiFileKey = 'agent_follow_ai_file';
const String kAgentSidebarTabIndexKey = 'agent_sidebar_tab_index';

/// 侧边栏当前 tab（0 智能体 / 1 话题 / 2 设置）。持久化（appSettingsStore）：
/// 重开抽屉、重启 app 都保持在上次 tab。
@Riverpod(keepAlive: true)
class AgentSidebarTabIndex extends _$AgentSidebarTabIndex {
  bool _touched = false;

  @override
  int build() {
    _hydrate();
    return 0;
  }

  Future<void> _hydrate() async {
    final stored = await ref
        .read(appSettingsStoreProvider)
        .getSetting(kAgentSidebarTabIndexKey);
    final index = int.tryParse(stored ?? '');
    if (!_touched && index != null && index >= 0 && index <= 2) {
      state = index;
    }
  }

  void set(int index) {
    if (index < 0 || index > 2) return;
    _touched = true;
    state = index;
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kAgentSidebarTabIndexKey, '$index');
  }
}

/// 智能体界面偏好（appSettingsStore 持久化，冷启动 hydrate 恢复）。
class AgentUiSettings {
  const AgentUiSettings({
    this.defaultMode = AgentSessionMode.code,
    this.autoCollapseWorkSessions = true,
    this.followAiFile = true,
    this.contextLimit = 128000,
  });

  /// 新话题的默认模式（Code/Auto/Ask/Plan）；与输入区模式 chip 同源，
  /// 草稿态切模式也写回这里（持久化）。
  final AgentSessionMode defaultMode;

  /// 工作段完成后自动折叠为摘要块（UI 稿 §4.1）。
  final bool autoCollapseWorkSessions;

  /// 右页工作台焦点 tab 跟随智能体当前活动。
  final bool followAiFile;

  /// 会话上下文长度上限（token）：用于展示已用/剩余占比，按模型
  /// 窗口自行设置（持久化）。
  final int contextLimit;

  AgentUiSettings copyWith({
    AgentSessionMode? defaultMode,
    bool? autoCollapseWorkSessions,
    bool? followAiFile,
    int? contextLimit,
  }) {
    return AgentUiSettings(
      defaultMode: defaultMode ?? this.defaultMode,
      autoCollapseWorkSessions:
          autoCollapseWorkSessions ?? this.autoCollapseWorkSessions,
      followAiFile: followAiFile ?? this.followAiFile,
      contextLimit: contextLimit ?? this.contextLimit,
    );
  }
}

@Riverpod(keepAlive: true)
class AgentUiSettingsController extends _$AgentUiSettingsController {
  /// hydrate 窗口内用户已改过的设置键：hydrate 不再用存储旧值覆盖。
  final Set<String> _touched = {};

  @override
  AgentUiSettings build() {
    _hydrate();
    return const AgentUiSettings();
  }

  Future<void> _hydrate() async {
    final store = ref.read(appSettingsStoreProvider);
    final storedLimit = await store.getSetting(kAgentContextLimitKey);
    final storedMode = await store.getSetting(kAgentDefaultModeKey);
    final storedCollapse = await store.getSetting(kAgentAutoCollapseKey);
    final storedFollow = await store.getSetting(kAgentFollowAiFileKey);

    final limit = int.tryParse(storedLimit ?? '');
    final mode = AgentSessionMode.values
        .where((m) => m.name == storedMode)
        .firstOrNull;
    state = state.copyWith(
      contextLimit: _touched.contains(kAgentContextLimitKey)
          ? null
          : (limit != null && limit > 0)
          ? limit
          : null,
      defaultMode: _touched.contains(kAgentDefaultModeKey) ? null : mode,
      autoCollapseWorkSessions: _touched.contains(kAgentAutoCollapseKey)
          ? null
          : switch (storedCollapse) {
              '1' => true,
              '0' => false,
              _ => null,
            },
      followAiFile: _touched.contains(kAgentFollowAiFileKey)
          ? null
          : switch (storedFollow) {
              '1' => true,
              '0' => false,
              _ => null,
            },
    );
  }

  void setDefaultMode(AgentSessionMode mode) {
    _touched.add(kAgentDefaultModeKey);
    state = state.copyWith(defaultMode: mode);
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kAgentDefaultModeKey, mode.name);
  }

  void setAutoCollapseWorkSessions(bool value) {
    _touched.add(kAgentAutoCollapseKey);
    state = state.copyWith(autoCollapseWorkSessions: value);
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kAgentAutoCollapseKey, value ? '1' : '0');
  }

  void setFollowAiFile(bool value) {
    _touched.add(kAgentFollowAiFileKey);
    state = state.copyWith(followAiFile: value);
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kAgentFollowAiFileKey, value ? '1' : '0');
  }

  void setContextLimit(int value) {
    if (value <= 0) return;
    _touched.add(kAgentContextLimitKey);
    state = state.copyWith(contextLimit: value);
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kAgentContextLimitKey, '$value');
  }
}
