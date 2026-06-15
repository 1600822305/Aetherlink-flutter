import 'package:flutter/widgets.dart';

import 'package:aetherlink_flutter/features/chat/presentation/mobile/chat_page.dart';

/// Application route table (placeholder).
///
/// The routing package is still **TBD** in `docs/ARCHITECTURE.md` (go_router is
/// a candidate but not yet selected via an ADR), and the scaffold task forbids
/// introducing packages the design docs have not chosen. Until the routing ADR
/// lands, the app exposes a single static home route, wired directly into
/// [AetherlinkApp]. Replace this with the real route table once the router is
/// decided.
abstract final class AppRouter {
  static Widget get home => const ChatPage();
}
