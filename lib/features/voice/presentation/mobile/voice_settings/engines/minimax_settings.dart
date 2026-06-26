part of '../../voice_settings_page.dart';
// ignore_for_file: invalid_use_of_protected_member

/// MiniMax TTS voice/model selection section, including dynamic voice fetching.
extension _MiniMaxSettings on _TtsProviderDetailPageState {
  Future<void> _fetchMiniMaxRemoteVoices() async {
    try {
      final provider = _currentProvider();
      final svc = NetworkTtsService();
      final voices = await svc.fetchMiniMaxVoices(provider);
      if (mounted) {
        setState(() => _miniMaxRemoteVoices = voices);
      }
    } catch (_) {
      // Silently fall back to static list.
    }
  }

  List<SelectorGroup> _buildMiniMaxRemoteGroups() {
    final systemVoices = _miniMaxRemoteVoices
        .where((v) => v.category == 'system')
        .toList();
    final clonedVoices = _miniMaxRemoteVoices
        .where((v) => v.category == 'cloned')
        .toList();
    final genVoices = _miniMaxRemoteVoices
        .where((v) => v.category == 'generated')
        .toList();
    final groups = <SelectorGroup>[];
    if (systemVoices.isNotEmpty) {
      groups.add(
        SelectorGroup(
          name: '系统音色 (${systemVoices.length})',
          items: systemVoices
              .map(
                (v) => SelectorItem(
                  key: v.id,
                  label: v.name,
                  subLabel: v.description,
                ),
              )
              .toList(),
        ),
      );
    }
    if (clonedVoices.isNotEmpty) {
      groups.add(
        SelectorGroup(
          name: '克隆音色 (${clonedVoices.length})',
          items: clonedVoices
              .map(
                (v) => SelectorItem(
                  key: v.id,
                  label: v.name,
                  subLabel: v.description,
                ),
              )
              .toList(),
        ),
      );
    }
    if (genVoices.isNotEmpty) {
      groups.add(
        SelectorGroup(
          name: '生成音色 (${genVoices.length})',
          items: genVoices
              .map(
                (v) => SelectorItem(
                  key: v.id,
                  label: v.name,
                  subLabel: v.description,
                ),
              )
              .toList(),
        ),
      );
    }
    return groups;
  }

  List<Widget> _buildMiniMaxVoice() {
    return [
      // -- Model & Voice --
      Row(
        children: [
          Expanded(
            child: _DropdownField(
              label: '模型',
              value: _model.isEmpty ? kMiniMaxModels.first.id : _model,
              items: {for (final m in kMiniMaxModels) m.id: m.name},
              onChanged: (v) => setState(() => _model = v),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SelectorField(
              label: '音色',
              value: _voice,
              displayText: _voice.isEmpty
                  ? '选择...'
                  : _miniMaxRemoteVoices
                            .where((v) => v.id == _voice)
                            .map((v) => v.name)
                            .firstOrNull ??
                        kMiniMaxVoices
                            .where((v) => v.id == _voice)
                            .map((v) => v.name)
                            .firstOrNull ??
                        _voice,
              onTap: () async {
                // Try to fetch remote voices if API key is present and not yet fetched.
                var groups = buildPresetGroups('MiniMax 音色', kMiniMaxVoices);
                if (_miniMaxRemoteVoices.isNotEmpty) {
                  groups = _buildMiniMaxRemoteGroups();
                } else if (_apiKeyCtrl.text.trim().isNotEmpty) {
                  await _fetchMiniMaxRemoteVoices();
                  if (_miniMaxRemoteVoices.isNotEmpty) {
                    groups = _buildMiniMaxRemoteGroups();
                  }
                }
                if (!mounted) return;
                final result = await FullScreenVoicePicker.show(
                  context,
                  title: '选择 MiniMax 音色',
                  groups: groups,
                  selectedKey: _voice,
                );
                if (result != null) setState(() => _voice = result);
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      // -- Emotion & Language Boost --
      Row(
        children: [
          Expanded(
            child: _SelectorField(
              label: '情感',
              value: _emotion,
              displayText: _emotion.isEmpty
                  ? '默认'
                  : kMiniMaxEmotions
                            .where((e) => e.id == _emotion)
                            .map((e) => e.name)
                            .firstOrNull ??
                        _emotion,
              onTap: () async {
                final result = await FullScreenVoicePicker.show(
                  context,
                  title: '选择情感风格',
                  groups: buildPresetGroups('MiniMax 情感', kMiniMaxEmotions),
                  selectedKey: _emotion,
                  allowEmpty: true,
                );
                if (result != null) setState(() => _emotion = result);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DropdownField(
              label: '语言增强',
              value: _languageBoost.isEmpty ? 'auto' : _languageBoost,
              items: {for (final l in kMiniMaxLanguageBoost) l.id: l.name},
              onChanged: (v) => setState(() => _languageBoost = v),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      // -- Audio Settings --
      Row(
        children: [
          Expanded(
            child: _DropdownField(
              label: '音频格式',
              value: _audioFormat.isEmpty ? 'mp3' : _audioFormat,
              items: {for (final f in kMiniMaxAudioFormats) f.id: f.name},
              onChanged: (v) => setState(() => _audioFormat = v),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DropdownField(
              label: '采样率',
              value: _sampleRate.toString(),
              items: {for (final s in kMiniMaxSampleRates) s.id: s.name},
              onChanged: (v) =>
                  setState(() => _sampleRate = int.tryParse(v) ?? 32000),
            ),
          ),
        ],
      ),
    ];
  }
}
