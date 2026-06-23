import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/features/voice/application/tts_controller.dart';
import 'package:aetherlink_flutter/features/voice/application/voice_settings_controller.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/system_tts_service.dart';
import 'package:aetherlink_flutter/features/voice/domain/asr_provider_setting.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/network_tts_service.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_playback_state.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_provider_setting.dart';
import 'package:aetherlink_flutter/features/voice/domain/voice_presets.dart';
import 'package:aetherlink_flutter/features/voice/domain/voice_settings.dart';
import 'package:aetherlink_flutter/features/voice/presentation/widgets/full_screen_voice_picker.dart';

// ---------------------------------------------------------------------------
// Service metadata used by the 2nd-level card grid.
// Mirrors Web's getTTSServices / getASRServices.
// ---------------------------------------------------------------------------

class _ServiceMeta {
  const _ServiceMeta({
    required this.icon,
    required this.color,
    required this.name,
    required this.description,
    required this.features,
    this.status = '',
  });
  final IconData icon;
  final Color color;
  final String name;
  final String description;
  final List<String> features;
  final String status;
}

Map<TtsProviderKind, _ServiceMeta> _ttsServiceMeta() => {
  TtsProviderKind.system: const _ServiceMeta(
    icon: LucideIcons.smartphone,
    color: Color(0xFF64748B),
    name: '系统 TTS',
    description: '使用设备内置语音合成引擎',
    features: ['免费', '离线'],
    status: '免费',
  ),
  TtsProviderKind.openai: const _ServiceMeta(
    icon: LucideIcons.bot,
    color: Color(0xFF10B981),
    name: 'OpenAI TTS',
    description: '高质量 AI 语音合成，支持多种风格',
    features: ['高品质', '多风格', '流式'],
    status: '高级',
  ),
  TtsProviderKind.gemini: const _ServiceMeta(
    icon: LucideIcons.sparkles,
    color: Color(0xFFEA4335),
    name: 'Gemini TTS',
    description: 'Google Gemini 语音合成服务',
    features: ['30种语音', '多语言'],
    status: '高级',
  ),
  TtsProviderKind.minimax: const _ServiceMeta(
    icon: LucideIcons.audioLines,
    color: Color(0xFFFF6B35),
    name: 'MiniMax TTS',
    description: '海螺 AI 高质量中文语音合成',
    features: ['14种音色', '情感', '中文优化'],
    status: '高级',
  ),
  TtsProviderKind.siliconflow: const _ServiceMeta(
    icon: LucideIcons.rocket,
    color: Color(0xFF9333EA),
    name: 'SiliconFlow',
    description: '硅基流动 TTS，高性价比语音合成',
    features: ['多模型', '高性价比'],
    status: '推荐',
  ),
  TtsProviderKind.azure: const _ServiceMeta(
    icon: LucideIcons.cloud,
    color: Color(0xFF3B82F6),
    name: 'Azure TTS',
    description: '微软 Azure 认知服务语音合成',
    features: ['企业级', '多语言', '神经网络'],
    status: '企业',
  ),
  TtsProviderKind.elevenlabs: const _ServiceMeta(
    icon: LucideIcons.mic,
    color: Color(0xFF00C7B7),
    name: 'ElevenLabs',
    description: '领先的 AI 语音克隆与合成平台',
    features: ['语音克隆', '超自然', '多模型'],
    status: '高级',
  ),
  TtsProviderKind.volcano: const _ServiceMeta(
    icon: LucideIcons.flame,
    color: Color(0xFFFF4500),
    name: '火山引擎 TTS',
    description: '字节跳动火山引擎，100+ 音色',
    features: ['100+音色', '情感', '多方言'],
    status: '付费',
  ),
};

Map<AsrProviderKind, _ServiceMeta> _asrServiceMeta() => {
  AsrProviderKind.system: const _ServiceMeta(
    icon: LucideIcons.smartphone,
    color: Color(0xFF64748B),
    name: '系统语音识别',
    description: '使用设备内置语音识别引擎',
    features: ['免费', '离线'],
    status: '免费',
  ),
  AsrProviderKind.openaiRealtime: const _ServiceMeta(
    icon: LucideIcons.radio,
    color: Color(0xFF10B981),
    name: 'OpenAI Realtime',
    description: 'OpenAI 实时语音识别 (WebSocket)',
    features: ['实时', '高精度'],
    status: '高级',
  ),
  AsrProviderKind.whisper: const _ServiceMeta(
    icon: LucideIcons.audioWaveform,
    color: Color(0xFF6366F1),
    name: 'OpenAI Whisper',
    description: '高精度离线友好语音转文字',
    features: ['高精度', '多语言'],
    status: '高级',
  ),
};

// ---------------------------------------------------------------------------
// 2nd-level page: Dual-tab (TTS / ASR) provider card grid
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
      body: SafeArea(
        top: false,
        child: TabBarView(
          controller: _tabCtrl,
          children: [
            _TtsTab(settings: settings, ctrl: ctrl),
            _AsrTab(settings: settings, ctrl: ctrl),
          ],
        ),
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
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
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
// TTS tab — card grid (matches Web's grid layout)
// ---------------------------------------------------------------------------

class _TtsTab extends ConsumerWidget {
  const _TtsTab({required this.settings, required this.ctrl});
  final VoiceSettings settings;
  final VoiceSettingsController ctrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = _ttsServiceMeta();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        for (final kind in TtsProviderKind.values) ...[
          Builder(
            builder: (ctx) {
              final preset = defaultTtsProvider(kind);
              final configured = settings.ttsProviders
                  .where((p) => p.kind == kind)
                  .toList();
              final provider = configured.isNotEmpty
                  ? configured.first
                  : preset;
              final isActive = settings.activeTtsProviderId == provider.id;
              final m = meta[kind]!;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ServiceCard(
                  icon: m.icon,
                  color: m.color,
                  name: m.name,
                  description: m.description,
                  features: m.features,
                  status: m.status,
                  isActive: isActive,
                  onTap: () => _pushDetail(ctx, kind, provider),
                  onLongPress: () => ctrl.setActiveTtsProvider(provider.id),
                  onTest: kind == TtsProviderKind.system
                      ? () => _testSystemTts(ref)
                      : null,
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  void _testSystemTts(WidgetRef ref) {
    final ttsCtrl = ref.read(ttsControllerProvider.notifier);
    final provider = defaultTtsProvider(TtsProviderKind.system);
    ttsCtrl.preview('你好，这是系统语音合成测试。', provider);
  }

  void _pushDetail(
    BuildContext context,
    TtsProviderKind kind,
    TtsProviderSetting provider,
  ) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) =>
            _TtsProviderDetailPage(kind: kind, provider: provider),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ASR tab — card grid
// ---------------------------------------------------------------------------

class _AsrTab extends StatelessWidget {
  const _AsrTab({required this.settings, required this.ctrl});
  final VoiceSettings settings;
  final VoiceSettingsController ctrl;

  @override
  Widget build(BuildContext context) {
    final meta = _asrServiceMeta();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                padding: const EdgeInsets.only(bottom: 10),
                child: _ServiceCard(
                  icon: m.icon,
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

// ---------------------------------------------------------------------------
// Service card — rich card matching Web's grid items
// ---------------------------------------------------------------------------

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.icon,
    required this.color,
    required this.name,
    required this.description,
    required this.features,
    required this.status,
    required this.isActive,
    required this.onTap,
    required this.onLongPress,
    this.onTest,
  });
  final IconData icon;
  final Color color;
  final String name;
  final String description;
  final List<String> features;
  final String status;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onTest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? theme.colorScheme.primary.withValues(alpha: 0.5)
                  : theme.dividerColor,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: icon + name + badges
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (isActive)
                              const _Badge(
                                label: '当前使用',
                                bgColor: Color(0xFF22C55E),
                                textColor: Colors.white,
                              ),
                            if (isActive && status.isNotEmpty)
                              const SizedBox(width: 4),
                            if (status.isNotEmpty)
                              _Badge(
                                label: status,
                                bgColor: color.withValues(alpha: 0.12),
                                textColor: color,
                                outlined: true,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (onTest != null)
                    GestureDetector(
                      onTap: onTest,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(LucideIcons.volume2, size: 16, color: color),
                      ),
                    ),
                  if (onTest != null) const SizedBox(width: 8),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Description
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              // Feature tags
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: features
                    .map((f) => _FeatureChip(label: f, color: color))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.bgColor,
    required this.textColor,
    this.outlined = false,
  });
  final String label;
  final Color bgColor;
  final Color textColor;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : bgColor,
        borderRadius: BorderRadius.circular(6),
        border: outlined
            ? Border.all(color: textColor.withValues(alpha: 0.4))
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3rd-level: TTS Provider Detail Page
// Matches Web layout: single Paper card with all settings + separate test card.
// ---------------------------------------------------------------------------

class _TtsProviderDetailPage extends ConsumerStatefulWidget {
  const _TtsProviderDetailPage({required this.kind, required this.provider});

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
  late final TextEditingController _regionCtrl;
  late final TextEditingController _groupIdCtrl;
  late final TextEditingController _appIdCtrl;
  late final TextEditingController _clusterCtrl;
  late final TextEditingController _testTextCtrl;
  late final TextEditingController _instructionsCtrl;
  late final TextEditingController _stylePromptCtrl;
  late final TextEditingController _speaker1NameCtrl;
  late final TextEditingController _speaker2NameCtrl;
  late bool _enabled;
  late bool _useMultiSpeaker;
  late String _speaker1Voice;
  late String _speaker2Voice;
  late double _speed;
  late double _volume;
  late double _pitch;
  late String _apiVersion;
  late String _encoding;
  late String _voice;
  late String _voiceName;
  late String _emotion;
  late String _model;
  late String _outputFormat;
  late String _resourceId;
  late String _languageBoost;
  late int _sampleRate;
  late int _bitrate;
  late String _audioFormat;
  List<MiniMaxRemoteVoice> _miniMaxRemoteVoices = [];
  late double _gain;
  late int _maxTokens;
  late double _stability;
  late double _similarityBoost;
  late double _elStyle;
  late bool _useSpeakerBoost;
  List<ElevenLabsRemoteVoice> _elRemoteVoices = [];
  bool _elVoicesLoading = false;
  late String _azureRate;
  late String _azurePitch;
  late String _azureVolume;
  late String _azureStyle;
  late double _azureStyleDegree;
  late String _azureRole;
  late String _azureOutputFormat;
  List<AzureRemoteVoice> _azureRemoteVoices = [];
  bool _azureVoicesLoading = false;
  SystemTtsService? _systemTts;

  bool get _isSystem => widget.kind == TtsProviderKind.system;
  bool get _isVolcano => widget.kind == TtsProviderKind.volcano;
  bool get _isElevenLabs => widget.kind == TtsProviderKind.elevenlabs;
  bool get _isAzure => widget.kind == TtsProviderKind.azure;

  /// True when SiliconFlow model supports speed/gain (MOSS-TTSD / IndexTTS-2).
  bool get _sfHasSpeedGain =>
      widget.kind == TtsProviderKind.siliconflow &&
      (_model == 'fnlp/MOSS-TTSD-v0.5' || _model == 'IndexTeam/IndexTTS-2');

  @override
  void initState() {
    super.initState();
    final p = widget.provider;
    _apiKeyCtrl = TextEditingController(text: p.apiKey);
    _baseUrlCtrl = TextEditingController(text: p.baseUrl);
    _modelCtrl = TextEditingController(text: p.model);
    _regionCtrl = TextEditingController(text: p.region);
    _groupIdCtrl = TextEditingController(text: p.groupId);
    _appIdCtrl = TextEditingController(text: p.appId);
    _clusterCtrl = TextEditingController(text: p.cluster);
    _testTextCtrl = TextEditingController(text: '你好，欢迎使用语音合成服务！这是一段测试文本。');
    // "启用此服务" reflects whether this is the single active provider,
    // matching the original web app's per-service enable toggle.
    _enabled =
        ref.read(voiceSettingsControllerProvider).activeTtsProviderId == p.id;
    _speed = p.speed;
    _volume = p.volume;
    _pitch = p.pitch;
    _apiVersion = p.apiVersion;
    _encoding = p.encoding;
    _voice = p.voice;
    _voiceName = p.voiceName;
    _emotion = p.emotion;
    _model = p.model;
    _outputFormat = p.outputFormat;
    _resourceId = p.resourceId;
    _languageBoost = p.languageBoost;
    _sampleRate = p.sampleRate;
    _bitrate = p.bitrate;
    _audioFormat = p.audioFormat;
    _gain = p.gain;
    _maxTokens = p.maxTokens;
    _stability = p.stability;
    _similarityBoost = p.similarityBoost;
    _elStyle = p.elStyle;
    _useSpeakerBoost = p.useSpeakerBoost;
    _azureRate = p.azureRate;
    _azurePitch = p.azurePitch;
    _azureVolume = p.azureVolume;
    _azureStyle = p.azureStyle;
    _azureStyleDegree = p.azureStyleDegree;
    _azureRole = p.azureRole;
    _azureOutputFormat = p.azureOutputFormat;
    _instructionsCtrl = TextEditingController(text: p.instructions);
    _stylePromptCtrl = TextEditingController(text: p.stylePrompt);
    _speaker1NameCtrl = TextEditingController(text: p.speaker1Name);
    _speaker2NameCtrl = TextEditingController(text: p.speaker2Name);
    _useMultiSpeaker = p.useMultiSpeaker;
    _speaker1Voice = p.speaker1Voice;
    _speaker2Voice = p.speaker2Voice;
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _baseUrlCtrl.dispose();
    _modelCtrl.dispose();
    _regionCtrl.dispose();
    _groupIdCtrl.dispose();
    _appIdCtrl.dispose();
    _clusterCtrl.dispose();
    _testTextCtrl.dispose();
    _instructionsCtrl.dispose();
    _stylePromptCtrl.dispose();
    _speaker1NameCtrl.dispose();
    _speaker2NameCtrl.dispose();
    _systemTts?.dispose();
    super.dispose();
  }

  /// Builds a [TtsProviderSetting] from the current (possibly unsaved) form
  /// values. Used by both save and the live preview/test.
  TtsProviderSetting _currentProvider() => widget.provider.copyWith(
    enabled: _enabled,
    apiKey: _apiKeyCtrl.text.trim(),
    baseUrl: _baseUrlCtrl.text.trim(),
    model: _usesModelSelector ? _model : _modelCtrl.text.trim(),
    voice: widget.kind == TtsProviderKind.gemini ? '' : _voice,
    voiceName: widget.kind == TtsProviderKind.gemini ? _voiceName : '',
    region: _regionCtrl.text.trim(),
    groupId: _groupIdCtrl.text.trim(),
    speed: _speed,
    emotion: _emotion,
    outputFormat: _outputFormat,
    appId: _appIdCtrl.text.trim(),
    cluster: _clusterCtrl.text.trim(),
    resourceId: _resourceId,
    volume: _volume,
    pitch: _pitch,
    apiVersion: _apiVersion,
    encoding: _encoding,
    languageBoost: _languageBoost,
    sampleRate: _sampleRate,
    bitrate: _bitrate,
    audioFormat: _audioFormat,
    gain: _gain,
    maxTokens: _maxTokens,
    stability: _stability,
    similarityBoost: _similarityBoost,
    elStyle: _elStyle,
    useSpeakerBoost: _useSpeakerBoost,
    azureRate: _azureRate,
    azurePitch: _azurePitch,
    azureVolume: _azureVolume,
    azureStyle: _azureStyle,
    azureStyleDegree: _azureStyleDegree,
    azureRole: _azureRole,
    azureOutputFormat: _azureOutputFormat,
    instructions: _instructionsCtrl.text,
    stylePrompt: _stylePromptCtrl.text,
    useMultiSpeaker: _useMultiSpeaker,
    speaker1Name: _speaker1NameCtrl.text.trim(),
    speaker1Voice: _speaker1Voice,
    speaker2Name: _speaker2NameCtrl.text.trim(),
    speaker2Voice: _speaker2Voice,
  );

  /// Persists the current form values. Called automatically when leaving the
  /// page (back button or system back gesture).
  void _persist() {
    final updated = _currentProvider();
    final notifier = ref.read(voiceSettingsControllerProvider.notifier);
    notifier.updateTtsProvider(updated);
    // Enabling makes this the single active provider (others are implicitly
    // deactivated since activeTtsProviderId holds only one id). Disabling the
    // currently-active provider falls back to the system engine.
    if (_enabled) {
      notifier.setActiveTtsProvider(updated.id);
    } else if (ref.read(voiceSettingsControllerProvider).activeTtsProviderId ==
        updated.id) {
      notifier.setActiveTtsProvider('system');
    }
  }

  bool get _usesModelSelector => const {
    TtsProviderKind.openai,
    TtsProviderKind.minimax,
    TtsProviderKind.siliconflow,
    TtsProviderKind.elevenlabs,
    TtsProviderKind.gemini,
  }.contains(widget.kind);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _persist();
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: ModelSettingsAppBar(
          title: defaultTtsProvider(widget.kind).name,
          onBack: () => Navigator.of(context).maybePop(),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              // ===== Single main card (matching Web's single Paper) =====
              ModelSettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // -- Enable switch --
                    _InlineToggle(
                      label: '启用此服务',
                      value: _enabled,
                      onChanged: (v) => setState(() => _enabled = v),
                    ),
                    if (_isSystem) ...[
                      Divider(height: 24, color: theme.dividerColor),
                      _SystemTtsConfigSection(
                        systemTts: _systemTts ??= SystemTtsService(),
                      ),
                    ] else ...[
                      Divider(height: 24, color: theme.dividerColor),
                      // -- Credentials --
                      ..._buildCredentialFields(),
                      // -- API version + V3 options (Volcano, inline) --
                      if (_isVolcano) ..._buildVolcanoApiOptions(),
                      Divider(height: 24, color: theme.dividerColor),
                      // -- Voice / model selection --
                      ..._buildVoiceSection(),
                      // -- Encoding (Volcano) --
                      if (_isVolcano) ...[
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
                      ],
                    ],
                    if (!_isSystem) ...[
                    Divider(height: 24, color: theme.dividerColor),
                    // -- Playback sliders (Azure uses its own prosody controls) --
                    if (!_isAzure)
                      _SliderRow(
                        label: '语速',
                        value: _speed,
                        min:
                            (_sfHasSpeedGain ||
                                _isElevenLabs ||
                                widget.kind == TtsProviderKind.openai)
                            ? 0.25
                            : 0.5,
                        max:
                            (_sfHasSpeedGain ||
                                _isElevenLabs ||
                                widget.kind == TtsProviderKind.openai)
                            ? 4.0
                            : 2.0,
                        divisions:
                            (_sfHasSpeedGain ||
                                _isElevenLabs ||
                                widget.kind == TtsProviderKind.openai)
                            ? 15
                            : 6,
                        onChanged: (v) => setState(() => _speed = v),
                      ),
                    if (_isVolcano) ...[
                      _SliderRow(
                        label: '音量',
                        value: _volume,
                        min: 0.5,
                        max: 2.0,
                        divisions: 6,
                        onChanged: (v) => setState(() => _volume = v),
                      ),
                      _SliderRow(
                        label: '音调',
                        value: _pitch,
                        min: 0.5,
                        max: 2.0,
                        divisions: 6,
                        onChanged: (v) => setState(() => _pitch = v),
                      ),
                    ],
                    if (_sfHasSpeedGain) ...[
                      _SliderRow(
                        label: '增益',
                        value: _gain,
                        min: -10,
                        max: 10,
                        divisions: 20,
                        onChanged: (v) => setState(() => _gain = v),
                      ),
                    ],
                    if (widget.kind == TtsProviderKind.minimax) ...[
                      _SliderRow(
                        label: '音量',
                        value: _volume,
                        min: 0.1,
                        max: 10.0,
                        divisions: 99,
                        onChanged: (v) => setState(() => _volume = v),
                      ),
                      _SliderRow(
                        label: '音调',
                        value: _pitch,
                        min: -12,
                        max: 12,
                        divisions: 24,
                        onChanged: (v) => setState(() => _pitch = v),
                      ),
                    ],
                    // -- Volcano advanced (cluster, model, resource ID) --
                    if (_isVolcano) ...[
                      Divider(height: 24, color: theme.dividerColor),
                      ..._buildVolcanoAdvanced(),
                    ],
                    ], // end if (!_isSystem)
                  ],
                ),
              ),
              // ===== Test section =====
              const SizedBox(height: 10),
              _TtsTestSection(
                testTextCtrl: _testTextCtrl,
                buildProvider: _currentProvider,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -- Credential fields per engine --
  List<Widget> _buildCredentialFields() {
    return [
      if (_isVolcano) ...[
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
        if (widget.kind != TtsProviderKind.elevenlabs) ...[
          const SizedBox(height: 12),
          ModelFormField(
            label: 'Base URL',
            hint: '输入服务地址',
            controller: _baseUrlCtrl,
          ),
        ],
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
      ],
      const SizedBox(height: 4),
    ];
  }

  // -- Volcano API version + V3 options (inline in credentials area) --
  List<Widget> _buildVolcanoApiOptions() {
    final showV3 = _apiVersion == 'v3' || _apiVersion == 'auto';
    return [
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
      if (showV3) ...[
        const SizedBox(height: 12),
        _DropdownField(
          label: 'Resource ID',
          value: _resourceId,
          items: const {
            '': '自动选择',
            'volc.service_type.10029': 'BigTTS (豆包大模型)',
            'seed-tts-2.0': 'Seed TTS 2.0',
          },
          onChanged: (v) => setState(() => _resourceId = v),
        ),
        const SizedBox(height: 12),
        ModelFormField(
          label: '模型 (Model)',
          hint: '留空使用默认',
          controller: _modelCtrl,
        ),
      ],
      const SizedBox(height: 4),
    ];
  }

  // -- Voice/model selection section per engine --
  List<Widget> _buildVoiceSection() {
    switch (widget.kind) {
      case TtsProviderKind.system:
        return const [];
      case TtsProviderKind.openai:
        return _buildOpenAIVoice();
      case TtsProviderKind.gemini:
        return _buildGeminiVoice();
      case TtsProviderKind.minimax:
        return _buildMiniMaxVoice();
      case TtsProviderKind.siliconflow:
        return _buildSiliconFlowVoice();
      case TtsProviderKind.azure:
        return _buildAzureVoice();
      case TtsProviderKind.elevenlabs:
        return _buildElevenLabsVoice();
      case TtsProviderKind.volcano:
        return _buildVolcanoVoice();
    }
  }

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

  List<Widget> _buildVolcanoVoice() {
    final voiceDisplayName = _voice.isEmpty
        ? '选择音色...'
        : kVolcanoVoices.entries
                  .where((e) => e.value == _voice)
                  .map((e) => e.key)
                  .firstOrNull ??
              _voice;
    final emotionDisplayName = _emotion.isEmpty
        ? '默认'
        : kVolcanoEmotions[_emotion] ?? _emotion;

    return [
      _SelectorField(
        label: '音色',
        value: _voice,
        displayText: voiceDisplayName,
        onTap: () async {
          final result = await FullScreenVoicePicker.show(
            context,
            title: '选择火山引擎音色',
            groups: buildVolcanoVoiceGroups(),
            selectedKey: kVolcanoVoices.entries
                .where((e) => e.value == _voice)
                .map((e) => e.key)
                .firstOrNull,
          );
          if (result != null) {
            setState(() {
              _voice = kVolcanoVoices[result] ?? result;
            });
          }
        },
      ),
      const SizedBox(height: 12),
      _SelectorField(
        label: '情感风格',
        value: _emotion,
        displayText: emotionDisplayName,
        onTap: () async {
          final result = await FullScreenVoicePicker.show(
            context,
            title: '选择情感风格',
            groups: buildVolcanoEmotionGroups(),
            selectedKey: _emotion,
            allowEmpty: true,
          );
          if (result != null) setState(() => _emotion = result);
        },
      ),
    ];
  }

  List<Widget> _buildVolcanoAdvanced() {
    return [
      ModelFormField(
        label: 'Cluster',
        hint: 'volcano_tts',
        controller: _clusterCtrl,
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// 3rd-level: ASR Provider Detail Page
// ---------------------------------------------------------------------------

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
  late bool _enabled;
  late double _vadThreshold;
  late int _silenceDurationMs;
  late int _prefixPaddingMs;
  late double _temperature;
  late String _realtimeDelay;

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
    // "启用此服务" reflects whether this is the single active ASR provider.
    _enabled =
        ref.read(voiceSettingsControllerProvider).activeAsrProviderId == p.id;
    _vadThreshold = p.vadThreshold;
    _silenceDurationMs = p.silenceDurationMs;
    _prefixPaddingMs = p.prefixPaddingMs;
    _temperature = p.temperature;
    _realtimeDelay = p.realtimeDelay;
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _baseUrlCtrl.dispose();
    _modelCtrl.dispose();
    _wsUrlCtrl.dispose();
    _languageCtrl.dispose();
    _promptCtrl.dispose();
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
      vadThreshold: _vadThreshold,
      silenceDurationMs: _silenceDurationMs,
      prefixPaddingMs: _prefixPaddingMs,
      temperature: _temperature,
      realtimeDelay: _realtimeDelay,
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

// ---------------------------------------------------------------------------
// TTS test/preview section
// ---------------------------------------------------------------------------

class _TtsTestSection extends ConsumerWidget {
  const _TtsTestSection({
    required this.testTextCtrl,
    required this.buildProvider,
  });

  final TextEditingController testTextCtrl;
  final TtsProviderSetting Function() buildProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ttsState = ref.watch(ttsControllerProvider);
    final isPlaying =
        ttsState.status == TtsStatus.playing ||
        ttsState.status == TtsStatus.loading;
    final isTestMessage = ttsState.messageId == '__tts_test__';

    return ModelSettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ModelSectionTitle('语音试听'),
          const SizedBox(height: 12),
          TextField(
            controller: testTextCtrl,
            maxLines: 3,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: '输入测试文本...',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
                fontSize: 13.5,
              ),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final ttsCtrl = ref.read(ttsControllerProvider.notifier);
                if (isPlaying && isTestMessage) {
                  await ttsCtrl.stop();
                } else {
                  final text = testTextCtrl.text.trim();
                  if (text.isEmpty) return;
                  await ttsCtrl.preview(text, buildProvider());
                }
              },
              icon: Icon(
                isPlaying && isTestMessage
                    ? LucideIcons.square
                    : LucideIcons.volume2,
                size: 16,
              ),
              label: Text(
                isPlaying && isTestMessage ? '停止播放' : '试听',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: isPlaying && isTestMessage
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
                foregroundColor: isPlaying && isTestMessage
                    ? theme.colorScheme.onError
                    : theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          if (ttsState.status == TtsStatus.error && isTestMessage) ...[
            const SizedBox(height: 8),
            Text(
              ttsState.error ?? '播放失败',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// System TTS configuration section (engine, language, rate, pitch)
// ---------------------------------------------------------------------------

class _SystemTtsConfigSection extends ConsumerStatefulWidget {
  const _SystemTtsConfigSection({required this.systemTts});
  final SystemTtsService systemTts;

  @override
  ConsumerState<_SystemTtsConfigSection> createState() =>
      _SystemTtsConfigSectionState();
}

class _SystemTtsConfigSectionState
    extends ConsumerState<_SystemTtsConfigSection> {
  List<String> _engines = [];
  List<String> _languages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEngineData();
  }

  Future<void> _loadEngineData() async {
    final engines = await widget.systemTts.listEngines();
    final languages = await widget.systemTts.listLanguages();
    if (!mounted) return;
    setState(() {
      _engines = engines;
      _languages = languages;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(voiceSettingsControllerProvider);
    final ctrl = ref.read(voiceSettingsControllerProvider.notifier);

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final currentEngine = settings.systemTtsEngine.isEmpty
        ? (_engines.isNotEmpty ? _engines.first : '')
        : settings.systemTtsEngine;
    final currentLanguage = settings.systemTtsLanguage.isEmpty
        ? (_languages.contains('zh-CN')
            ? 'zh-CN'
            : (_languages.contains('en-US')
                ? 'en-US'
                : (_languages.isNotEmpty ? _languages.first : '')))
        : settings.systemTtsLanguage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '引擎',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        _SystemTtsDropdown(
          value: currentEngine,
          items: _engines,
          hint: '自动选择',
          onChanged: (v) {
            ctrl.setSystemTtsEngine(v);
            // Reload languages for new engine.
            widget.systemTts.applyUserConfig(engineId: v).then((_) async {
              final langs = await widget.systemTts.listLanguages();
              if (mounted) setState(() => _languages = langs);
            });
          },
        ),
        const SizedBox(height: 14),
        Text(
          '语言',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        _SystemTtsDropdown(
          value: currentLanguage,
          items: _languages,
          hint: '自动选择',
          onChanged: (v) => ctrl.setSystemTtsLanguage(v),
        ),
        const SizedBox(height: 14),
        _SliderRow(
          label: '语速',
          value: settings.systemTtsSpeechRate,
          min: 0.1,
          max: 1.0,
          divisions: 9,
          onChanged: (v) => ctrl.setSystemTtsSpeechRate(v),
        ),
        _SliderRow(
          label: '音调',
          value: settings.systemTtsPitch,
          min: 0.5,
          max: 2.0,
          divisions: 6,
          onChanged: (v) => ctrl.setSystemTtsPitch(v),
        ),
      ],
    );
  }
}

class _SystemTtsDropdown extends StatelessWidget {
  const _SystemTtsDropdown({
    required this.value,
    required this.items,
    required this.hint,
    required this.onChanged,
  });
  final String value;
  final List<String> items;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: items.isEmpty
          ? null
          : () async {
              final picked = await showModalBottomSheet<String>(
                context: context,
                backgroundColor: theme.colorScheme.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (ctx) {
                  return SafeArea(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: theme.dividerColor),
                        itemBuilder: (_, i) {
                          final item = items[i];
                          final selected = item == value;
                          return ListTile(
                            dense: true,
                            title: Text(
                              item,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: selected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                            trailing: selected
                                ? Icon(
                                    LucideIcons.check,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  )
                                : null,
                            onTap: () => Navigator.of(ctx).pop(item),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
              if (picked != null) onChanged(picked);
            },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value.isEmpty ? hint : value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13.5,
                  color: value.isEmpty
                      ? theme.hintColor
                      : theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              LucideIcons.chevronDown,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared compact widgets
// ---------------------------------------------------------------------------

class _InlineToggle extends StatelessWidget {
  const _InlineToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        CustomSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _DropdownRow extends StatelessWidget {
  const _DropdownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<(String, String)> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: items.any((e) => e.$1 == value)
              ? value
              : items.first.$1,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
          ),
          items: items
              .map(
                (e) => DropdownMenuItem<String>(
                  value: e.$1,
                  child: Text(e.$2, style: theme.textTheme.bodyMedium),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              value.toStringAsFixed(1),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
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
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, overflow: TextOverflow.ellipsis),
                  ),
                )
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

class _SelectorField extends StatelessWidget {
  const _SelectorField({
    required this.label,
    required this.value,
    required this.displayText,
    required this.onTap,
  });
  final String label;
  final String value;
  final String displayText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = value.isNotEmpty;
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
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      displayText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13.5,
                        color: hasValue
                            ? theme.colorScheme.onSurface
                            : theme.hintColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
