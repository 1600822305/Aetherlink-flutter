part of '../../voice_settings_page.dart';
// ignore_for_file: invalid_use_of_protected_member

/// SiliconFlow TTS voice/model selection section.
extension _SiliconFlowSettings on _TtsProviderDetailPageState {
  List<Widget> _buildSiliconFlowVoice() {
    final currentModel = _model.isEmpty ? kSiliconFlowModels.first.id : _model;
    final voices = kSiliconFlowVoices[currentModel] ?? [];
    final isMossTTSD = currentModel == 'fnlp/MOSS-TTSD-v0.5';
    return [
      // -- Model & Voice --
      _DropdownField(
        label: '模型',
        value: currentModel,
        items: {
          for (final m in kSiliconFlowModels)
            m.id: '${m.name} - ${m.description}',
        },
        onChanged: (v) => setState(() {
          _model = v;
          final modelVoices = kSiliconFlowVoices[v];
          if (modelVoices != null &&
              !modelVoices.any((voice) => voice.id == _voice)) {
            _voice = modelVoices.first.id;
          }
        }),
      ),
      const SizedBox(height: 12),
      _DropdownField(
        label: '语音',
        value: _voice.isEmpty
            ? (voices.isNotEmpty ? voices.first.id : '')
            : _voice,
        items: {for (final v in voices) v.id: '${v.name} - ${v.description}'},
        onChanged: (v) => setState(() => _voice = v),
      ),
      const SizedBox(height: 12),
      // -- Audio Format & Sample Rate --
      Row(
        children: [
          Expanded(
            child: _DropdownField(
              label: '音频格式',
              value: _audioFormat.isEmpty ? 'mp3' : _audioFormat,
              items: {for (final f in kSiliconFlowOutputFormats) f.id: f.name},
              onChanged: (v) => setState(() => _audioFormat = v),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DropdownField(
              label: '采样率',
              value: _sampleRate > 0 ? _sampleRate.toString() : '44100',
              items: {for (final s in kSiliconFlowSampleRates) s.id: s.name},
              onChanged: (v) =>
                  setState(() => _sampleRate = int.tryParse(v) ?? 44100),
            ),
          ),
        ],
      ),
      // -- MOSS-TTSD max_tokens --
      if (isMossTTSD) ...[
        const SizedBox(height: 12),
        _SliderRow(
          label: 'Max Tokens',
          value: _maxTokens.toDouble(),
          min: 256,
          max: 4096,
          divisions: 15,
          onChanged: (v) => setState(() => _maxTokens = v.round()),
        ),
      ],
    ];
  }
}
