import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:aetherlink_flutter/shared/utils/haptics.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/chat_page.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/translate_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/about_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/agent_prompts_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/appearance_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/behavior_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/chat_interface_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/default_model_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/input_box_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/mcp_server_detail_page.dart';
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
import 'package:aetherlink_flutter/features/settings/presentation/mobile/top_toolbar_settings_page.dart';
import 'package:aetherlink_flutter/features/theming/presentation/mobile/theme_style_settings_page.dart';
import 'package:aetherlink_flutter/features/welcome/presentation/mobile/welcome_page.dart';

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
  static const String agentPromptsPath = '/settings/agent-prompts';
  static const String quickPhrasesPath = '/settings/quick-phrases';
  static const String networkProxyPath = '/settings/network-proxy';
  static const String behaviorPath = '/settings/behavior';
  static const String welcomePath = '/welcome';
  static const String translatePath = '/translate';

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
        path: agentPromptsPath,
        name: 'agent-prompts',
        pageBuilder: (context, state) =>
            _instant(state, const AgentPromptsSettingsPage()),
      ),
      GoRoute(
        path: quickPhrasesPath,
        name: 'quick-phrases',
        pageBuilder: (context, state) =>
            _instant(state, const QuickPhrasesSettingsPage()),
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
        path: defaultModelPath,
        name: 'default-model',
        pageBuilder: (context, state) =>
            _instant(state, const DefaultModelSettingsPage()),
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
