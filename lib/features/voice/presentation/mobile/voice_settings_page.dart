import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/shared/utils/provider_icons.dart';
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
import 'package:aetherlink_flutter/shared/widgets/instant_switch_tab_view.dart';

// Per-provider TTS settings sections (extensions on _TtsProviderDetailPageState).
part 'voice_settings/engines/openai_settings.dart';
part 'voice_settings/engines/gemini_settings.dart';
part 'voice_settings/engines/minimax_settings.dart';
part 'voice_settings/engines/siliconflow_settings.dart';
part 'voice_settings/engines/azure_settings.dart';
part 'voice_settings/engines/elevenlabs_settings.dart';
part 'voice_settings/engines/volcano_settings.dart';
part 'voice_settings/engines/mimo_settings.dart';
part 'voice_settings/engines/qwen_settings.dart';
part 'voice_settings/engines/groq_settings.dart';
part 'voice_settings/engines/xai_settings.dart';

// ASR (speech-to-text) settings: tab + per-provider detail page.
part 'voice_settings/asr_settings.dart';

// ---------------------------------------------------------------------------
// Service metadata used by the 2nd-level card grid.
// Mirrors Web's getTTSServices / getASRServices.
// ---------------------------------------------------------------------------

class _ServiceMeta {
  const _ServiceMeta({
    required this.providerId,
    required this.color,
    required this.name,
    required this.description,
    required this.features,
    this.status = '',
  });
  final String providerId;
  final Color color;
  final String name;
  final String description;
  final List<String> features;
  final String status;
}

Map<TtsProviderKind, _ServiceMeta> _ttsServiceMeta() => {
  TtsProviderKind.system: const _ServiceMeta(
    providerId: 'custom',
    color: Color(0xFF64748B),
    name: '系统 TTS',
    description: '使用设备内置语音合成引擎',
    features: ['免费', '离线'],
    status: '免费',
  ),
  TtsProviderKind.openai: const _ServiceMeta(
    providerId: 'openai',
    color: Color(0xFF10B981),
    name: 'OpenAI TTS',
    description: '高质量 AI 语音合成，支持多种风格',
    features: ['高品质', '多风格', '流式'],
    status: '高级',
  ),
  TtsProviderKind.gemini: const _ServiceMeta(
    providerId: 'gemini',
    color: Color(0xFFEA4335),
    name: 'Gemini TTS',
    description: 'Google Gemini 语音合成服务',
    features: ['30种语音', '多语言'],
    status: '高级',
  ),
  TtsProviderKind.minimax: const _ServiceMeta(
    providerId: 'minimax',
    color: Color(0xFFFF6B35),
    name: 'MiniMax TTS',
    description: '海螺 AI 高质量中文语音合成',
    features: ['14种音色', '情感', '中文优化'],
    status: '高级',
  ),
  TtsProviderKind.siliconflow: const _ServiceMeta(
    providerId: 'siliconflow',
    color: Color(0xFF9333EA),
    name: 'SiliconFlow',
    description: '硅基流动 TTS，高性价比语音合成',
    features: ['多模型', '高性价比'],
    status: '推荐',
  ),
  TtsProviderKind.azure: const _ServiceMeta(
    providerId: 'azure-openai',
    color: Color(0xFF3B82F6),
    name: 'Azure TTS',
    description: '微软 Azure 认知服务语音合成',
    features: ['企业级', '多语言', '神经网络'],
    status: '企业',
  ),
  TtsProviderKind.elevenlabs: const _ServiceMeta(
    providerId: 'elevenlabs',
    color: Color(0xFF00C7B7),
    name: 'ElevenLabs',
    description: '领先的 AI 语音克隆与合成平台',
    features: ['语音克隆', '超自然', '多模型'],
    status: '高级',
  ),
  TtsProviderKind.volcano: const _ServiceMeta(
    providerId: 'volcengine',
    color: Color(0xFFFF4500),
    name: '火山引擎 TTS',
    description: '字节跳动火山引擎，100+ 音色',
    features: ['100+音色', '情感', '多方言'],
    status: '付费',
  ),
  TtsProviderKind.mimo: const _ServiceMeta(
    providerId: 'mimo',
    color: Color(0xFFFF6A00),
    name: 'MiMo TTS',
    description: '小米 MiMo 语音合成，支持语音设计与克隆',
    features: ['多音色', '语音设计', '语音克隆', '情感控制'],
    status: '高级',
  ),
  TtsProviderKind.qwen: const _ServiceMeta(
    providerId: 'dashscope',
    color: Color(0xFF6236FF),
    name: 'Qwen TTS',
    description: '阿里通义千问语音合成，支持指令控制表现力',
    features: ['22+音色', '10语言', '指令控制', '流式输出'],
    status: '高级',
  ),
  TtsProviderKind.groq: const _ServiceMeta(
    providerId: 'groq',
    color: Color(0xFFF55036),
    name: 'Groq TTS',
    description: 'Groq PlayAI 超低延迟语音合成',
    features: ['23音色', '极速推理', '多格式'],
    status: '高级',
  ),
  TtsProviderKind.xai: const _ServiceMeta(
    providerId: 'grok',
    color: Color(0xFF000000),
    name: 'xAI TTS',
    description: 'xAI Grok 多语言语音合成',
    features: ['5音色', '20+语言', '自动检测', '延迟优化'],
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
        child: InstantSwitchTabView(
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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

// ---------------------------------------------------------------------------
// Service card — rich card matching Web's grid items
// ---------------------------------------------------------------------------

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.providerId,
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
  final String providerId;
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
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? theme.colorScheme.primary.withValues(alpha: 0.5)
                  : theme.dividerColor,
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Image.asset(
                    getProviderIcon(
                      providerId,
                      isDark: Theme.of(context).brightness == Brightness.dark,
                    ),
                    width: 20,
                    height: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Name + feature subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF22C55E),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                        if (status.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _Badge(
                            label: status,
                            bgColor: color.withValues(alpha: 0.12),
                            textColor: color,
                            outlined: true,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      features.join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onTest != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onTest,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(LucideIcons.volume2, size: 14, color: color),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Icon(
                LucideIcons.chevronRight,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
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

  // MiMo-specific
  late bool _mimoOptimizeTextPreview;
  late TextEditingController _mimoVoiceDescCtrl;
  late TextEditingController _mimoCloneAudioCtrl;

  // Qwen-specific
  late String _qwenLanguageType;
  late bool _qwenOptimizeInstructions;
  late TextEditingController _qwenInstructionsCtrl;

  // Groq-specific
  late int _groqSampleRate;

  // xAI-specific
  late String _xaiLanguage;
  late String _xaiCodec;
  late int _xaiSampleRate;
  late int _xaiBitRate;
  late bool _xaiTextNormalization;
  late int _xaiOptimizeStreamingLatency;

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
    // MiMo
    _mimoOptimizeTextPreview = p.mimoOptimizeTextPreview;
    _mimoVoiceDescCtrl = TextEditingController(text: p.mimoVoiceDescription);
    _mimoCloneAudioCtrl = TextEditingController(text: p.mimoVoiceCloneAudio);
    // Qwen
    _qwenLanguageType = p.qwenLanguageType;
    _qwenOptimizeInstructions = p.qwenOptimizeInstructions;
    _qwenInstructionsCtrl = TextEditingController(text: p.qwenInstructions);
    // Groq
    _groqSampleRate = p.groqSampleRate;
    // xAI
    _xaiLanguage = p.xaiLanguage;
    _xaiCodec = p.xaiCodec;
    _xaiSampleRate = p.xaiSampleRate;
    _xaiBitRate = p.xaiBitRate;
    _xaiTextNormalization = p.xaiTextNormalization;
    _xaiOptimizeStreamingLatency = p.xaiOptimizeStreamingLatency;
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
    _mimoVoiceDescCtrl.dispose();
    _mimoCloneAudioCtrl.dispose();
    _qwenInstructionsCtrl.dispose();
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
    mimoVoiceDescription: _mimoVoiceDescCtrl.text,
    mimoOptimizeTextPreview: _mimoOptimizeTextPreview,
    mimoVoiceCloneAudio: _mimoCloneAudioCtrl.text,
    qwenLanguageType: _qwenLanguageType,
    qwenInstructions: _qwenInstructionsCtrl.text,
    qwenOptimizeInstructions: _qwenOptimizeInstructions,
    groqSampleRate: _groqSampleRate,
    xaiLanguage: _xaiLanguage,
    xaiCodec: _xaiCodec,
    xaiSampleRate: _xaiSampleRate,
    xaiBitRate: _xaiBitRate,
    xaiTextNormalization: _xaiTextNormalization,
    xaiOptimizeStreamingLatency: _xaiOptimizeStreamingLatency,
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
    TtsProviderKind.mimo,
    TtsProviderKind.qwen,
    TtsProviderKind.groq,
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
                          min: widget.kind == TtsProviderKind.xai
                              ? 0.7
                              : (_sfHasSpeedGain ||
                                    _isElevenLabs ||
                                    widget.kind == TtsProviderKind.openai ||
                                    widget.kind == TtsProviderKind.groq)
                              ? 0.25
                              : 0.5,
                          max: widget.kind == TtsProviderKind.xai
                              ? 1.5
                              : (_sfHasSpeedGain ||
                                    _isElevenLabs ||
                                    widget.kind == TtsProviderKind.openai ||
                                    widget.kind == TtsProviderKind.groq)
                              ? 4.0
                              : 2.0,
                          divisions: widget.kind == TtsProviderKind.xai
                              ? 8
                              : (_sfHasSpeedGain ||
                                    _isElevenLabs ||
                                    widget.kind == TtsProviderKind.openai ||
                                    widget.kind == TtsProviderKind.groq)
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
      case TtsProviderKind.mimo:
        return _buildMimoVoice();
      case TtsProviderKind.qwen:
        return _buildQwenVoice();
      case TtsProviderKind.groq:
        return _buildGroqVoice();
      case TtsProviderKind.xai:
        return _buildXaiVoice();
    }
  }
}

// ---------------------------------------------------------------------------
// 3rd-level: ASR Provider Detail Page
// ---------------------------------------------------------------------------

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
