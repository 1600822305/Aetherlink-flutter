part of '../../voice_settings_page.dart';
// ignore_for_file: invalid_use_of_protected_member

/// Qwen TTS section (base + instruct variants).
extension _QwenSettings on _TtsProviderDetailPageState {
  List<Widget> _buildQwenVoice() {
    final isInstruct = _model.contains('instruct');
    return [
      // -- Model selection --
      _DropdownField(
        label: '模型',
        value: _model.isEmpty ? 'qwen3-tts-flash' : _model,
        items: const {
          'qwen3-tts-flash': 'Qwen3 TTS Flash - 基础语音合成',
          'qwen3-tts-instruct-flash': 'Qwen3 TTS Instruct Flash - 指令控制',
        },
        onChanged: (v) => setState(() => _model = v),
      ),
      const SizedBox(height: 12),
      // -- Voice selection --
      _DropdownField(
        label: '音色',
        value: _voice.isEmpty ? 'Cherry' : _voice,
        items: const {
          'Cherry': 'Cherry - 中文女声',
          'Serena': 'Serena - 中文女声',
          'Ethan': 'Ethan - 中文男声',
          'Chelsie': 'Chelsie - 中英双语女声',
          'Momo': 'Momo - 日语女声',
          'Vivian': 'Vivian - 中文女声',
          'Moon': 'Moon - 中文女声',
          'Maia': 'Maia - 中文女声',
          'Kai': 'Kai - 中文男声',
          'Nofish': 'Nofish - 中文男声',
          'Bella': 'Bella - 英文女声',
          'Jennifer': 'Jennifer - 英文女声',
          'Ryan': 'Ryan - 英文男声',
          'Katerina': 'Katerina - 俄语女声',
          'Aiden': 'Aiden - 英文男声',
          'Eldric Sage': 'Eldric Sage - 英文男声',
          'Mia': 'Mia - 英文女声',
          'Mochi': 'Mochi - 中文女声',
          'Bellona': 'Bellona - 英文女声',
          'Vincent': 'Vincent - 中文男声',
          'Bunny': 'Bunny - 中英双语女声',
          'Neil': 'Neil - 中英双语男声',
        },
        onChanged: (v) => setState(() => _voice = v),
      ),
      const SizedBox(height: 12),
      // -- Language selection --
      _DropdownField(
        label: '语言',
        value: _qwenLanguageType,
        items: const {
          'Auto': 'Auto - 自动检测',
          'Chinese': 'Chinese - 中文',
          'English': 'English - 英文',
          'Japanese': 'Japanese - 日语',
          'Korean': 'Korean - 韩语',
          'French': 'French - 法语',
          'German': 'German - 德语',
          'Italian': 'Italian - 意大利语',
          'Portuguese': 'Portuguese - 葡萄牙语',
          'Spanish': 'Spanish - 西班牙语',
          'Russian': 'Russian - 俄语',
        },
        onChanged: (v) => setState(() => _qwenLanguageType = v),
      ),
      const SizedBox(height: 12),
      // -- Instructions (only for instruct model) --
      if (isInstruct) ...[
        ModelFormField(
          label: '指令 (Instructions)',
          hint: '使用自然语言控制语音表现力，例如：用温柔缓慢的语气朗读...',
          controller: _qwenInstructionsCtrl,
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        _InlineToggle(
          label: '优化指令 (Optimize Instructions)',
          value: _qwenOptimizeInstructions,
          onChanged: (v) => setState(() => _qwenOptimizeInstructions = v),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }
}
