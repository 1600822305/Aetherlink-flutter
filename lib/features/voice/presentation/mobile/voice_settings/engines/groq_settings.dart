part of '../../voice_settings_page.dart';
// ignore_for_file: invalid_use_of_protected_member

/// Groq (PlayAI) TTS section.
extension _GroqSettings on _TtsProviderDetailPageState {
  List<Widget> _buildGroqVoice() {
    return [
      // -- Model selection --
      _DropdownField(
        label: '模型',
        value: _model.isEmpty ? 'playai-tts' : _model,
        items: const {
          'playai-tts': 'PlayAI TTS - 英语语音合成',
          'playai-tts-arabic': 'PlayAI TTS Arabic - 阿拉伯语',
        },
        onChanged: (v) => setState(() => _model = v),
      ),
      const SizedBox(height: 12),
      // -- Voice selection (23 voices) --
      _DropdownField(
        label: '音色',
        value: _voice.isEmpty ? 'Fritz-PlayAI' : _voice,
        items: const {
          'Ahmad-PlayAI': 'Ahmad',
          'Amira-PlayAI': 'Amira',
          'Arista-PlayAI': 'Arista',
          'Atlas-PlayAI': 'Atlas',
          'Basil-PlayAI': 'Basil',
          'Briggs-PlayAI': 'Briggs',
          'Calum-PlayAI': 'Calum',
          'Celeste-PlayAI': 'Celeste',
          'Cheyenne-PlayAI': 'Cheyenne',
          'Chip-PlayAI': 'Chip',
          'Cillian-PlayAI': 'Cillian',
          'Deedee-PlayAI': 'Deedee',
          'Fritz-PlayAI': 'Fritz',
          'Gail-PlayAI': 'Gail',
          'Indigo-PlayAI': 'Indigo',
          'Khalid-PlayAI': 'Khalid',
          'Mamaw-PlayAI': 'Mamaw',
          'Mason-PlayAI': 'Mason',
          'Mikail-PlayAI': 'Mikail',
          'Mitch-PlayAI': 'Mitch',
          'Nasser-PlayAI': 'Nasser',
          'Quinn-PlayAI': 'Quinn',
          'Thunder-PlayAI': 'Thunder',
        },
        onChanged: (v) => setState(() => _voice = v),
      ),
      const SizedBox(height: 12),
      // -- Audio format --
      _DropdownField(
        label: '音频格式',
        value: _audioFormat.isEmpty ? 'wav' : _audioFormat,
        items: const {
          'wav': 'WAV - 无损音频',
          'mp3': 'MP3 - 通用压缩',
          'flac': 'FLAC - 无损压缩',
          'ogg': 'OGG - 开源格式',
          'mulaw': 'μ-law - 电话编码',
        },
        onChanged: (v) => setState(() => _audioFormat = v),
      ),
      const SizedBox(height: 12),
      // -- Sample rate --
      _DropdownField(
        label: '采样率',
        value: _groqSampleRate.toString(),
        items: const {
          '8000': '8000 Hz',
          '16000': '16000 Hz',
          '22050': '22050 Hz',
          '24000': '24000 Hz (默认)',
          '32000': '32000 Hz',
          '44100': '44100 Hz',
          '48000': '48000 Hz',
        },
        onChanged: (v) =>
            setState(() => _groqSampleRate = int.tryParse(v) ?? 24000),
      ),
    ];
  }
}
