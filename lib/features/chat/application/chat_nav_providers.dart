import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier to request the message list to scroll to a specific message ID.
class ScrollToMessageNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void scrollTo(String id) => state = id;
  void clear() => state = null;
}

final scrollToMessageIdProvider =
    NotifierProvider<ScrollToMessageNotifier, String?>(
      ScrollToMessageNotifier.new,
    );

/// Briefly highlights the message a 对话导航 jump landed on, mirroring the
/// web's `scrollToMessage` flash (1.6s), so the user can tell which message
/// the jump targeted.
class NavHighlightNotifier extends Notifier<String?> {
  Timer? _timer;

  @override
  String? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void flash(String id) {
    _timer?.cancel();
    state = id;
    _timer = Timer(const Duration(milliseconds: 1600), () {
      if (state == id) state = null;
    });
  }
}

final navHighlightMessageIdProvider =
    NotifierProvider<NavHighlightNotifier, String?>(NavHighlightNotifier.new);
