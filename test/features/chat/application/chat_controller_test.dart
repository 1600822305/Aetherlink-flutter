import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';

void main() {
  test('chatControllerProvider builds the initial placeholder state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(chatControllerProvider);

    expect(state.isReady, isFalse);
  });
}
