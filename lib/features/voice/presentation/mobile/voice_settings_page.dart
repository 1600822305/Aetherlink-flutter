import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/voice/application/voice_settings_controller.dart';
import 'package:aetherlink_flutter/features/voice/domain/asr_provider_setting.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_provider_setting.dart';
import 'package:aetherlink_flutter/features/voice/domain/voice_settings.dart';

/// Voice settings page with dual-tab layout: TTS providers and ASR providers.
/// Follows the visual patterns of `appearance_settings_page.dart` and mirrors
/// the original AetherLink web's `VoiceSettingsV2` structure.
class VoiceSettingsPage extends ConsumerStatefulWidget {
  const VoiceSettingsPage({super.key});

  @override
  ConsumerState<VoiceSettingsPage> createState() => _VoiceSettingsPageState();
}

class _VoiceSettingsPageState extends ConsumerState<VoiceSettingsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(voiceSettingsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('语音功能'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(LucideIcons.volume2), text: '语音合成 (TTS)'),
            Tab(icon: Icon(LucideIcons.mic), text: '语音识别 (ASR)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TtsTab(settings: settings),
          _AsrTab(settings: settings),
        ],
      ),
    );
  }
}

// -- TTS Tab -----------------------------------------------------------------

class _TtsTab extends ConsumerWidget {
  const _TtsTab({required this.settings});
  final VoiceSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ctrl = ref.read(voiceSettingsControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Global TTS toggle.
        SwitchListTile(
          title: const Text('启用语音合成'),
          subtitle: const Text('允许将 AI 回复转为语音播放'),
          value: settings.enableTts,
          onChanged: ctrl.setEnableTts,
        ),

        const SizedBox(height: 8),

        // Speed control.
        ListTile(
          title: const Text('默认播放速度'),
          trailing: Text(
            '${settings.defaultSpeed}x',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Slider(
          value: settings.defaultSpeed,
          min: 0.5,
          max: 2.0,
          divisions: 6,
          label: '${settings.defaultSpeed}x',
          onChanged: ctrl.setDefaultSpeed,
        ),

        const Divider(height: 32),

        // Provider list header.
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'TTS 服务提供商',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Provider cards.
        ...TtsProviderKind.values.map((kind) {
          final preset = defaultTtsProvider(kind);
          final configured = settings.ttsProviders
              .where((TtsProviderSetting p) => p.kind == kind)
              .toList();
          final provider = configured.isNotEmpty ? configured.first : preset;
          final isActive = settings.activeTtsProviderId == provider.id;

          return _ProviderCard(
            name: preset.name,
            icon: _ttsIcon(kind),
            isActive: isActive,
            isConfigured: configured.isNotEmpty,
            onTap: () => _showTtsProviderDetail(context, ref, kind, provider),
            onSetActive: () => ctrl.setActiveTtsProvider(provider.id),
          );
        }),
      ],
    );
  }

  void _showTtsProviderDetail(
    BuildContext context,
    WidgetRef ref,
    TtsProviderKind kind,
    TtsProviderSetting provider,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _TtsProviderDetailPage(kind: kind, provider: provider),
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
}

// -- ASR Tab -----------------------------------------------------------------

class _AsrTab extends ConsumerWidget {
  const _AsrTab({required this.settings});
  final VoiceSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ctrl = ref.read(voiceSettingsControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('启用语音识别'),
          subtitle: const Text('允许通过麦克风输入语音'),
          value: settings.enableAsr,
          onChanged: ctrl.setEnableAsr,
        ),

        const Divider(height: 32),

        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'ASR 服务提供商',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        ...AsrProviderKind.values.map((kind) {
          final preset = defaultAsrProvider(kind);
          final configured = settings.asrProviders
              .where((AsrProviderSetting p) => p.kind == kind)
              .toList();
          final provider = configured.isNotEmpty ? configured.first : preset;
          final isActive = settings.activeAsrProviderId == provider.id;

          return _ProviderCard(
            name: preset.name,
            icon: _asrIcon(kind),
            isActive: isActive,
            isConfigured: configured.isNotEmpty,
            onTap: () => _showAsrProviderDetail(context, ref, kind, provider),
            onSetActive: () => ctrl.setActiveAsrProvider(provider.id),
          );
        }),
      ],
    );
  }

  void _showAsrProviderDetail(
    BuildContext context,
    WidgetRef ref,
    AsrProviderKind kind,
    AsrProviderSetting provider,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AsrProviderDetailPage(kind: kind, provider: provider),
      ),
    );
  }

  static IconData _asrIcon(AsrProviderKind kind) => switch (kind) {
    AsrProviderKind.system => LucideIcons.smartphone,
    AsrProviderKind.openaiRealtime => LucideIcons.radio,
    AsrProviderKind.whisper => LucideIcons.audioWaveform,
  };
}

// -- Shared provider card ----------------------------------------------------

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.name,
    required this.icon,
    required this.isActive,
    required this.isConfigured,
    required this.onTap,
    required this.onSetActive,
  });

  final String name;
  final IconData icon;
  final bool isActive;
  final bool isConfigured;
  final VoidCallback onTap;
  final VoidCallback onSetActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive
            ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '当前使用',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            const Icon(LucideIcons.chevronRight, size: 18),
          ],
        ),
        onTap: onTap,
        onLongPress: onSetActive,
      ),
    );
  }
}

// -- TTS Provider Detail Page ------------------------------------------------

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

class _TtsProviderDetailPageState extends ConsumerState<_TtsProviderDetailPage> {
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _baseUrlCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _voiceCtrl;
  late final TextEditingController _regionCtrl;
  late bool _enabled;
  late double _speed;

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
    _enabled = p.enabled;
    _speed = p.speed;
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _baseUrlCtrl.dispose();
    _modelCtrl.dispose();
    _voiceCtrl.dispose();
    _regionCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final updated = widget.provider.copyWith(
      enabled: _enabled,
      apiKey: _apiKeyCtrl.text.trim(),
      baseUrl: _baseUrlCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      voice: widget.kind == TtsProviderKind.gemini ? '' : _voiceCtrl.text.trim(),
      voiceName: widget.kind == TtsProviderKind.gemini
          ? _voiceCtrl.text.trim()
          : '',
      region: _regionCtrl.text.trim(),
      speed: _speed,
    );
    ref.read(voiceSettingsControllerProvider.notifier).updateTtsProvider(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isSystem = widget.kind == TtsProviderKind.system;

    return Scaffold(
      appBar: AppBar(
        title: Text(defaultTtsProvider(widget.kind).name),
        actions: [
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('启用'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),

          if (!isSystem) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyCtrl,
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _baseUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _modelCtrl,
              decoration: const InputDecoration(
                labelText: '模型',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _voiceCtrl,
              decoration: InputDecoration(
                labelText: widget.kind == TtsProviderKind.gemini
                    ? '语音名称 (voiceName)'
                    : '语音 (voice)',
                border: const OutlineInputBorder(),
              ),
            ),
            if (widget.kind == TtsProviderKind.azure) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _regionCtrl,
                decoration: const InputDecoration(
                  labelText: '区域 (Region)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],

          const SizedBox(height: 16),
          ListTile(
            title: const Text('播放速度'),
            trailing: Text('${_speed}x'),
          ),
          Slider(
            value: _speed,
            min: 0.5,
            max: 2.0,
            divisions: 6,
            label: '${_speed}x',
            onChanged: (v) => setState(() => _speed = v),
          ),
        ],
      ),
    );
  }
}

// -- ASR Provider Detail Page ------------------------------------------------

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

class _AsrProviderDetailPageState extends ConsumerState<_AsrProviderDetailPage> {
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
    ref.read(voiceSettingsControllerProvider.notifier).updateAsrProvider(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isSystem = widget.kind == AsrProviderKind.system;
    final isRealtime = widget.kind == AsrProviderKind.openaiRealtime;

    return Scaffold(
      appBar: AppBar(
        title: Text(defaultAsrProvider(widget.kind).name),
        actions: [
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('启用'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),

          if (!isSystem) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyCtrl,
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            if (!isRealtime) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _baseUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (isRealtime) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _wsUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'WebSocket URL',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _modelCtrl,
              decoration: const InputDecoration(
                labelText: '模型',
                border: OutlineInputBorder(),
              ),
            ),
            if (isRealtime) ...[
              const SizedBox(height: 24),
              ListTile(
                title: const Text('VAD 阈值'),
                trailing: Text(_vadThreshold.toStringAsFixed(2)),
              ),
              Slider(
                value: _vadThreshold,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                label: _vadThreshold.toStringAsFixed(2),
                onChanged: (v) => setState(() => _vadThreshold = v),
              ),
              ListTile(
                title: const Text('静默持续时间 (ms)'),
                trailing: Text('$_silenceDurationMs'),
              ),
              Slider(
                value: _silenceDurationMs.toDouble(),
                min: 100,
                max: 2000,
                divisions: 19,
                label: '$_silenceDurationMs ms',
                onChanged: (v) =>
                    setState(() => _silenceDurationMs = v.round()),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
