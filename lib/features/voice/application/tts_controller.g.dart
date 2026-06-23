// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The central TTS controller: manages text chunking, synthesis (network or
/// system), audio playback, prefetching, and exposes an immutable
/// [TtsPlaybackState] for the UI.
///
/// Architecture follows Kelivo's `TtsProvider` (chunked playback + prefetch)
/// but uses Riverpod `Notifier` (the project's standard) instead of
/// `ChangeNotifier`.

@ProviderFor(TtsController)
final ttsControllerProvider = TtsControllerProvider._();

/// The central TTS controller: manages text chunking, synthesis (network or
/// system), audio playback, prefetching, and exposes an immutable
/// [TtsPlaybackState] for the UI.
///
/// Architecture follows Kelivo's `TtsProvider` (chunked playback + prefetch)
/// but uses Riverpod `Notifier` (the project's standard) instead of
/// `ChangeNotifier`.
final class TtsControllerProvider
    extends $NotifierProvider<TtsController, TtsPlaybackState> {
  /// The central TTS controller: manages text chunking, synthesis (network or
  /// system), audio playback, prefetching, and exposes an immutable
  /// [TtsPlaybackState] for the UI.
  ///
  /// Architecture follows Kelivo's `TtsProvider` (chunked playback + prefetch)
  /// but uses Riverpod `Notifier` (the project's standard) instead of
  /// `ChangeNotifier`.
  TtsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ttsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ttsControllerHash();

  @$internal
  @override
  TtsController create() => TtsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TtsPlaybackState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TtsPlaybackState>(value),
    );
  }
}

String _$ttsControllerHash() => r'8d200651364e1bb8ef001d3fa04b03cade8c5a3c';

/// The central TTS controller: manages text chunking, synthesis (network or
/// system), audio playback, prefetching, and exposes an immutable
/// [TtsPlaybackState] for the UI.
///
/// Architecture follows Kelivo's `TtsProvider` (chunked playback + prefetch)
/// but uses Riverpod `Notifier` (the project's standard) instead of
/// `ChangeNotifier`.

abstract class _$TtsController extends $Notifier<TtsPlaybackState> {
  TtsPlaybackState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TtsPlaybackState, TtsPlaybackState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TtsPlaybackState, TtsPlaybackState>,
              TtsPlaybackState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
