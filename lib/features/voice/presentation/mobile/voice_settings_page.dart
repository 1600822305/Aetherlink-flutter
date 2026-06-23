import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/features/voice/application/voice_settings_controller.dart';
import 'package:aetherlink_flutter/features/voice/domain/asr_provider_setting.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_provider_setting.dart';
import 'package:aetherlink_flutter/features/voice/domain/voice_settings.dart';

// ---------------------------------------------------------------------------
// 2nd-level page: Dual-tab (TTS / ASR) provider list
// ---------------------------------------------------------------------------

class VoiceSettingsPage extends ConsumerStatefulWidget {
  const VoiceSettingsPage({super.key});

  @override
  ConsumerState<VoiceSettingsPage> createState() => _VoiceSettingsPageState();
}

class _VoiceSettingsPageState extends ConsumerState<VoiceSettingsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(voiceSettingsControllerProvider);
    final ctrl = ref.read(voiceSettingsControllerProvider.notifier);

    return Scaffold(
      appBar: ModelSettingsAppBar(
        title: '语音功能',
        onBack: () => context.canPop()
            ? context.pop()
            : context.go(AppRouter.settingsPath),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(42),
          child: _TabHeader(controller: _tabCtrl),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // ---- TTS tab ----
          _TtsTab(settings: settings, ctrl: ctrl),
          // ---- ASR tab ----
          _AsrTab(settings: settings, ctrl: ctrl),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab header — compact pill-style segmented control
// ---------------------------------------------------------------------------

class _TabHeader extends StatelessWidget {
  const _TabHeader({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: theme.colorScheme.onSurface,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(
            height: 32,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.volume2, size: 15),
                SizedBox(width: 5),
                Text('语音合成'),
              ],
            ),
          ),
          Tab(
            height: 32,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.mic, size: 15),
                SizedBox(width: 5),
                Text('语音识别'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TTS tab content
// ---------------------------------------------------------------------------

class _TtsTab extends StatelessWidget {
  const _TtsTab({required this.settings, required this.ctrl});
  final VoiceSettings settings;
  final VoiceSettingsController ctrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        // Global TTS toggle + speed
        _CompactCard(
          children: [
            _CompactToggle(
              icon: LucideIcons.volume2,
              accent: const Color(0xFF06B6D4),
              label: '启用语音合成',
              value: settings.enableTts,
              onChanged: ctrl.setEnableTts,
            ),
            Divider(height: 1, color: theme.dividerColor),
            _CompactSlider(
              icon: LucideIcons.gauge,
              accent: const Color(0xFF8B5CF6),
              label: '播放速度',
              value: settings.defaultSpeed,
              min: 0.5,
              max: 2.0,
              divisions: 6,
              valueLabel: '${settings.defaultSpeed}x',
              onChanged: ctrl.setDefaultSpeed,
            ),
          ],
        ),
        const SizedBox(height: 10),
        // TTS provider list
        _CompactCard(
          children: [
            for (final kind in TtsProviderKind.values) ...[
              if (kind != TtsProviderKind.values.first)
                Divider(height: 1, indent: 48, color: theme.dividerColor),
              Builder(builder: (ctx) {
                final preset = defaultTtsProvider(kind);
                final configured = settings.ttsProviders
                    .where((p) => p.kind == kind)
                    .toList();
                final provider =
                    configured.isNotEmpty ? configured.first : preset;
                final isActive =
                    settings.activeTtsProviderId == provider.id;

                return _ProviderTile(
                  icon: _ttsIcon(kind),
                  accent: _ttsAccent(kind),
                  name: preset.name,
                  isActive: isActive,
                  onTap: () => _pushDetail(ctx, kind, provider),
                  onLongPress: () => ctrl.setActiveTtsProvider(provider.id),
                );
              }),
            ],
          ],
        ),
      ],
    );
  }

  void _pushDetail(
    BuildContext context,
    TtsProviderKind kind,
    TtsProviderSetting provider,
  ) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) =>
            _TtsProviderDetailPage(kind: kind, provider: provider),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  static IconData _ttsIcon(TtsProviderKind kind) => switch (kind) {
    TtsProviderKind.system => LucideIcons.smartphone,
    TtsProviderKind.openai => LucideIcons.bot,
    TtsProviderKind.gemini => LucideIcons.sparkles,
    TtsProviderKind.minimax => LucideIcons.audioLines,
    TtsProviderKind.siliconflow => LucideIcons.rocket,
    TtsProviderKind.azure => LucideIcons.cloud,
    TtsProviderKind.elevenlabs => LucideIcons.mic,
    TtsProviderKind.volcano => LucideIcons.flame,
  };

  static Color _ttsAccent(TtsProviderKind kind) => switch (kind) {
    TtsProviderKind.system => const Color(0xFF64748B),
    TtsProviderKind.openai => const Color(0xFF10B981),
    TtsProviderKind.gemini => const Color(0xFF6366F1),
    TtsProviderKind.minimax => const Color(0xFFF59E0B),
    TtsProviderKind.siliconflow => const Color(0xFFEF4444),
    TtsProviderKind.azure => const Color(0xFF0EA5E9),
    TtsProviderKind.elevenlabs => const Color(0xFF8B5CF6),
    TtsProviderKind.volcano => const Color(0xFFF97316),
  };
}

// ---------------------------------------------------------------------------
// ASR tab content
// ---------------------------------------------------------------------------

class _AsrTab extends StatelessWidget {
  const _AsrTab({required this.settings, required this.ctrl});
  final VoiceSettings settings;
  final VoiceSettingsController ctrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        // Global ASR toggle
        _CompactCard(
          children: [
            _CompactToggle(
              icon: LucideIcons.mic,
              accent: const Color(0xFFEC4899),
              label: '启用语音识别',
              value: settings.enableAsr,
              onChanged: ctrl.setEnableAsr,
            ),
          ],
        ),
        const SizedBox(height: 10),
        // ASR provider list
        _CompactCard(
          children: [
            for (final kind in AsrProviderKind.values) ...[
              if (kind != AsrProviderKind.values.first)
                Divider(height: 1, indent: 48, color: theme.dividerColor),
              Builder(builder: (ctx) {
                final preset = defaultAsrProvider(kind);
                final configured = settings.asrProviders
                    .where((p) => p.kind == kind)
                    .toList();
                final provider =
                    configured.isNotEmpty ? configured.first : preset;
                final isActive =
                    settings.activeAsrProviderId == provider.id;

                return _ProviderTile(
                  icon: _asrIcon(kind),
                  accent: _asrAccent(kind),
                  name: preset.name,
                  isActive: isActive,
                  onTap: () => _pushDetail(ctx, kind, provider),
                  onLongPress: () => ctrl.setActiveAsrProvider(provider.id),
                );
              }),
            ],
          ],
        ),
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
        pageBuilder: (_, __, ___) =>
            _AsrProviderDetailPage(kind: kind, provider: provider),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  static IconData _asrIcon(AsrProviderKind kind) => switch (kind) {
    AsrProviderKind.system => LucideIcons.smartphone,
    AsrProviderKind.openaiRealtime => LucideIcons.radio,
    AsrProviderKind.whisper => LucideIcons.audioWaveform,
  };

  static Color _asrAccent(AsrProviderKind kind) => switch (kind) {
    AsrProviderKind.system => const Color(0xFF64748B),
    AsrProviderKind.openaiRealtime => const Color(0xFF10B981),
    AsrProviderKind.whisper => const Color(0xFF6366F1),
  };
}

// ---------------------------------------------------------------------------
// 3rd-level: TTS Provider Detail Page
// ---------------------------------------------------------------------------

class _TtsProviderDetailPage extends ConsumerStatefulWidget {
  const _TtsProviderDetailPage({
    required this.kind,
    required this.provider,
  });

  final TtsProviderKind kind;
  final TtsProviderSetting provider;

  @override
  ConsumerState<_TtsProviderDetailPage> createState() =>
      _TtsProviderDetailPageState();
}

class _TtsProviderDetailPageState
    extends ConsumerState<_TtsProviderDetailPage> {
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _baseUrlCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _voiceCtrl;
  late final TextEditingController _regionCtrl;
  late final TextEditingController _groupIdCtrl;
  // Volcano-specific
  late final TextEditingController _appIdCtrl;
  late final TextEditingController _clusterCtrl;
  late final TextEditingController _resourceIdCtrl;
  late final TextEditingController _emotionCtrl;
  late bool _enabled;
  late double _speed;
  late double _volume;
  late double _pitch;
  late String _apiVersion;
  late String _encoding;

  bool get _isSystem => widget.kind == TtsProviderKind.system;
  bool get _isVolcano => widget.kind == TtsProviderKind.volcano;

  @override
  void initState() {
    super.initState();
    final p = widget.provider;
    _apiKeyCtrl = TextEditingController(text: p.apiKey);
    _baseUrlCtrl = TextEditingController(text: p.baseUrl);
    _modelCtrl = TextEditingController(text: p.model);
    _voiceCtrl = TextEditingController(
      text: p.kind == TtsProviderKind.gemini ? p.voiceName : p.voice,
    );
    _regionCtrl = TextEditingController(text: p.region);
    _groupIdCtrl = TextEditingController(text: p.groupId);
    _appIdCtrl = TextEditingController(text: p.appId);
    _clusterCtrl = TextEditingController(text: p.cluster);
    _resourceIdCtrl = TextEditingController(text: p.resourceId);
    _emotionCtrl = TextEditingController(text: p.emotion);
    _enabled = p.enabled;
    _speed = p.speed;
    _volume = p.volume;
    _pitch = p.pitch;
    _apiVersion = p.apiVersion;
    _encoding = p.encoding;
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _baseUrlCtrl.dispose();
    _modelCtrl.dispose();
    _voiceCtrl.dispose();
    _regionCtrl.dispose();
    _groupIdCtrl.dispose();
    _appIdCtrl.dispose();
    _clusterCtrl.dispose();
    _resourceIdCtrl.dispose();
    _emotionCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final updated = widget.provider.copyWith(
      enabled: _enabled,
      apiKey: _apiKeyCtrl.text.trim(),
      baseUrl: _baseUrlCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      voice: widget.kind == TtsProviderKind.gemini
          ? ''
          : _voiceCtrl.text.trim(),
      voiceName: widget.kind == TtsProviderKind.gemini
          ? _voiceCtrl.text.trim()
          : '',
      region: _regionCtrl.text.trim(),
      groupId: _groupIdCtrl.text.trim(),
      speed: _speed,
      // Volcano
      appId: _appIdCtrl.text.trim(),
      cluster: _clusterCtrl.text.trim(),
      resourceId: _resourceIdCtrl.text.trim(),
      emotion: _emotionCtrl.text.trim(),
      volume: _volume,
      pitch: _pitch,
      apiVersion: _apiVersion,
      encoding: _encoding,
    );
    ref.read(voiceSettingsControllerProvider.notifier).updateTtsProvider(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModelSettingsAppBar(
        title: defaultTtsProvider(widget.kind).name,
        onBack: () => Navigator.of(context).pop(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ModelTonalButton(label: '保存', onPressed: _save),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ModelSettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ModelSectionTitle('基本设置'),
                const SizedBox(height: 12),
                _CompactToggle(
                  icon: LucideIcons.power,
                  accent: const Color(0xFF10B981),
                  label: '启用',
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
                if (!_isSystem) ...[
                  const SizedBox(height: 12),
                  if (_isVolcano) ...[
                    // Volcano uses appId + accessToken (apiKey)
                    ModelFormField(
                      label: 'App ID',
                      hint: '输入火山引擎 App ID',
                      controller: _appIdCtrl,
                    ),
                    const SizedBox(height: 12),
                    ModelFormField(
                      label: 'Access Token',
                      hint: '输入 Access Token',
                      controller: _apiKeyCtrl,
                      obscureText: true,
                    ),
                  ] else ...[
                    ModelFormField(
                      label: 'API Key',
                      hint: '输入 API 密钥',
                      controller: _apiKeyCtrl,
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    ModelFormField(
                      label: 'Base URL',
                      hint: '输入服务地址',
                      controller: _baseUrlCtrl,
                    ),
                    const SizedBox(height: 12),
                    ModelFormField(
                      label: '模型',
                      hint: '输入模型名称',
                      controller: _modelCtrl,
                    ),
                  ],
                  const SizedBox(height: 12),
                  ModelFormField(
                    label: widget.kind == TtsProviderKind.gemini
                        ? '语音名称 (voiceName)'
                        : _isVolcano
                            ? '音色 (voice_type)'
                            : '语音 (voice)',
                    hint: _isVolcano ? '例如 BV001_streaming' : '输入语音标识',
                    controller: _voiceCtrl,
                  ),
                  if (widget.kind == TtsProviderKind.azure) ...[
                    const SizedBox(height: 12),
                    ModelFormField(
                      label: '区域 (Region)',
                      hint: '例如 eastus',
                      controller: _regionCtrl,
                    ),
                  ],
                  if (widget.kind == TtsProviderKind.minimax) ...[
                    const SizedBox(height: 12),
                    ModelFormField(
                      label: 'Group ID',
                      hint: '输入 MiniMax Group ID',
                      controller: _groupIdCtrl,
                    ),
                  ],
                  if (_isVolcano) ..._buildVolcanoAdvanced(),
                  if (widget.kind == TtsProviderKind.minimax ||
                      _isVolcano) ...[
                    const SizedBox(height: 12),
                    ModelFormField(
                      label: '情感 (emotion)',
                      hint: '例如 neutral, happy, sad',
                      controller: _emotionCtrl,
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                _CompactSlider(
                  icon: LucideIcons.gauge,
                  accent: const Color(0xFF8B5CF6),
                  label: '播放速度',
                  value: _speed,
                  min: 0.5,
                  max: 2.0,
                  divisions: 6,
                  valueLabel: '${_speed.toStringAsFixed(1)}x',
                  onChanged: (v) => setState(() => _speed = v),
                ),
                if (_isVolcano) ...[
                  const SizedBox(height: 8),
                  _CompactSlider(
                    icon: LucideIcons.volume2,
                    accent: const Color(0xFF06B6D4),
                    label: '音量',
                    value: _volume,
                    min: 0.5,
                    max: 2.0,
                    divisions: 6,
                    valueLabel: '${_volume.toStringAsFixed(1)}x',
                    onChanged: (v) => setState(() => _volume = v),
                  ),
                  const SizedBox(height: 8),
                  _CompactSlider(
                    icon: LucideIcons.music,
                    accent: const Color(0xFFF59E0B),
                    label: '音调',
                    value: _pitch,
                    min: 0.5,
                    max: 2.0,
                    divisions: 6,
                    valueLabel: '${_pitch.toStringAsFixed(1)}x',
                    onChanged: (v) => setState(() => _pitch = v),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildVolcanoAdvanced() {
    return [
      const SizedBox(height: 12),
      ModelFormField(
        label: 'Cluster',
        hint: 'volcano_tts',
        controller: _clusterCtrl,
      ),
      const SizedBox(height: 12),
      ModelFormField(
        label: '模型 (Model)',
        hint: '留空使用默认',
        controller: _modelCtrl,
      ),
      const SizedBox(height: 12),
      _DropdownField(
        label: '接口版本',
        value: _apiVersion,
        items: const {
          'auto': '自动 (根据音色选择)',
          'v1': 'V1 (传统音色)',
          'v3': 'V3 (大模型音色)',
        },
        onChanged: (v) => setState(() => _apiVersion = v),
      ),
      const SizedBox(height: 12),
      _DropdownField(
        label: '音频格式',
        value: _encoding,
        items: const {
          'mp3': 'MP3',
          'ogg_opus': 'OGG Opus',
          'wav': 'WAV',
          'pcm': 'PCM',
        },
        onChanged: (v) => setState(() => _encoding = v),
      ),
      const SizedBox(height: 12),
      ModelFormField(
        label: 'Resource ID',
        hint: '留空自动选择',
        controller: _resourceIdCtrl,
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// 3rd-level: ASR Provider Detail Page
// ---------------------------------------------------------------------------

class _AsrProviderDetailPage extends ConsumerStatefulWidget {
  const _AsrProviderDetailPage({
    required this.kind,
    required this.provider,
  });

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
  late bool _enabled;
  late double _vadThreshold;
  late int _silenceDurationMs;

  @override
  void initState() {
    super.initState();
    final p = widget.provider;
    _apiKeyCtrl = TextEditingController(text: p.apiKey);
    _baseUrlCtrl = TextEditingController(text: p.baseUrl);
    _modelCtrl = TextEditingController(text: p.model);
    _wsUrlCtrl = TextEditingController(text: p.websocketUrl);
    _enabled = p.enabled;
    _vadThreshold = p.vadThreshold;
    _silenceDurationMs = p.silenceDurationMs;
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _baseUrlCtrl.dispose();
    _modelCtrl.dispose();
    _wsUrlCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final updated = widget.provider.copyWith(
      enabled: _enabled,
      apiKey: _apiKeyCtrl.text.trim(),
      baseUrl: _baseUrlCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      websocketUrl: _wsUrlCtrl.text.trim(),
      vadThreshold: _vadThreshold,
      silenceDurationMs: _silenceDurationMs,
    );
    ref
        .read(voiceSettingsControllerProvider.notifier)
        .updateAsrProvider(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isSystem = widget.kind == AsrProviderKind.system;
    final isRealtime = widget.kind == AsrProviderKind.openaiRealtime;

    return Scaffold(
      appBar: ModelSettingsAppBar(
        title: defaultAsrProvider(widget.kind).name,
        onBack: () => Navigator.of(context).pop(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ModelTonalButton(label: '保存', onPressed: _save),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ModelSettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ModelSectionTitle('基本设置'),
                const SizedBox(height: 12),
                _CompactToggle(
                  icon: LucideIcons.power,
                  accent: const Color(0xFF10B981),
                  label: '启用',
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
                if (!isSystem) ...[
                  const SizedBox(height: 12),
                  ModelFormField(
                    label: 'API Key',
                    hint: '输入 API 密钥',
                    controller: _apiKeyCtrl,
                    obscureText: true,
                  ),
                  if (!isRealtime) ...[
                    const SizedBox(height: 12),
                    ModelFormField(
                      label: 'Base URL',
                      hint: '输入服务地址',
                      controller: _baseUrlCtrl,
                    ),
                  ],
                  if (isRealtime) ...[
                    const SizedBox(height: 12),
                    ModelFormField(
                      label: 'WebSocket URL',
                      hint: '输入 WebSocket 地址',
                      controller: _wsUrlCtrl,
                    ),
                  ],
                  const SizedBox(height: 12),
                  ModelFormField(
                    label: '模型',
                    hint: '输入模型名称',
                    controller: _modelCtrl,
                  ),
                  if (isRealtime) ...[
                    const SizedBox(height: 16),
                    _CompactSlider(
                      icon: LucideIcons.activity,
                      accent: const Color(0xFFF59E0B),
                      label: 'VAD 阈值',
                      value: _vadThreshold,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      valueLabel: _vadThreshold.toStringAsFixed(2),
                      onChanged: (v) => setState(() => _vadThreshold = v),
                    ),
                    const SizedBox(height: 8),
                    _CompactSlider(
                      icon: LucideIcons.timer,
                      accent: const Color(0xFFEF4444),
                      label: '静默时间',
                      value: _silenceDurationMs.toDouble(),
                      min: 100,
                      max: 2000,
                      divisions: 19,
                      valueLabel: '$_silenceDurationMs ms',
                      onChanged: (v) =>
                          setState(() => _silenceDurationMs = v.round()),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared compact widgets
// ---------------------------------------------------------------------------

class _CompactCard extends StatelessWidget {
  const _CompactCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _CompactToggle extends StatelessWidget {
  const _CompactToggle({
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final Color accent;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 14, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          CustomSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _CompactSlider extends StatelessWidget {
  const _CompactSlider({
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
  });
  final IconData icon;
  final Color accent;
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 14, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                valueLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: accent,
              thumbColor: accent,
              inactiveTrackColor: accent.withValues(alpha: 0.15),
              overlayColor: accent.withValues(alpha: 0.08),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.icon,
    required this.accent,
    required this.name,
    required this.isActive,
    required this.onTap,
    required this.onLongPress,
  });
  final IconData icon;
  final Color accent;
  final String name;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 14, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '当前使用',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Icon(
              LucideIcons.chevronRight,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.dividerColor),
          ),
          child: DropdownButton<String>(
            value: items.containsKey(value) ? value : items.keys.first,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13.5),
            items: items.entries
                .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}
