part of '../../voice_settings_page.dart';
// ignore_for_file: invalid_use_of_protected_member

/// MiMo TTS section (preset / voice-design / voice-clone variants).
extension _MimoSettings on _TtsProviderDetailPageState {
  List<Widget> _buildMimoVoice() {
    final isVoiceDesign = _model.contains('voicedesign');
    final isVoiceClone = _model.contains('voiceclone');
    final isPreset = !isVoiceDesign && !isVoiceClone;

    return [
      // -- Model selection --
      _DropdownField(
        label: '模型',
        value: _model.isEmpty ? 'mimo-v2.5-tts' : _model,
        items: const {
          'mimo-v2.5-tts': 'MiMo v2.5 TTS - 预设音色合成',
          'mimo-v2.5-tts-voicedesign': 'MiMo v2.5 VoiceDesign - 语音设计',
          'mimo-v2.5-tts-voiceclone': 'MiMo v2.5 VoiceClone - 语音克隆',
        },
        onChanged: (v) => setState(() => _model = v),
      ),
      const SizedBox(height: 12),
      // -- Voice selection (only for preset model) --
      if (isPreset) ...[
        _DropdownField(
          label: '音色',
          value: _voice.isEmpty ? 'mimo_default' : _voice,
          items: const {
            'mimo_default': 'MiMo Default - 默认音色',
            '冰糖': '冰糖 - 中文女声',
            '茉莉': '茉莉 - 中文女声',
            '苏打': '苏打 - 中文男声',
            '白桦': '白桦 - 中文男声',
            'Mia': 'Mia - English Female',
            'Chloe': 'Chloe - English Female',
            'Milo': 'Milo - English Male',
            'Dean': 'Dean - English Male',
          },
          onChanged: (v) => setState(() => _voice = v),
        ),
        const SizedBox(height: 12),
      ],
      // -- Audio format --
      _DropdownField(
        label: '音频格式',
        value: _audioFormat.isEmpty ? 'wav' : _audioFormat,
        items: const {'wav': 'WAV - 无损音频', 'pcm16': 'PCM16 - 原始音频流'},
        onChanged: (v) => setState(() => _audioFormat = v),
      ),
      const SizedBox(height: 12),
      // -- Style prompt (emotion/style control for all models) --
      ModelFormField(
        label: '风格/情感标签',
        hint: '例如：happy, sad, angry, whisper, gentle...',
        controller: _stylePromptCtrl,
        maxLines: 2,
      ),
      const SizedBox(height: 12),
      // -- Voice description (voicedesign model only) --
      if (isVoiceDesign) ...[
        ModelFormField(
          label: '语音描述 (Voice Description)',
          hint: '描述你想要的声音特征，例如：一个温柔的年轻女性声音，语调轻柔...',
          controller: _mimoVoiceDescCtrl,
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        _InlineToggle(
          label: '优化文本预览 (Optimize Text Preview)',
          value: _mimoOptimizeTextPreview,
          onChanged: (v) => setState(() => _mimoOptimizeTextPreview = v),
        ),
        const SizedBox(height: 12),
      ],
      // -- Voice clone audio (voiceclone model only) --
      if (isVoiceClone) ...[
        ModelFormField(
          label: '克隆音频 (Base64)',
          hint: '粘贴音频文件的 Base64 编码内容...',
          controller: _mimoCloneAudioCtrl,
          maxLines: 3,
        ),
        const SizedBox(height: 12),
      ],
      // -- Sample rate --
      _DropdownField(
        label: '采样率',
        value: _sampleRate == 0 ? '32000' : _sampleRate.toString(),
        items: const {
          '8000': '8000 Hz',
          '16000': '16000 Hz',
          '22050': '22050 Hz',
          '24000': '24000 Hz',
          '32000': '32000 Hz (默认)',
          '44100': '44100 Hz',
          '48000': '48000 Hz',
        },
        onChanged: (v) =>
            setState(() => _sampleRate = int.tryParse(v) ?? 32000),
      ),
    ];
  }
}
