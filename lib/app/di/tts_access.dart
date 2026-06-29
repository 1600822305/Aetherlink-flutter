import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/voice/application/tts_controller.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_playback_state.dart';

part 'tts_access.g.dart';

/// App-level composition seam exposing the 语音播放 (TTS) controller to the
/// `chat` feature.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`,
/// so the chat message-action layer cannot read [TtsController] (which lives in
/// `voice/application`) directly. It instead watches [ttsPlaybackProvider] and
/// invokes playback through [TtsActions] here in `app/` (the composition root,
/// which may depend on any feature). The pure-Dart `voice/domain`
/// [TtsPlaybackState] type may be imported across features and is re-used as-is.
@Riverpod(keepAlive: true)
TtsPlaybackState ttsPlayback(Ref ref) => ref.watch(ttsControllerProvider);

/// Action seam over [TtsController]: lets the chat feature trigger playback
/// without importing `voice/application`. Toggling play on the message that is
/// already speaking pauses/resumes it (see [TtsController.speak]).
@Riverpod(keepAlive: true)
TtsActions ttsActions(Ref ref) => TtsActions(ref);

/// Thin callable wrapper handed to the chat feature by [ttsActionsProvider].
class TtsActions {
  const TtsActions(this._ref);

  final Ref _ref;

  Future<void> speak(String text, {required String messageId}) =>
      _ref.read(ttsControllerProvider.notifier).speak(text, messageId: messageId);
}
