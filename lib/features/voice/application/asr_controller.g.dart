// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asr_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The ASR controller: manages microphone recording, speech recognition
/// (system native, real-time streaming, or batch Whisper), and exposes the
/// recognized text.

@ProviderFor(AsrController)
final asrControllerProvider = AsrControllerProvider._();

/// The ASR controller: manages microphone recording, speech recognition
/// (system native, real-time streaming, or batch Whisper), and exposes the
/// recognized text.
final class AsrControllerProvider
    extends
        $NotifierProvider<
          AsrController,
          ({String? error, AsrStatus status, String text})
        > {
  /// The ASR controller: manages microphone recording, speech recognition
  /// (system native, real-time streaming, or batch Whisper), and exposes the
  /// recognized text.
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

String _$asrControllerHash() => r'068c81b3401ab5f955153f928ae4b49f4c9b9dc4';

/// The ASR controller: manages microphone recording, speech recognition
/// (system native, real-time streaming, or batch Whisper), and exposes the
/// recognized text.

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
