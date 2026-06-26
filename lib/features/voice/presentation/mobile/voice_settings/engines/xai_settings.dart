part of '../../voice_settings_page.dart';
// ignore_for_file: invalid_use_of_protected_member

/// xAI (Grok) TTS section.
extension _XaiSettings on _TtsProviderDetailPageState {
  List<Widget> _buildXaiVoice() {
    return [
      // -- Voice selection (5 voices) --
      _DropdownField(
        label: '音色',
        value: _voice.isEmpty ? 'eve' : _voice,
        items: const {
          'eve': 'Eve - 活力女声',
          'ara': 'Ara - 温暖女声',
          'rex': 'Rex - 自信男声',
          'sal': 'Sal - 柔和男声',
          'leo': 'Leo - 权威男声',
        },
        onChanged: (v) => setState(() => _voice = v),
      ),
      const SizedBox(height: 12),
      // -- Language selection (20+ languages) --
      _DropdownField(
        label: '语言',
        value: _xaiLanguage,
        items: const {
          'auto': 'Auto - 自动检测',
          'en': 'English - 英语',
          'zh': 'Chinese - 中文',
          'ja': 'Japanese - 日语',
          'ko': 'Korean - 韩语',
          'fr': 'French - 法语',
          'de': 'German - 德语',
          'it': 'Italian - 意大利语',
          'pt-BR': 'Portuguese (BR) - 巴西葡语',
          'pt-PT': 'Portuguese (PT) - 葡萄牙语',
          'es-MX': 'Spanish (MX) - 墨西哥西语',
          'es-ES': 'Spanish (ES) - 西班牙语',
          'ru': 'Russian - 俄语',
          'ar-EG': 'Arabic (EG) - 埃及阿语',
          'ar-SA': 'Arabic (SA) - 沙特阿语',
          'ar-AE': 'Arabic (AE) - 阿联酋阿语',
          'bn': 'Bengali - 孟加拉语',
          'hi': 'Hindi - 印地语',
          'id': 'Indonesian - 印尼语',
          'tr': 'Turkish - 土耳其语',
          'vi': 'Vietnamese - 越南语',
        },
        onChanged: (v) => setState(() => _xaiLanguage = v),
      ),
      const SizedBox(height: 12),
      // -- Codec --
      _DropdownField(
        label: '编码格式',
        value: _xaiCodec,
        items: const {
          'mp3': 'MP3 - 通用压缩',
          'wav': 'WAV - 无损音频',
          'pcm': 'PCM - 原始音频流',
          'mulaw': 'μ-law - 电话编码',
          'alaw': 'A-law - 欧洲电话编码',
        },
        onChanged: (v) => setState(() => _xaiCodec = v),
      ),
      const SizedBox(height: 12),
      // -- Sample rate --
      _DropdownField(
        label: '采样率',
        value: _xaiSampleRate.toString(),
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
            setState(() => _xaiSampleRate = int.tryParse(v) ?? 24000),
      ),
      const SizedBox(height: 12),
      // -- Bit rate --
      _DropdownField(
        label: '比特率',
        value: _xaiBitRate.toString(),
        items: const {
          '64000': '64 kbps',
          '96000': '96 kbps',
          '128000': '128 kbps (默认)',
          '192000': '192 kbps',
          '256000': '256 kbps',
          '320000': '320 kbps',
        },
        onChanged: (v) =>
            setState(() => _xaiBitRate = int.tryParse(v) ?? 128000),
      ),
      const SizedBox(height: 12),
      // -- Text normalization toggle --
      _InlineToggle(
        label: '文本规范化 (Text Normalization)',
        value: _xaiTextNormalization,
        onChanged: (v) => setState(() => _xaiTextNormalization = v),
      ),
      const SizedBox(height: 12),
      // -- Optimize streaming latency --
      _DropdownField(
        label: '延迟优化',
        value: _xaiOptimizeStreamingLatency.toString(),
        items: const {'0': '0 - 最佳质量', '1': '1 - 平衡', '2': '2 - 最低延迟'},
        onChanged: (v) =>
            setState(() => _xaiOptimizeStreamingLatency = int.tryParse(v) ?? 0),
      ),
    ];
  }
}
