// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asr_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The ASR controller: manages microphone recording, speech recognition
/// (real-time streaming or batch Whisper), and exposes the recognized text.
///
/// Architecture follows RikkaHub's `ASRController` pattern but uses Riverpod
/// `Notifier`.

@ProviderFor(AsrController)
final asrControllerProvider = AsrControllerProvider._();

/// The ASR controller: manages microphone recording, speech recognition
/// (real-time streaming or batch Whisper), and exposes the recognized text.
///
/// Architecture follows RikkaHub's `ASRController` pattern but uses Riverpod
/// `Notifier`.
final class AsrControllerProvider
    extends
        $NotifierProvider<
          AsrController,
          ({String? error, AsrStatus status, String text})
        > {
  /// The ASR controller: manages microphone recording, speech recognition
  /// (real-time streaming or batch Whisper), and exposes the recognized text.
  ///
  /// Architecture follows RikkaHub's `ASRController` pattern but uses Riverpod
  /// `Notifier`.
  AsrControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'asrControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$asrControllerHash();

  @$internal
  @override
  AsrController create() => AsrController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(
    ({String? error, AsrStatus status, String text}) value,
  ) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<({String? error, AsrStatus status, String text})>(
            value,
          ),
    );
  }
}

String _$asrControllerHash() => r'36ad2cc9abb55a26c804c68a431b9ba613ce3dbc';

/// The ASR controller: manages microphone recording, speech recognition
/// (real-time streaming or batch Whisper), and exposes the recognized text.
///
/// Architecture follows RikkaHub's `ASRController` pattern but uses Riverpod
/// `Notifier`.

abstract class _$AsrController
    extends $Notifier<({String? error, AsrStatus status, String text})> {
  ({String? error, AsrStatus status, String text}) build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              ({String? error, AsrStatus status, String text}),
              ({String? error, AsrStatus status, String text})
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                ({String? error, AsrStatus status, String text}),
                ({String? error, AsrStatus status, String text})
              >,
              ({String? error, AsrStatus status, String text}),
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
