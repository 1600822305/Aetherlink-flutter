part of '../../voice_settings_page.dart';
// ignore_for_file: invalid_use_of_protected_member

/// Fish Audio TTS section — model, reference voice, sampling / prosody /
/// output-format / chunking parameters of the `POST /v1/tts` API.
extension _FishAudioSettings on _TtsProviderDetailPageState {
  List<Widget> _buildFishAudioVoice() {
    return [
      // -- Model (sent as the `model` request header) --
      _DropdownField(
        label: '模型',
        value: _model.isEmpty ? 's2.1-pro-free' : _model,
        items: const {
          's2.1-pro-free': 'S2.1 Pro Free - 免费档',
          's2.1-pro': 'S2.1 Pro - 最新旗舰',
          's2-pro': 'S2 Pro - 支持多说话人',
          's1': 'S1 - 经典模型',
        },
        onChanged: (v) => setState(() => _model = v),
      ),
      const SizedBox(height: 12),
      // -- Reference voice (voice model ID from Fish Audio library) --
      ModelFormField(
        label: '音色 Reference ID',
        hint: '输入语音模型 ID（留空使用默认音色）',
        controller: _fishReferenceIdCtrl,
      ),
      const SizedBox(height: 12),
      // -- Zero-shot cloning: inline reference audio + transcript.
      //    When set, it takes precedence over reference_id and the request is
      //    sent as MessagePack.
      ..._buildFishReferenceAudio(),
      // -- Sampling --
      _SliderRow(
        label: '温度',
        value: _fishTemperature,
        min: 0.0,
        max: 1.0,
        divisions: 20,
        onChanged: (v) => setState(() => _fishTemperature = v),
      ),
      _SliderRow(
        label: 'Top P',
        value: _fishTopP,
        min: 0.0,
        max: 1.0,
        divisions: 20,
        onChanged: (v) => setState(() => _fishTopP = v),
      ),
      // -- Prosody volume (dB) --
      _SliderRow(
        label: '音量 (dB)',
        value: _fishVolume,
        min: -20,
        max: 20,
        divisions: 40,
        onChanged: (v) => setState(() => _fishVolume = v),
      ),
      _InlineToggle(
        label: '响度归一化 (S2-Pro)',
        value: _fishNormalizeLoudness,
        onChanged: (v) => setState(() => _fishNormalizeLoudness = v),
      ),
      const SizedBox(height: 12),
      // -- Output format --
      _DropdownField(
        label: '音频格式',
        value: _fishFormat,
        items: const {
          'mp3': 'MP3 - 通用压缩',
          'wav': 'WAV - 无损音频',
          'pcm': 'PCM - 原始音频流',
          'opus': 'Opus - 低带宽',
        },
        onChanged: (v) => setState(() => _fishFormat = v),
      ),
      const SizedBox(height: 12),
      _DropdownField(
        label: '采样率',
        value: _fishSampleRate.toString(),
        items: const {
          '0': '默认（MP3/WAV 44100，Opus 48000）',
          '8000': '8000 Hz (WAV/PCM)',
          '16000': '16000 Hz (WAV/PCM)',
          '24000': '24000 Hz (WAV/PCM)',
          '32000': '32000 Hz',
          '44100': '44100 Hz',
          '48000': '48000 Hz (Opus)',
        },
        onChanged: (v) =>
            setState(() => _fishSampleRate = int.tryParse(v) ?? 0),
      ),
      if (_fishFormat == 'mp3') ...[
        const SizedBox(height: 12),
        _DropdownField(
          label: 'MP3 比特率',
          value: _fishMp3Bitrate.toString(),
          items: const {
            '64': '64 kbps',
            '128': '128 kbps (默认)',
            '192': '192 kbps',
          },
          onChanged: (v) =>
              setState(() => _fishMp3Bitrate = int.tryParse(v) ?? 128),
        ),
      ],
      if (_fishFormat == 'opus') ...[
        const SizedBox(height: 12),
        _DropdownField(
          label: 'Opus 比特率',
          value: _fishOpusBitrate.toString(),
          items: const {
            '-1000': '自动',
            '24000': '24 kbps',
            '32000': '32 kbps (默认)',
            '48000': '48 kbps',
            '64000': '64 kbps',
          },
          onChanged: (v) =>
              setState(() => _fishOpusBitrate = int.tryParse(v) ?? -1000),
        ),
      ],
      const SizedBox(height: 12),
      // -- Latency mode --
      _DropdownField(
        label: '延迟模式',
        value: _fishLatency,
        items: const {
          'normal': 'Normal - 最佳质量',
          'balanced': 'Balanced - 平衡',
          'low': 'Low - 最低延迟',
        },
        onChanged: (v) => setState(() => _fishLatency = v),
      ),
      const SizedBox(height: 12),
      // -- Text normalization --
      _InlineToggle(
        label: '文本规范化（中英文数字）',
        value: _fishNormalize,
        onChanged: (v) => setState(() => _fishNormalize = v),
      ),
      const SizedBox(height: 8),
      // -- Chunking --
      _SliderRow(
        label: '分段长度',
        value: _fishChunkLength.toDouble(),
        min: 100,
        max: 300,
        divisions: 20,
        onChanged: (v) => setState(() => _fishChunkLength = v.round()),
      ),
      _SliderRow(
        label: '最小分段',
        value: _fishMinChunkLength.toDouble(),
        min: 0,
        max: 100,
        divisions: 20,
        onChanged: (v) => setState(() => _fishMinChunkLength = v.round()),
      ),
      _InlineToggle(
        label: '基于前文保持声音一致',
        value: _fishConditionOnPreviousChunks,
        onChanged: (v) => setState(() => _fishConditionOnPreviousChunks = v),
      ),
      const SizedBox(height: 8),
      // -- Generation limits --
      _SliderRow(
        label: '最大 Token',
        value: _fishMaxNewTokens.toDouble(),
        min: 256,
        max: 4096,
        divisions: 15,
        onChanged: (v) => setState(() => _fishMaxNewTokens = v.round()),
      ),
      _SliderRow(
        label: '重复惩罚',
        value: _fishRepetitionPenalty,
        min: 1.0,
        max: 2.0,
        divisions: 20,
        onChanged: (v) => setState(() => _fishRepetitionPenalty = v),
      ),
      _SliderRow(
        label: '提前停止阈值',
        value: _fishEarlyStopThreshold,
        min: 0.0,
        max: 1.0,
        divisions: 20,
        onChanged: (v) => setState(() => _fishEarlyStopThreshold = v),
      ),
    ];
  }

  /// Zero-shot voice cloning: pick a local reference audio (WAV/MP3/FLAC,
  /// ideally 10-30s of clear speech) plus its exact transcript.
  List<Widget> _buildFishReferenceAudio() {
    final hasAudio = _fishReferenceAudio.isNotEmpty;
    return [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(
          '零样本克隆参考音频',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pickFishReferenceAudio,
              icon: const Icon(LucideIcons.fileAudio, size: 15),
              label: Text(
                hasAudio
                    ? '已选择（${(_fishReferenceAudio.length * 3 ~/ 4 / 1024).round()} KB）'
                    : '选择参考音频（10-30 秒清晰人声）',
                style: const TextStyle(fontSize: 12.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (hasAudio) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: '清除',
              icon: const Icon(LucideIcons.x, size: 16),
              onPressed: () => setState(() => _fishReferenceAudio = ''),
            ),
          ],
        ],
      ),
      if (hasAudio) ...[
        const SizedBox(height: 8),
        ModelFormField(
          label: '参考音频转写文本',
          hint: '输入参考音频中说的原文（转写越准克隆效果越好）',
          controller: _fishReferenceTextCtrl,
          maxLines: 2,
        ),
      ],
      const SizedBox(height: 12),
    ];
  }

  Future<void> _pickFishReferenceAudio() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['wav', 'mp3', 'flac'],
    );
    final file = result?.files.firstOrNull;
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 20 * 1024 * 1024) {
      if (mounted) {
        AppToast.warning(context, '音频超过 20 MB，请换更短的样本');
      }
      return;
    }
    if (!mounted) return;
    setState(() => _fishReferenceAudio = base64Encode(bytes));
  }
}
