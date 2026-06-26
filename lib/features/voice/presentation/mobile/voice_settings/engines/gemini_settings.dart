part of '../../voice_settings_page.dart';
// ignore_for_file: invalid_use_of_protected_member

/// Gemini TTS voice/model selection section (single- or multi-speaker).
extension _GeminiSettings on _TtsProviderDetailPageState {
  List<Widget> _buildGeminiVoice() {
    return [
      _DropdownField(
        label: '模型',
        value: _model.isEmpty ? kGeminiModels.first.id : _model,
        items: {for (final m in kGeminiModels) m.id: m.name},
        onChanged: (v) => setState(() => _model = v),
      ),
      const SizedBox(height: 12),
      // -- Multi-speaker toggle --
      _InlineToggle(
        label: '多说话人模式',
        value: _useMultiSpeaker,
        onChanged: (v) => setState(() => _useMultiSpeaker = v),
      ),
      const SizedBox(height: 12),
      if (!_useMultiSpeaker) ...[
        // -- Single speaker voice selection --
        _SelectorField(
          label: '语音',
          value: _voiceName,
          displayText: _voiceName.isEmpty ? '选择语音...' : _voiceName,
          onTap: () async {
            final result = await FullScreenVoicePicker.show(
              context,
              title: '选择 Gemini 语音',
              groups: buildPresetGroups('Gemini 语音', kGeminiVoices),
              selectedKey: _voiceName,
            );
            if (result != null) setState(() => _voiceName = result);
          },
        ),
      ] else ...[
        // -- Multi-speaker config (up to 2 speakers) --
        ModelFormField(
          label: '说话人 1 名称',
          hint: '例如 Joe（需和文本中的名称一致）',
          controller: _speaker1NameCtrl,
        ),
        const SizedBox(height: 8),
        _SelectorField(
          label: '说话人 1 语音',
          value: _speaker1Voice,
          displayText: _speaker1Voice.isEmpty ? '选择语音...' : _speaker1Voice,
          onTap: () async {
            final result = await FullScreenVoicePicker.show(
              context,
              title: '说话人 1 语音',
              groups: buildPresetGroups('Gemini 语音', kGeminiVoices),
              selectedKey: _speaker1Voice,
            );
            if (result != null) setState(() => _speaker1Voice = result);
          },
        ),
        const SizedBox(height: 12),
        ModelFormField(
          label: '说话人 2 名称',
          hint: '例如 Jane（需和文本中的名称一致）',
          controller: _speaker2NameCtrl,
        ),
        const SizedBox(height: 8),
        _SelectorField(
          label: '说话人 2 语音',
          value: _speaker2Voice,
          displayText: _speaker2Voice.isEmpty ? '选择语音...' : _speaker2Voice,
          onTap: () async {
            final result = await FullScreenVoicePicker.show(
              context,
              title: '说话人 2 语音',
              groups: buildPresetGroups('Gemini 语音', kGeminiVoices),
              selectedKey: _speaker2Voice,
            );
            if (result != null) setState(() => _speaker2Voice = result);
          },
        ),
      ],
      const SizedBox(height: 12),
      // -- Style prompt --
      ModelFormField(
        label: '风格提示词 (Style Prompt)',
        hint: '例如：Say in a cheerful tone / 用温柔低语的方式说',
        controller: _stylePromptCtrl,
        maxLines: 3,
      ),
    ];
  }
}
