part of '../../voice_settings_page.dart';
// ignore_for_file: invalid_use_of_protected_member

/// Azure TTS voice/prosody selection section, including dynamic voice fetching.
extension _AzureSettings on _TtsProviderDetailPageState {
  List<Widget> _buildAzureVoice() {
    return [
      // -- Voice (preset + dynamic) --
      _SelectorField(
        label: '语音',
        value: _voice,
        displayText: _voice.isEmpty
            ? '选择语音...'
            : _azureRemoteVoices
                      .where((v) => v.shortName == _voice)
                      .map(
                        (v) =>
                            '${v.localName.isNotEmpty ? v.localName : v.displayName} (${v.locale})',
                      )
                      .firstOrNull ??
                  kAzureVoices
                      .where((v) => v.id == _voice)
                      .map((v) => '${v.name} (${v.id})')
                      .firstOrNull ??
                  _voice,
        onTap: () async {
          // Fetch cloud voices if we have an API key and haven't yet.
          if (_azureRemoteVoices.isEmpty &&
              !_azureVoicesLoading &&
              _apiKeyCtrl.text.trim().isNotEmpty) {
            setState(() => _azureVoicesLoading = true);
            final svc = NetworkTtsService();
            final voices = await svc.fetchAzureVoices(_currentProvider());
            if (mounted) {
              setState(() {
                _azureRemoteVoices = voices;
                _azureVoicesLoading = false;
              });
            }
          }
          if (!mounted) return;
          // Build groups: remote voices by locale, or preset fallback.
          final List<SelectorGroup> groups;
          if (_azureRemoteVoices.isNotEmpty) {
            final byLocale = <String, List<SelectorItem>>{};
            for (final v in _azureRemoteVoices) {
              (byLocale[v.locale] ??= []).add(
                SelectorItem(
                  key: v.shortName,
                  label: v.localName.isNotEmpty ? v.localName : v.displayName,
                  subLabel: '${v.gender} · ${v.shortName}',
                ),
              );
            }
            // Sort: zh first, then en, then others.
            final sortedKeys = byLocale.keys.toList()
              ..sort((a, b) {
                if (a.startsWith('zh') && !b.startsWith('zh')) return -1;
                if (!a.startsWith('zh') && b.startsWith('zh')) return 1;
                if (a.startsWith('en') && !b.startsWith('en')) return -1;
                if (!a.startsWith('en') && b.startsWith('en')) return 1;
                return a.compareTo(b);
              });
            groups = sortedKeys
                .map((k) => SelectorGroup(name: k, items: byLocale[k]!))
                .toList();
          } else {
            // Group preset voices by language.
            final byLang = <String, List<SelectorItem>>{};
            for (final v in kAzureVoices) {
              final lang = v.language.isNotEmpty ? v.language : 'Other';
              (byLang[lang] ??= []).add(
                SelectorItem(
                  key: v.id,
                  label: v.name,
                  subLabel: '${v.description} · ${v.id}',
                ),
              );
            }
            groups = byLang.entries
                .map((e) => SelectorGroup(name: e.key, items: e.value))
                .toList();
          }
          final result = await FullScreenVoicePicker.show(
            context,
            title: '选择 Azure 语音',
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
        value: _azureOutputFormat.isEmpty
            ? 'audio-16khz-128kbitrate-mono-mp3'
            : _azureOutputFormat,
        items: {
          for (final f in kAzureOutputFormats)
            f.id: '${f.name} - ${f.description}',
        },
        onChanged: (v) => setState(() => _azureOutputFormat = v),
      ),
      const SizedBox(height: 12),
      // -- Prosody --
      _DropdownField(
        label: '语速',
        value: _azureRate,
        items: {for (final r in kAzureProsodyRates) r.id: r.name},
        onChanged: (v) => setState(() => _azureRate = v),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _DropdownField(
              label: '音调',
              value: _azurePitch,
              items: {for (final p in kAzureProsodyPitches) p.id: p.name},
              onChanged: (v) => setState(() => _azurePitch = v),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DropdownField(
              label: '音量',
              value: _azureVolume,
              items: {for (final p in kAzureProsodyVolumes) p.id: p.name},
              onChanged: (v) => setState(() => _azureVolume = v),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      // -- Express-as (style / role) --
      _DropdownField(
        label: '风格',
        value: _azureStyle,
        items: {
          for (final s in kAzureStyles) s.id: '${s.name} - ${s.description}',
        },
        onChanged: (v) => setState(() => _azureStyle = v),
      ),
      if (_azureStyle.isNotEmpty) ...[
        const SizedBox(height: 12),
        _SliderRow(
          label: '风格强度',
          value: _azureStyleDegree,
          min: 0.01,
          max: 2.0,
          divisions: 20,
          onChanged: (v) => setState(() => _azureStyleDegree = v),
        ),
        const SizedBox(height: 12),
        _DropdownField(
          label: '角色扮演',
          value: _azureRole,
          items: {
            for (final r in kAzureRoles) r.id: '${r.name} - ${r.description}',
          },
          onChanged: (v) => setState(() => _azureRole = v),
        ),
      ],
    ];
  }
}
