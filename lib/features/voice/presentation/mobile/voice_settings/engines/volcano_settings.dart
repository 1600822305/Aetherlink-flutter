part of '../../voice_settings_page.dart';
// ignore_for_file: invalid_use_of_protected_member

/// Volcano Engine TTS section: API-version options, voice/emotion pickers and
/// advanced (cluster) fields.
extension _VolcanoSettings on _TtsProviderDetailPageState {
  // -- Volcano API version + V3 options (inline in credentials area) --
  List<Widget> _buildVolcanoApiOptions() {
    final showV3 = _apiVersion == 'v3' || _apiVersion == 'auto';
    return [
      const SizedBox(height: 12),
      _DropdownField(
        label: '接口版本',
        value: _apiVersion,
        items: const {
          'auto': '自动 (根据音色选择)',
          'v1': 'V1 (传统音色)',
          'v3': 'V3 (大模型音色)',
        },
        onChanged: (v) => setState(() => _apiVersion = v),
      ),
      if (showV3) ...[
        const SizedBox(height: 12),
        _DropdownField(
          label: 'Resource ID',
          value: _resourceId,
          items: const {
            '': '自动选择',
            'volc.service_type.10029': 'BigTTS (豆包大模型)',
            'seed-tts-2.0': 'Seed TTS 2.0',
          },
          onChanged: (v) => setState(() => _resourceId = v),
        ),
        const SizedBox(height: 12),
        ModelFormField(
          label: '模型 (Model)',
          hint: '留空使用默认',
          controller: _modelCtrl,
        ),
      ],
      const SizedBox(height: 4),
    ];
  }

  List<Widget> _buildVolcanoVoice() {
    final voiceDisplayName = _voice.isEmpty
        ? '选择音色...'
        : kVolcanoVoices.entries
                  .where((e) => e.value == _voice)
                  .map((e) => e.key)
                  .firstOrNull ??
              _voice;
    final emotionDisplayName = _emotion.isEmpty
        ? '默认'
        : kVolcanoEmotions[_emotion] ?? _emotion;

    return [
      _SelectorField(
        label: '音色',
        value: _voice,
        displayText: voiceDisplayName,
        onTap: () async {
          final result = await FullScreenVoicePicker.show(
            context,
            title: '选择火山引擎音色',
            groups: buildVolcanoVoiceGroups(),
            selectedKey: kVolcanoVoices.entries
                .where((e) => e.value == _voice)
                .map((e) => e.key)
                .firstOrNull,
          );
          if (result != null) {
            setState(() {
              _voice = kVolcanoVoices[result] ?? result;
            });
          }
        },
      ),
      const SizedBox(height: 12),
      _SelectorField(
        label: '情感风格',
        value: _emotion,
        displayText: emotionDisplayName,
        onTap: () async {
          final result = await FullScreenVoicePicker.show(
            context,
            title: '选择情感风格',
            groups: buildVolcanoEmotionGroups(),
            selectedKey: _emotion,
            allowEmpty: true,
          );
          if (result != null) setState(() => _emotion = result);
        },
      ),
    ];
  }

  List<Widget> _buildVolcanoAdvanced() {
    return [
      ModelFormField(
        label: 'Cluster',
        hint: 'volcano_tts',
        controller: _clusterCtrl,
      ),
    ];
  }
}
