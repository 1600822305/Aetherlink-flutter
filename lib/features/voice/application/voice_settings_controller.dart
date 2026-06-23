import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/app/di/json_kv_notifier.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/features/voice/domain/voice_settings.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_provider_setting.dart';
import 'package:aetherlink_flutter/features/voice/domain/asr_provider_setting.dart';

part 'voice_settings_controller.g.dart';

const String kVoiceSettingsKey = 'voiceSettings';

/// Persists voice settings (TTS/ASR provider list, active provider, global
/// preferences) following the project's `JsonKvNotifier` pattern — a single JSON
/// blob in the Drift key/value store.
@Riverpod(keepAlive: true)
class VoiceSettingsController extends _$VoiceSettingsController
    with JsonKvNotifier<VoiceSettings> {
  @override
  ChatRepository get kvStore => ref.read(appSettingsStoreProvider);

  @override
  String get storageKey => kVoiceSettingsKey;

  @override
  VoiceSettings fromStored(Map<String, dynamic> json) =>
      VoiceSettings.fromJson(json);

  @override
  Map<String, dynamic> toStored(VoiceSettings value) => value.toJson();

  @override
  VoiceSettings build() => hydrate(const VoiceSettings());

  // -- TTS ------------------------------------------------------------------

  void setEnableTts(bool value) =>
      persist(state.copyWith(enableTts: value));

  void setActiveTtsProvider(String providerId) =>
      persist(state.copyWith(activeTtsProviderId: providerId));

  void updateTtsProvider(TtsProviderSetting provider) {
    final list = [...state.ttsProviders];
    final idx = list.indexWhere((p) => p.id == provider.id);
    if (idx >= 0) {
      list[idx] = provider;
    } else {
      list.add(provider);
    }
    persist(state.copyWith(ttsProviders: list));
  }

  void removeTtsProvider(String providerId) {
    persist(state.copyWith(
      ttsProviders: state.ttsProviders.where((p) => p.id != providerId).toList(),
    ));
  }

  // -- ASR ------------------------------------------------------------------

  void setEnableAsr(bool value) =>
      persist(state.copyWith(enableAsr: value));

  void setActiveAsrProvider(String providerId) =>
      persist(state.copyWith(activeAsrProviderId: providerId));

  void updateAsrProvider(AsrProviderSetting provider) {
    final list = [...state.asrProviders];
    final idx = list.indexWhere((p) => p.id == provider.id);
    if (idx >= 0) {
      list[idx] = provider;
    } else {
      list.add(provider);
    }
    persist(state.copyWith(asrProviders: list));
  }

  void removeAsrProvider(String providerId) {
    persist(state.copyWith(
      asrProviders: state.asrProviders.where((p) => p.id != providerId).toList(),
    ));
  }

  // -- Global ---------------------------------------------------------------

  void setDefaultSpeed(double speed) =>
      persist(state.copyWith(defaultSpeed: speed.clamp(0.5, 2.0)));
}

/// Convenience provider: the currently active TTS provider setting, or `null`
/// if none is configured. Derived from [voiceSettingsControllerProvider].
@riverpod
TtsProviderSetting? activeTtsProvider(Ref ref) {
  final settings = ref.watch(voiceSettingsControllerProvider);
  final id = settings.activeTtsProviderId;
  final match = settings.ttsProviders.where((p) => p.id == id);
  if (match.isNotEmpty) return match.first;
  // Fallback: system TTS is always implicitly available.
  if (id == 'system') return defaultTtsProvider(TtsProviderKind.system);
  return null;
}

/// Convenience provider: the currently active ASR provider setting, or `null`.
@riverpod
AsrProviderSetting? activeAsrProvider(Ref ref) {
  final settings = ref.watch(voiceSettingsControllerProvider);
  final id = settings.activeAsrProviderId;
  final match = settings.asrProviders.where((p) => p.id == id);
  if (match.isNotEmpty) return match.first;
  if (id == 'system') return defaultAsrProvider(AsrProviderKind.system);
  return null;
}
