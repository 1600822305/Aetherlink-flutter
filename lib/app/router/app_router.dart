import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:aetherlink_flutter/shared/utils/haptics.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/chat_page.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/translate_page.dart';
import 'package:aetherlink_flutter/features/backup/presentation/backup_settings_page.dart';
import 'package:aetherlink_flutter/features/notes/presentation/mobile/note_editor_page.dart';
import 'package:aetherlink_flutter/features/notes/presentation/mobile/notes_page.dart';
import 'package:aetherlink_flutter/features/notes/presentation/mobile/notes_settings_page.dart';
import 'package:aetherlink_flutter/features/memory/presentation/mobile/assistant_memory_index_page.dart';
import 'package:aetherlink_flutter/features/memory/presentation/mobile/assistant_memory_list_page.dart';
import 'package:aetherlink_flutter/features/memory/presentation/mobile/global_memory_list_page.dart';
import 'package:aetherlink_flutter/features/memory/presentation/mobile/memory_home_page.dart';
import 'package:aetherlink_flutter/features/memory/presentation/mobile/memory_settings_page.dart';
import 'package:aetherlink_flutter/features/memory/presentation/mobile/search_memory_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/about_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/agent_prompts_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/auxiliary_model_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/appearance_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/behavior_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/chat_interface_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/default_model_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/input_box_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/mcp_assistant_detail_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/mcp_server_detail_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/mcp_tool_domain_detail_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_combo/model_combo_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/mcp_server_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/message_bubble_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/network_proxy_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/quick_phrases_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/thinking_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/add_provider_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/advanced_api_config_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/edit_model_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/model_provider_detail_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/multi_key_management_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/settings_search_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/skill_editor_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/skill_store_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/skills_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/top_toolbar_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/web_search_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/web_search/add_search_provider_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/web_search/search_provider_detail_page.dart';
import 'package:aetherlink_flutter/features/theming/presentation/mobile/theme_style_settings_page.dart';
import 'package:aetherlink_flutter/features/voice/presentation/mobile/voice_settings_page.dart';
import 'package:aetherlink_flutter/features/welcome/presentation/mobile/welcome_page.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/workspace_management_page.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/workspace_page.dart';

/// Declarative application route table (go_router).
///
/// go_router was chosen for M4.0 (see the M4.0 hand-off / `docs/ARCHITECTURE.md`):
/// declarative routes, deep-link support, and a smooth path to the desktop
/// master-detail shell in M5.
///
/// The existing [ChatPage] placeholder is kept as the home target — its content
/// is owned by a later milestone and is left untouched here. New feature pages
/// register their own routes as later milestones land.
abstract final class AppRouter {
  static const String chatPath = '/';
  static const String settingsPath = '/settings';
  static const String aboutPath = '/about';
  static const String defaultModelPath = '/settings/default-model';
  static const String auxiliaryModelPath = '/settings/auxiliary-model';
  static const String appearancePath = '/settings/appearance';
  static const String inputBoxSettingsPath = '/settings/appearance/input-box';
  static const String topToolbarSettingsPath =
      '/settings/appearance/top-toolbar';
  static const String chatInterfaceSettingsPath =
      '/settings/appearance/chat-interface';
  static const String messageBubbleSettingsPath =
      '/settings/appearance/message-bubble';
  static const String thinkingSettingsPath = '/settings/appearance/thinking';
  static const String themeStyleSettingsPath =
      '/settings/appearance/theme-style';
  static const String mcpServerPath = '/settings/mcp-server';
  static String mcpAssistantDetailPath(String serverId) =>
      '/settings/mcp-assistant/$serverId';
  static String mcpAssistantDomainPath(String serverId, String domain) =>
      '/settings/mcp-assistant/$serverId/domain/$domain';
  static const String agentPromptsPath = '/settings/agent-prompts';
  static const String skillsPath = '/settings/skills';
  static const String skillStorePath = '/settings/skills/store';
  static String skillEditorPath(String skillId) => '/settings/skills/$skillId';
  static const String quickPhrasesPath = '/settings/quick-phrases';
  static const String webSearchPath = '/settings/web-search';
  static const String addSearchProviderPath = '/settings/web-search/add';
  static String searchProviderDetailPath(String providerId) =>
      '/settings/web-search/provider/$providerId';
  static const String modelComboPath = '/settings/model-combo';
  static const String networkProxyPath = '/settings/network-proxy';
  static const String behaviorPath = '/settings/behavior';
  static const String settingsSearchPath = '/settings/search';
  static const String voiceSettingsPath = '/settings/voice';
  static const String backupSettingsPath = '/settings/backup';
  static const String memoryPath = '/settings/memory';
  static const String globalMemoryPath = '/settings/memory/global';
  static const String assistantMemoryIndexPath = '/settings/memory/assistants';
  static const String searchMemoryPath = '/settings/memory/search';
  static const String memorySettingsPath = '/settings/memory/settings';
  static const String workspaceManagementPath = '/settings/workspace';
  static const String notesPath = '/settings/notes';
  static const String notesSettingsPath = '/settings/notes/settings';
  static String noteEditorPath(String relativePath, String name) =>
      '/settings/notes/edit?path=${Uri.encodeQueryComponent(relativePath)}'
      '&name=${Uri.encodeQueryComponent(name)}';
  static const String welcomePath = '/welcome';
  static const String translatePath = '/translate';
  static const String workspacePath = '/workspace';

  /// The model-provider third-level pages (M4.3.1). The detail / edit / advanced
  /// routes are parameterized by `:providerId`; the helpers below build a
  /// concrete location for navigation.
  static const String addProviderPath = '/settings/add-provider';
  static String modelProviderPath(String providerId) =>
      '/settings/model-provider/$providerId';
  static String editModelPath(String providerId, {String? modelId}) =>
      modelId == null
      ? '/settings/model-provider/$providerId/edit-model'
      : '/settings/model-provider/$providerId/edit-model?modelId='
            '${Uri.encodeQueryComponent(modelId)}';
  static String advancedApiPath(String providerId) =>
      '/settings/model-provider/$providerId/advanced-api';
  static String multiKeyPath(String providerId) =>
      '/settings/model-provider/$providerId/multi-key';

  /// Wraps [child] in a zero-duration [CustomTransitionPage] so route changes
  /// (push *and* pop) are truly instant. The app intentionally has no page
  /// transitions; a no-op [PageTransitionsBuilder] only removes the visual
  /// animation while leaving `MaterialPageRoute`'s 300ms `transitionDuration` in
  /// place — that lingering window is what made every navigation feel laggy.
  /// Setting both durations to [Duration.zero] also disposes the previous route
  /// immediately instead of keeping it mounted for the transition.
  static Page<void> _instant(GoRouterState state, Widget child) =>
      CustomTransitionPage<void>(
        key: state.pageKey,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder: (_, _, _, child) => child,
        child: child,
      );

  /// Builds the router. [startAtWelcome] decides the first landing page: M4.1
  /// passes the in-memory onboarding state (first-time user → [welcomePath],
  /// otherwise → [chatPath]). It defaults to `false` so existing callers keep
  /// landing on the chat home.
  static GoRouter create({bool startAtWelcome = false}) => GoRouter(
    initialLocation: startAtWelcome ? welcomePath : chatPath,
    observers: [_HapticNavObserver()],
    routes: [
      GoRoute(
        path: chatPath,
        name: 'chat',
        pageBuilder: (context, state) => _instant(state, const ChatPage()),
      ),
      GoRoute(
        path: welcomePath,
        name: 'welcome',
        pageBuilder: (context, state) => _instant(state, const WelcomePage()),
      ),
      GoRoute(
        path: translatePath,
        name: 'translate',
        pageBuilder: (context, state) => _instant(state, const TranslatePage()),
      ),
      GoRoute(
        path: workspacePath,
        name: 'workspace',
        pageBuilder: (context, state) => _instant(state, const WorkspacePage()),
      ),
      GoRoute(
        path: settingsPath,
        name: 'settings',
        pageBuilder: (context, state) => _instant(state, const SettingsPage()),
      ),
      GoRoute(
        path: aboutPath,
        name: 'about',
        pageBuilder: (context, state) => _instant(state, const AboutPage()),
      ),
      GoRoute(
        path: modelComboPath,
        name: 'model-combo',
        pageBuilder: (context, state) =>
            _instant(state, const ModelComboSettingsPage()),
      ),
      GoRoute(
        path: mcpServerPath,
        name: 'mcp-server',
        pageBuilder: (context, state) =>
            _instant(state, const McpServerSettingsPage()),
      ),
      GoRoute(
        path: '/settings/mcp-server/:id',
        name: 'mcp-server-detail',
        pageBuilder: (context, state) => _instant(
          state,
          McpServerDetailPage(serverId: state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/settings/mcp-assistant/:serverId',
        name: 'mcp-assistant-detail',
        pageBuilder: (context, state) => _instant(
          state,
          McpAssistantDetailPage(
            serverId: state.pathParameters['serverId'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/settings/mcp-assistant/:serverId/domain/:domain',
        name: 'mcp-assistant-domain',
        pageBuilder: (context, state) => _instant(
          state,
          McpToolDomainDetailPage(
            serverId: state.pathParameters['serverId'] ?? '',
            domain: state.pathParameters['domain'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: agentPromptsPath,
        name: 'agent-prompts',
        pageBuilder: (context, state) =>
            _instant(state, const AgentPromptsSettingsPage()),
      ),
      GoRoute(
        path: skillsPath,
        name: 'skills',
        pageBuilder: (context, state) =>
            _instant(state, const SkillsSettingsPage()),
      ),
      GoRoute(
        path: skillStorePath,
        name: 'skill-store',
        pageBuilder: (context, state) =>
            _instant(state, const SkillStorePage()),
      ),
      GoRoute(
        path: '$skillsPath/:skillId',
        name: 'skill-editor',
        pageBuilder: (context, state) => _instant(
          state,
          SkillEditorPage(skillId: state.pathParameters['skillId']!),
        ),
      ),
      GoRoute(
        path: quickPhrasesPath,
        name: 'quick-phrases',
        pageBuilder: (context, state) =>
            _instant(state, const QuickPhrasesSettingsPage()),
      ),
      GoRoute(
        path: webSearchPath,
        name: 'web-search',
        pageBuilder: (context, state) =>
            _instant(state, const WebSearchSettingsPage()),
      ),
      GoRoute(
        path: addSearchProviderPath,
        name: 'add-search-provider',
        pageBuilder: (context, state) =>
            _instant(state, const AddSearchProviderPage()),
      ),
      GoRoute(
        path: '/settings/web-search/provider/:providerId',
        name: 'search-provider-detail',
        pageBuilder: (context, state) => _instant(
          state,
          SearchProviderDetailPage(
            providerId: state.pathParameters['providerId'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: networkProxyPath,
        name: 'network-proxy',
        pageBuilder: (context, state) =>
            _instant(state, const NetworkProxySettingsPage()),
      ),
      GoRoute(
        path: behaviorPath,
        name: 'behavior',
        pageBuilder: (context, state) =>
            _instant(state, const BehaviorSettingsPage()),
      ),
      GoRoute(
        path: memoryPath,
        name: 'memory',
        pageBuilder: (context, state) =>
            _instant(state, const MemoryHomePage()),
      ),
      GoRoute(
        path: globalMemoryPath,
        name: 'memoryGlobal',
        pageBuilder: (context, state) =>
            _instant(state, const GlobalMemoryListPage()),
      ),
      GoRoute(
        path: assistantMemoryIndexPath,
        name: 'memoryAssistants',
        pageBuilder: (context, state) =>
            _instant(state, const AssistantMemoryIndexPage()),
      ),
      GoRoute(
        path: searchMemoryPath,
        name: 'memorySearch',
        pageBuilder: (context, state) =>
            _instant(state, const SearchMemoryPage()),
      ),
      GoRoute(
        path: memorySettingsPath,
        name: 'memorySettings',
        pageBuilder: (context, state) =>
            _instant(state, const MemorySettingsPage()),
      ),
      GoRoute(
        path: AssistantMemoryRoute.pattern,
        name: 'memoryAssistant',
        pageBuilder: (context, state) => _instant(
          state,
          AssistantMemoryListPage(
            assistantId: state.pathParameters['assistantId'] ?? '',
            assistantName: state.extra is String ? state.extra! as String : '',
          ),
        ),
      ),
      GoRoute(
        path: voiceSettingsPath,
        name: 'voice-settings',
        pageBuilder: (context, state) =>
            _instant(state, const VoiceSettingsPage()),
      ),
      GoRoute(
        path: backupSettingsPath,
        name: 'backup-settings',
        pageBuilder: (context, state) =>
            _instant(state, const BackupSettingsPage()),
      ),
      GoRoute(
        path: notesPath,
        name: 'notes',
        pageBuilder: (context, state) => _instant(state, const NotesPage()),
      ),
      GoRoute(
        path: workspaceManagementPath,
        name: 'workspace-management',
        pageBuilder: (context, state) =>
            _instant(state, const WorkspaceManagementPage()),
      ),
      GoRoute(
        path: notesSettingsPath,
        name: 'notes-settings',
        pageBuilder: (context, state) =>
            _instant(state, const NotesSettingsPage()),
      ),
      GoRoute(
        path: '/settings/notes/edit',
        name: 'note-editor',
        pageBuilder: (context, state) => _instant(
          state,
          NoteEditorPage(
            relativePath: state.uri.queryParameters['path'] ?? '',
            title: state.uri.queryParameters['name'] ?? '笔记',
          ),
        ),
      ),
      GoRoute(
        path: settingsSearchPath,
        name: 'settings-search',
        pageBuilder: (context, state) =>
            _instant(state, const SettingsSearchPage()),
      ),
      GoRoute(
        path: defaultModelPath,
        name: 'default-model',
        pageBuilder: (context, state) =>
            _instant(state, const DefaultModelSettingsPage()),
      ),
      GoRoute(
        path: auxiliaryModelPath,
        name: 'auxiliary-model',
        pageBuilder: (context, state) =>
            _instant(state, const AuxiliaryModelSettingsPage()),
      ),
      GoRoute(
        path: appearancePath,
        name: 'appearance',
        pageBuilder: (context, state) =>
            _instant(state, const AppearanceSettingsPage()),
      ),
      GoRoute(
        path: inputBoxSettingsPath,
        name: 'input-box-settings',
        pageBuilder: (context, state) =>
            _instant(state, const InputBoxSettingsPage()),
      ),
      GoRoute(
        path: topToolbarSettingsPath,
        name: 'top-toolbar-settings',
        pageBuilder: (context, state) =>
            _instant(state, const TopToolbarSettingsPage()),
      ),
      GoRoute(
        path: chatInterfaceSettingsPath,
        name: 'chat-interface-settings',
        pageBuilder: (context, state) =>
            _instant(state, const ChatInterfaceSettingsPage()),
      ),
      GoRoute(
        path: messageBubbleSettingsPath,
        name: 'message-bubble-settings',
        pageBuilder: (context, state) =>
            _instant(state, const MessageBubbleSettingsPage()),
      ),
      GoRoute(
        path: thinkingSettingsPath,
        name: 'thinking-settings',
        pageBuilder: (context, state) =>
            _instant(state, const ThinkingSettingsPage()),
      ),
      GoRoute(
        path: themeStyleSettingsPath,
        name: 'theme-style-settings',
        pageBuilder: (context, state) =>
            _instant(state, const ThemeStyleSettingsPage()),
      ),
      GoRoute(
        path: addProviderPath,
        name: 'add-provider',
        pageBuilder: (context, state) =>
            _instant(state, const AddProviderPage()),
      ),
      GoRoute(
        path: '/settings/model-provider/:providerId',
        name: 'model-provider',
        pageBuilder: (context, state) => _instant(
          state,
          ModelProviderDetailPage(
            providerId: state.pathParameters['providerId'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/settings/model-provider/:providerId/edit-model',
        name: 'edit-model',
        pageBuilder: (context, state) => _instant(
          state,
          EditModelPage(
            providerId: state.pathParameters['providerId'] ?? '',
            modelId: state.uri.queryParameters['modelId'],
          ),
        ),
      ),
      GoRoute(
        path: '/settings/model-provider/:providerId/advanced-api',
        name: 'advanced-api',
        pageBuilder: (context, state) => _instant(
          state,
          AdvancedApiConfigPage(
            providerId: state.pathParameters['providerId'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/settings/model-provider/:providerId/multi-key',
        name: 'multi-key',
        pageBuilder: (context, state) => _instant(
          state,
          MultiKeyManagementPage(
            providerId: state.pathParameters['providerId'] ?? '',
          ),
        ),
      ),
    ],
  );
}

/// Fires a gated haptic on forward navigation (port of the web
/// `hapticFeedback.enableOnNavigation`). The initial route (no previous route)
/// is skipped so launching the app doesn't buzz. Gating against the master /
/// 导航 sub-toggle lives in [Haptics.onNavigation].
class _HapticNavObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) Haptics.instance.onNavigation();
  }
}
