import 'package:go_router/go_router.dart';

import 'package:aetherlink_flutter/features/chat/presentation/mobile/chat_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/about_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/appearance_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/default_model_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/add_provider_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/advanced_api_config_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/edit_model_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/model_provider_detail_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/multi_key_management_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/settings_page.dart';
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
  static const String welcomePath = '/welcome';

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

  /// Builds the router. [startAtWelcome] decides the first landing page: M4.1
  /// passes the in-memory onboarding state (first-time user → [welcomePath],
  /// otherwise → [chatPath]). It defaults to `false` so existing callers keep
  /// landing on the chat home.
  static GoRouter create({bool startAtWelcome = false}) => GoRouter(
    initialLocation: startAtWelcome ? welcomePath : chatPath,
    routes: [
      GoRoute(
        path: chatPath,
        name: 'chat',
        builder: (context, state) => const ChatPage(),
      ),
      GoRoute(
        path: welcomePath,
        name: 'welcome',
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: settingsPath,
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: aboutPath,
        name: 'about',
        builder: (context, state) => const AboutPage(),
      ),
      GoRoute(
        path: defaultModelPath,
        name: 'default-model',
        builder: (context, state) => const DefaultModelSettingsPage(),
      ),
      GoRoute(
        path: appearancePath,
        name: 'appearance',
        builder: (context, state) => const AppearanceSettingsPage(),
      ),
      GoRoute(
        path: addProviderPath,
        name: 'add-provider',
        builder: (context, state) => const AddProviderPage(),
      ),
      GoRoute(
        path: '/settings/model-provider/:providerId',
        name: 'model-provider',
        builder: (context, state) => ModelProviderDetailPage(
          providerId: state.pathParameters['providerId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/settings/model-provider/:providerId/edit-model',
        name: 'edit-model',
        builder: (context, state) => EditModelPage(
          providerId: state.pathParameters['providerId'] ?? '',
          modelId: state.uri.queryParameters['modelId'],
        ),
      ),
      GoRoute(
        path: '/settings/model-provider/:providerId/advanced-api',
        name: 'advanced-api',
        builder: (context, state) => AdvancedApiConfigPage(
          providerId: state.pathParameters['providerId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/settings/model-provider/:providerId/multi-key',
        name: 'multi-key',
        builder: (context, state) => MultiKeyManagementPage(
          providerId: state.pathParameters['providerId'] ?? '',
        ),
      ),
    ],
  );
}
