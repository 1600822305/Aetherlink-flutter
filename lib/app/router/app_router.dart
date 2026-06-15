import 'package:go_router/go_router.dart';

import 'package:aetherlink_flutter/features/chat/presentation/mobile/chat_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/about_page.dart';

/// Declarative application route table (go_router).
///
/// go_router was chosen for M4.0 (see the M4.0 hand-off / `docs/ARCHITECTURE.md`):
/// declarative routes, deep-link support, and a smooth path to the desktop
/// master-detail shell in M5.
///
/// M4.0 only wires the foundation routes. The existing [ChatPage] placeholder is
/// kept as the home target — its content is owned by M4.1 and is left untouched
/// here. New feature pages register their own routes as later milestones land.
abstract final class AppRouter {
  static const String chatPath = '/';
  static const String aboutPath = '/about';

  static GoRouter create() => GoRouter(
    initialLocation: chatPath,
    routes: [
      GoRoute(
        path: chatPath,
        name: 'chat',
        builder: (context, state) => const ChatPage(),
      ),
      GoRoute(
        path: aboutPath,
        name: 'about',
        builder: (context, state) => const AboutPage(),
      ),
    ],
  );
}
