part of '../voice_settings_page.dart';

// ASR (speech-to-text) provider settings: card grid tab + per-provider detail.

Map<AsrProviderKind, _ServiceMeta> _asrServiceMeta() => {
  AsrProviderKind.system: const _ServiceMeta(
    providerId: 'custom',
    color: Color(0xFF64748B),
    name: '系统语音识别',
    description: '使用设备内置语音识别引擎',
    features: ['免费', '离线'],
    status: '免费',
  ),
  AsrProviderKind.openaiRealtime: const _ServiceMeta(
    providerId: 'openai',
    color: Color(0xFF10B981),
    name: 'OpenAI Realtime',
    description: 'OpenAI 实时语音识别 (WebSocket)',
    features: ['实时', '高精度'],
    status: '高级',
  ),
  AsrProviderKind.dashscope: const _ServiceMeta(
    providerId: 'qwen',
    color: Color(0xFF615CED),
    name: 'DashScope ASR',
    description: '阿里通义 Qwen 实时语音识别 (WebSocket)',
    features: ['实时', '多语言', '热词'],
    status: '高级',
  ),
  AsrProviderKind.whisper: const _ServiceMeta(
    providerId: 'openai',
    color: Color(0xFF6366F1),
    name: 'OpenAI Whisper',
    description: '高精度离线友好语音转文字',
    features: ['高精度', '多语言'],
    status: '高级',
  ),
};

class _AsrTab extends StatelessWidget {
  const _AsrTab({required this.settings, required this.ctrl});
  final VoiceSettings settings;
  final VoiceSettingsController ctrl;

  @override
  Widget build(BuildContext context) {
    final meta = _asrServiceMeta();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        for (final kind in AsrProviderKind.values) ...[
          Builder(
            builder: (ctx) {
              final preset = defaultAsrProvider(kind);
              final configured = settings.asrProviders
                  .where((p) => p.kind == kind)
                  .toList();
              final provider = configured.isNotEmpty
                  ? configured.first
                  : preset;
              final isActive = settings.activeAsrProviderId == provider.id;
              final m = meta[kind]!;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ServiceCard(
                  providerId: m.providerId,
                  color: m.color,
                  name: m.name,
                  description: m.description,
                  features: m.features,
                  status: m.status,
                  isActive: isActive,
                  onTap: () => _pushDetail(ctx, kind, provider),
                  onLongPress: () => ctrl.setActiveAsrProvider(provider.id),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  void _pushDetail(
    BuildContext context,
    AsrProviderKind kind,
    AsrProviderSetting provider,
  ) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) =>
            _AsrProviderDetailPage(kind: kind, provider: provider),
      ),
    );
  }
}

class _AsrProviderDetailPage extends ConsumerStatefulWidget {
  const _AsrProviderDetailPage({required this.kind, required this.provider});

  final AsrProviderKind kind;
  final AsrProviderSetting provider;

  @override
  ConsumerState<_AsrProviderDetailPage> createState() =>
      _AsrProviderDetailPageState();
}

class _AsrProviderDetailPageState
    extends ConsumerState<_AsrProviderDetailPage> {
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _baseUrlCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _wsUrlCtrl;
  late final TextEditingController _languageCtrl;
  late final TextEditingController _promptCtrl;
  late final TextEditingController _corpusCtrl;
  late bool _enabled;
  late double _vadThreshold;
  late int _silenceDurationMs;
  late int _prefixPaddingMs;
  late double _temperature;
  late String _realtimeDelay;
  late int _sampleRate;
  late String _inputAudioFormat;
  late bool _useVad;

  @override
  void initState() {
    super.initState();
    final p = widget.provider;
    _apiKeyCtrl = TextEditingController(text: p.apiKey);
    _baseUrlCtrl = TextEditingController(text: p.baseUrl);
    _modelCtrl = TextEditingController(text: p.model);
    _wsUrlCtrl = TextEditingController(text: p.websocketUrl);
    _languageCtrl = TextEditingController(text: p.language);
    _promptCtrl = TextEditingController(text: p.prompt);
    _corpusCtrl = TextEditingController(text: p.corpusText);
    // "启用此服务" reflects whether this is the single active ASR provider.
    _enabled =
        ref.read(voiceSettingsControllerProvider).activeAsrProviderId == p.id;
    _vadThreshold = p.vadThreshold;
    _silenceDurationMs = p.silenceDurationMs;
    _prefixPaddingMs = p.prefixPaddingMs;
    _temperature = p.temperature;
    _realtimeDelay = p.realtimeDelay;
    _sampleRate = p.sampleRate;
    _inputAudioFormat = p.inputAudioFormat.isNotEmpty
        ? p.inputAudioFormat
        : 'pcm';
    _useVad = p.useVad;
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _baseUrlCtrl.dispose();
    _modelCtrl.dispose();
    _wsUrlCtrl.dispose();
    _languageCtrl.dispose();
    _promptCtrl.dispose();
    _corpusCtrl.dispose();
    super.dispose();
  }

  /// Persists the current form values. Called automatically when leaving the
  /// page (back button or system back gesture).
  void _persist() {
    final updated = widget.provider.copyWith(
      enabled: _enabled,
      apiKey: _apiKeyCtrl.text.trim(),
      baseUrl: _baseUrlCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      websocketUrl: _wsUrlCtrl.text.trim(),
      language: _languageCtrl.text.trim(),
      prompt: _promptCtrl.text.trim(),
      corpusText: _corpusCtrl.text.trim(),
      vadThreshold: _vadThreshold,
      silenceDurationMs: _silenceDurationMs,
      prefixPaddingMs: _prefixPaddingMs,
      temperature: _temperature,
      realtimeDelay: _realtimeDelay,
      sampleRate: _sampleRate,
      inputAudioFormat: _inputAudioFormat,
      useVad: _useVad,
    );
    final notifier = ref.read(voiceSettingsControllerProvider.notifier);
    notifier.updateAsrProvider(updated);
    // Enabling makes this the single active ASR provider; disabling the
    // currently-active provider falls back to the system engine.
    if (_enabled) {
      notifier.setActiveAsrProvider(updated.id);
    } else if (ref.read(voiceSettingsControllerProvider).activeAsrProviderId ==
        updated.id) {
      notifier.setActiveAsrProvider('system');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSystem = widget.kind == AsrProviderKind.system;
    final isRealtime = widget.kind == AsrProviderKind.openaiRealtime;
    final isDashscope = widget.kind == AsrProviderKind.dashscope;
    final isWhisper = widget.kind == AsrProviderKind.whisper;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _persist();
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: ModelSettingsAppBar(
          title: defaultAsrProvider(widget.kind).name,
          onBack: () => Navigator.of(context).maybePop(),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              // Single card (matching Web pattern)
              ModelSettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InlineToggle(
                      label: '启用此服务',
                      value: _enabled,
                      onChanged: (v) => setState(() => _enabled = v),
                    ),
                    if (isSystem) ...[
                      Divider(height: 24, color: theme.dividerColor),
                      ModelFormField(
                        label: '识别语言',
                        hint: '如 zh_CN、en_US（留空自动检测）',
                        controller: _languageCtrl,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '使用设备内置语音识别引擎，无需 API Key。'
                        '识别语言留空时自动使用系统语言。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ],
                    if (!isSystem) ...[
                      Divider(height: 24, color: theme.dividerColor),
                      ModelFormField(
                        label: 'API Key',
                        hint: '输入 API 密钥',
                        controller: _apiKeyCtrl,
                        obscureText: true,
                      ),
                      if (!isRealtime && !isDashscope) ...[
                        const SizedBox(height: 12),
                        ModelFormField(
                          label: 'Base URL',
                          hint: '输入服务地址',
                          controller: _baseUrlCtrl,
                        ),
                      ],
                      if (isRealtime || isDashscope) ...[
                        const SizedBox(height: 12),
                        ModelFormField(
                          label: 'WebSocket URL',
                          hint: '输入 WebSocket 地址',
                          controller: _wsUrlCtrl,
                        ),
                      ],
                      // Model selector
                      const SizedBox(height: 12),
                      if (isWhisper)
                        _DropdownRow(
                          label: '模型',
                          value: _modelCtrl.text.isEmpty
                              ? 'whisper-1'
                              : _modelCtrl.text,
                          items: const [
                            ('whisper-1', 'whisper-1'),
                            ('gpt-4o-transcribe', 'gpt-4o-transcribe'),
                            (
                              'gpt-4o-mini-transcribe',
                              'gpt-4o-mini-transcribe',
                            ),
                          ],
                          onChanged: (v) => setState(() => _modelCtrl.text = v),
                        )
                      else if (isRealtime)
                        _DropdownRow(
                          label: '模型',
                          value: _modelCtrl.text.isEmpty
                              ? 'gpt-4o-transcribe'
                              : _modelCtrl.text,
                          items: const [
                            ('gpt-4o-transcribe', 'gpt-4o-transcribe'),
                            (
                              'gpt-4o-mini-transcribe',
                              'gpt-4o-mini-transcribe',
                            ),
                            ('gpt-realtime-whisper', 'gpt-realtime-whisper'),
                          ],
                          onChanged: (v) => setState(() => _modelCtrl.text = v),
                        )
                      else if (isDashscope)
                        ModelFormField(
                          label: '模型',
                          hint: 'qwen3-asr-flash-realtime',
                          controller: _modelCtrl,
                        )
                      else
                        ModelFormField(
                          label: '模型',
                          hint: '输入模型名称',
                          controller: _modelCtrl,
                        ),
                      const SizedBox(height: 12),
                      ModelFormField(
                        label: '识别语言',
                        hint: '如 zh、en（留空自动检测）',
                        controller: _languageCtrl,
                      ),
                      // Prompt (Whisper + Realtime)
                      if (isWhisper || isRealtime) ...[
                        const SizedBox(height: 12),
                        ModelFormField(
                          label: 'Prompt（提示词）',
                          hint: '引导转录风格或专业术语',
                          controller: _promptCtrl,
                          maxLines: 2,
                        ),
                      ],
                      if (isRealtime) ...[
                        Divider(height: 24, color: theme.dividerColor),
                        // Delay selector (for gpt-realtime-whisper)
                        _DropdownRow(
                          label: '延迟/精度',
                          value: _realtimeDelay.isEmpty
                              ? 'medium'
                              : _realtimeDelay,
                          items: const [
                            ('minimal', 'minimal（最低延迟）'),
                            ('low', 'low（低延迟）'),
                            ('medium', 'medium（平衡）'),
                            ('high', 'high（高精度）'),
                            ('xhigh', 'xhigh（最高精度）'),
                          ],
                          onChanged: (v) => setState(() => _realtimeDelay = v),
                        ),
                        const SizedBox(height: 8),
                        _SliderRow(
                          label: 'VAD 阈值',
                          value: _vadThreshold,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          onChanged: (v) => setState(() => _vadThreshold = v),
                        ),
                        _SliderRow(
                          label: '静默时间 (ms)',
                          value: _silenceDurationMs.toDouble(),
                          min: 100,
                          max: 2000,
                          divisions: 19,
                          onChanged: (v) =>
                              setState(() => _silenceDurationMs = v.round()),
                        ),
                        _SliderRow(
                          label: '前置缓冲 (ms)',
                          value: _prefixPaddingMs.toDouble(),
                          min: 0,
                          max: 1000,
                          divisions: 20,
                          onChanged: (v) =>
                              setState(() => _prefixPaddingMs = v.round()),
                        ),
                      ],
                      if (isDashscope) ...[
                        Divider(height: 24, color: theme.dividerColor),
                        ModelFormField(
                          label: '热词/上下文（corpus）',
                          hint: '提供专业术语或上下文以提升识别准确度',
                          controller: _corpusCtrl,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        _DropdownRow(
                          label: '采样率',
                          value: _sampleRate.toString(),
                          items: const [
                            ('16000', '16000 Hz'),
                            ('8000', '8000 Hz'),
                          ],
                          onChanged: (v) =>
                              setState(() => _sampleRate = int.parse(v)),
                        ),
                        const SizedBox(height: 12),
                        _DropdownRow(
                          label: '音频格式',
                          value: _inputAudioFormat,
                          items: const [('pcm', 'PCM'), ('opus', 'Opus')],
                          onChanged: (v) =>
                              setState(() => _inputAudioFormat = v),
                        ),
                        Divider(height: 24, color: theme.dividerColor),
                        _InlineToggle(
                          label: '自动断句 (VAD)',
                          value: _useVad,
                          onChanged: (v) => setState(() => _useVad = v),
                        ),
                        if (_useVad) ...[
                          const SizedBox(height: 8),
                          _SliderRow(
                            label: 'VAD 阈值',
                            value: _vadThreshold,
                            min: -1.0,
                            max: 1.0,
                            divisions: 40,
                            onChanged: (v) => setState(() => _vadThreshold = v),
                          ),
                          _SliderRow(
                            label: '静默时间 (ms)',
                            value: _silenceDurationMs.toDouble(),
                            min: 200,
                            max: 6000,
                            divisions: 58,
                            onChanged: (v) =>
                                setState(() => _silenceDurationMs = v.round()),
                          ),
                        ],
                      ],
                      if (isWhisper) ...[
                        Divider(height: 24, color: theme.dividerColor),
                        _SliderRow(
                          label: 'Temperature',
                          value: _temperature,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          onChanged: (v) => setState(() => _temperature = v),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
