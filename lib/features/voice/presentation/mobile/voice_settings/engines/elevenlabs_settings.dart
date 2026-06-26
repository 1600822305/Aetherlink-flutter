part of '../../voice_settings_page.dart';
// ignore_for_file: invalid_use_of_protected_member

/// ElevenLabs TTS voice/model selection section, including dynamic fetching.
extension _ElevenLabsSettings on _TtsProviderDetailPageState {
  List<Widget> _buildElevenLabsVoice() {
    return [
      // -- Model --
      _DropdownField(
        label: '模型',
        value: _model.isEmpty ? kElevenLabsModels.first.id : _model,
        items: {
          for (final m in kElevenLabsModels)
            m.id: '${m.name} - ${m.description}',
        },
        onChanged: (v) => setState(() => _model = v),
      ),
      const SizedBox(height: 12),
      // -- Voice (preset + dynamic) --
      _SelectorField(
        label: '语音',
        value: _voice,
        displayText: _voice.isEmpty
            ? '选择语音...'
            : _elRemoteVoices
                      .where((v) => v.id == _voice)
                      .map((v) => v.name)
                      .firstOrNull ??
                  kElevenLabsVoices
                      .where((v) => v.id == _voice)
                      .map((v) => v.name)
                      .firstOrNull ??
                  _voice,
        onTap: () async {
          // Fetch cloud voices if we have an API key and haven't yet.
          if (_elRemoteVoices.isEmpty &&
              !_elVoicesLoading &&
              _apiKeyCtrl.text.trim().isNotEmpty) {
            setState(() => _elVoicesLoading = true);
            final svc = NetworkTtsService();
            final voices = await svc.fetchElevenLabsVoices(_currentProvider());
            if (mounted) {
              setState(() {
                _elRemoteVoices = voices;
                _elVoicesLoading = false;
              });
            }
          }
          if (!mounted) return;
          // Build groups: remote voices by category, then preset fallback.
          final List<SelectorGroup> groups;
          if (_elRemoteVoices.isNotEmpty) {
            final byCategory = <String, List<SelectorItem>>{};
            for (final v in _elRemoteVoices) {
              final cat = v.category.isEmpty ? 'premade' : v.category;
              (byCategory[cat] ??= []).add(
                SelectorItem(key: v.id, label: v.name, subLabel: cat),
              );
            }
            groups = byCategory.entries
                .map((e) => SelectorGroup(name: e.key, items: e.value))
                .toList();
          } else {
            groups = buildPresetGroups('ElevenLabs 语音', kElevenLabsVoices);
          }
          final result = await FullScreenVoicePicker.show(
            context,
            title: '选择 ElevenLabs 语音',
            groups: groups,
            selectedKey: _voice,
          );
          if (result != null) setState(() => _voice = result);
        },
      ),
      const SizedBox(height: 12),
      // -- Output Format --
      _DropdownField(
        label: '输出格式',
        value: _outputFormat.isEmpty ? 'mp3_44100_128' : _outputFormat,
        items: {
          for (final f in kElevenLabsOutputFormats)
            f.id: '${f.name} - ${f.description}',
        },
        onChanged: (v) => setState(() => _outputFormat = v),
      ),
      const SizedBox(height: 12),
      // -- Voice Settings --
      _SliderRow(
        label: '稳定性',
        value: _stability,
        min: 0,
        max: 1,
        divisions: 20,
        onChanged: (v) => setState(() => _stability = v),
      ),
      _SliderRow(
        label: '相似度',
        value: _similarityBoost,
        min: 0,
        max: 1,
        divisions: 20,
        onChanged: (v) => setState(() => _similarityBoost = v),
      ),
      _SliderRow(
        label: '风格',
        value: _elStyle,
        min: 0,
        max: 1,
        divisions: 20,
        onChanged: (v) => setState(() => _elStyle = v),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('说话者增强'),
            Switch.adaptive(
              value: _useSpeakerBoost,
              onChanged: (v) => setState(() => _useSpeakerBoost = v),
            ),
          ],
        ),
      ),
    ];
  }
}
