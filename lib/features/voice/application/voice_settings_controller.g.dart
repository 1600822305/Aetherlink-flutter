// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Persists voice settings (TTS/ASR provider list, active provider, global
/// preferences) following the project's `JsonKvNotifier` pattern — a single JSON
/// blob in the Drift key/value store.

@ProviderFor(VoiceSettingsController)
final voiceSettingsControllerProvider = VoiceSettingsControllerProvider._();

/// Persists voice settings (TTS/ASR provider list, active provider, global
/// preferences) following the project's `JsonKvNotifier` pattern — a single JSON
/// blob in the Drift key/value store.
final class VoiceSettingsControllerProvider
    extends $NotifierProvider<VoiceSettingsController, VoiceSettings> {
  /// Persists voice settings (TTS/ASR provider list, active provider, global
  /// preferences) following the project's `JsonKvNotifier` pattern — a single JSON
  /// blob in the Drift key/value store.
  VoiceSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'voiceSettingsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$voiceSettingsControllerHash();

  @$internal
  @override
  VoiceSettingsController create() => VoiceSettingsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VoiceSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VoiceSettings>(value),
    );
  }
}

String _$voiceSettingsControllerHash() =>
    r'973d70b56f0185c3abbb7ffdf9aaa2011e527cc2';

/// Persists voice settings (TTS/ASR provider list, active provider, global
/// preferences) following the project's `JsonKvNotifier` pattern — a single JSON
/// blob in the Drift key/value store.

abstract class _$VoiceSettingsController extends $Notifier<VoiceSettings> {
  VoiceSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<VoiceSettings, VoiceSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<VoiceSettings, VoiceSettings>,
              VoiceSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Convenience provider: the currently active TTS provider setting, or `null`
/// if none is configured. Derived from [voiceSettingsControllerProvider].

@ProviderFor(activeTtsProvider)
final activeTtsProviderProvider = ActiveTtsProviderProvider._();

/// Convenience provider: the currently active TTS provider setting, or `null`
/// if none is configured. Derived from [voiceSettingsControllerProvider].

final class ActiveTtsProviderProvider
    extends
        $FunctionalProvider<
          TtsProviderSetting?,
          TtsProviderSetting?,
          TtsProviderSetting?
        >
    with $Provider<TtsProviderSetting?> {
  /// Convenience provider: the currently active TTS provider setting, or `null`
  /// if none is configured. Derived from [voiceSettingsControllerProvider].
  ActiveTtsProviderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeTtsProviderProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeTtsProviderHash();

  @$internal
  @override
  $ProviderElement<TtsProviderSetting?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TtsProviderSetting? create(Ref ref) {
    return activeTtsProvider(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TtsProviderSetting? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TtsProviderSetting?>(value),
    );
  }
}

String _$activeTtsProviderHash() => r'98010e545c8988ee9b3356a7e75d14ba7a07a4c3';

/// Convenience provider: the currently active ASR provider setting, or `null`.

@ProviderFor(activeAsrProvider)
final activeAsrProviderProvider = ActiveAsrProviderProvider._();

/// Convenience provider: the currently active ASR provider setting, or `null`.

final class ActiveAsrProviderProvider
    extends
        $FunctionalProvider<
          AsrProviderSetting?,
          AsrProviderSetting?,
          AsrProviderSetting?
        >
    with $Provider<AsrProviderSetting?> {
  /// Convenience provider: the currently active ASR provider setting, or `null`.
  ActiveAsrProviderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeAsrProviderProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeAsrProviderHash();

  @$internal
  @override
  $ProviderElement<AsrProviderSetting?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsrProviderSetting? create(Ref ref) {
    return activeAsrProvider(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsrProviderSetting? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsrProviderSetting?>(value),
    );
  }
}

String _$activeAsrProviderHash() => r'4991da824ec71b32c6371e7b219b88dd5582a032';
