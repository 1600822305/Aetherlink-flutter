part of '../../voice_settings_page.dart';
// ignore_for_file: invalid_use_of_protected_member

/// OpenAI TTS voice/model selection section.
extension _OpenAiSettings on _TtsProviderDetailPageState {
  List<Widget> _buildOpenAIVoice() {
    final isGpt4oMiniTts = _model.startsWith('gpt-4o-mini-tts');
    return [
      _DropdownField(
        label: '模型',
        value: _model,
        items: {
          for (final m in kOpenAIModels) m.id: '${m.name} - ${m.description}',
        },
        onChanged: (v) => setState(() => _model = v),
      ),
      const SizedBox(height: 12),
      _DropdownField(
        label: '语音',
        value: _voice.isEmpty ? kOpenAIVoices.first.id : _voice,
        items: {
          for (final v in kOpenAIVoices) v.id: '${v.name} - ${v.description}',
        },
        onChanged: (v) => setState(() => _voice = v),
      ),
      const SizedBox(height: 12),
      _DropdownField(
        label: '输出格式',
        value: _outputFormat.isEmpty ? 'mp3' : _outputFormat,
        items: {
          for (final f in kOpenAIFormats) f.id: '${f.name} - ${f.description}',
        },
        onChanged: (v) => setState(() => _outputFormat = v),
      ),
      if (isGpt4oMiniTts) ...[
        const SizedBox(height: 12),
        ModelFormField(
          label: 'Instructions (语音风格指令)',
          hint: '例如：Speak in a cheerful tone / 用温柔的语气说话',
          controller: _instructionsCtrl,
          maxLines: 3,
        ),
      ],
    ];
  }
}
