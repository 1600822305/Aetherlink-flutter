import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/features/voice/application/voice_settings_controller.dart';
import 'package:aetherlink_flutter/features/voice/domain/asr_provider_setting.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_provider_setting.dart';

/// Voice settings page — follows the project's standard settings card style
/// (`ModelSettingsCard` / `ModelSettingsAppBar` / `ModelFormField`).
class VoiceSettingsPage extends ConsumerWidget {
  const VoiceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(voiceSettingsControllerProvider);
    final ctrl = ref.read(voiceSettingsControllerProvider.notifier);

    return Scaffold(
      appBar: ModelSettingsAppBar(
        title: '语音功能',
        onBack: () => context.canPop()
            ? context.pop()
            : context.go(AppRouter.settingsPath),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          // -- TTS section ---------------------------------------------------
          _VoiceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardHeader(
                  title: '语音合成 (TTS)',
                  description: '将 AI 回复转为语音播放',
                  trailing: _StatusPill(enabled: settings.enableTts),
                ),
                Divider(height: 1, color: theme.dividerColor),
                _ToggleRow(
                  icon: LucideIcons.volume2,
                  accent: const Color(0xFF06B6D4),
                  label: '启用语音合成',
                  description: '允许将 AI 回复转为语音播放',
                  value: settings.enableTts,
                  onChanged: ctrl.setEnableTts,
                ),
                Divider(height: 1, color: theme.dividerColor),
                _SliderRow(
                  icon: LucideIcons.gauge,
                  accent: const Color(0xFF8B5CF6),
                  label: '默认播放速度',
                  value: settings.defaultSpeed,
                  min: 0.5,
                  max: 2.0,
                  divisions: 6,
                  valueLabel: '${settings.defaultSpeed}x',
                  onChanged: ctrl.setDefaultSpeed,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // TTS provider list.
          _VoiceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CardHeader(
                  title: 'TTS 服务提供商',
                  description: '选择并配置语音合成服务，长按可设为当前使用',
                ),
                Divider(height: 1, color: theme.dividerColor),
                ...TtsProviderKind.values.map((kind) {
                  final preset = defaultTtsProvider(kind);
                  final configured = settings.ttsProviders
                      .where((p) => p.kind == kind)
                      .toList();
                  final provider =
                      configured.isNotEmpty ? configured.first : preset;
                  final isActive =
                      settings.activeTtsProviderId == provider.id;

                  return _ProviderRow(
                    icon: _ttsIcon(kind),
                    accent: _ttsAccent(kind),
                    name: preset.name,
                    isActive: isActive,
                    isConfigured: configured.isNotEmpty,
                    isLast: kind == TtsProviderKind.values.last,
                    onTap: () => _pushTtsDetail(context, ref, kind, provider),
                    onSetActive: () =>
                        ctrl.setActiveTtsProvider(provider.id),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // -- ASR section ---------------------------------------------------
          _VoiceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardHeader(
                  title: '语音识别 (ASR)',
                  description: '通过麦克风输入语音并转为文字',
                  trailing: _StatusPill(enabled: settings.enableAsr),
                ),
                Divider(height: 1, color: theme.dividerColor),
                _ToggleRow(
                  icon: LucideIcons.mic,
                  accent: const Color(0xFFEC4899),
                  label: '启用语音识别',
                  description: '允许通过麦克风输入语音',
                  value: settings.enableAsr,
                  onChanged: ctrl.setEnableAsr,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ASR provider list.
          _VoiceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CardHeader(
                  title: 'ASR 服务提供商',
                  description: '选择并配置语音识别服务，长按可设为当前使用',
                ),
                Divider(height: 1, color: theme.dividerColor),
                ...AsrProviderKind.values.map((kind) {
                  final preset = defaultAsrProvider(kind);
                  final configured = settings.asrProviders
                      .where((p) => p.kind == kind)
                      .toList();
                  final provider =
                      configured.isNotEmpty ? configured.first : preset;
                  final isActive =
                      settings.activeAsrProviderId == provider.id;

                  return _ProviderRow(
                    icon: _asrIcon(kind),
                    accent: _asrAccent(kind),
                    name: preset.name,
                    isActive: isActive,
                    isConfigured: configured.isNotEmpty,
                    isLast: kind == AsrProviderKind.values.last,
                    onTap: () => _pushAsrDetail(context, ref, kind, provider),
                    onSetActive: () =>
                        ctrl.setActiveAsrProvider(provider.id),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _pushTtsDetail(
    BuildContext context,
    WidgetRef ref,
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

  void _pushAsrDetail(
    BuildContext context,
    WidgetRef ref,
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
// TTS Provider Detail Page
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
    _groupIdCtrl = TextEditingController(text: p.groupId);
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
    _groupIdCtrl.dispose();
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
    );
    ref.read(voiceSettingsControllerProvider.notifier).updateTtsProvider(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isSystem = widget.kind == TtsProviderKind.system;

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
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ModelSettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ModelSectionTitle('基本设置'),
                const SizedBox(height: 16),
                _ToggleRow(
                  icon: LucideIcons.power,
                  accent: const Color(0xFF10B981),
                  label: '启用',
                  description: '开启后此提供商可用于语音合成',
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
                if (!isSystem) ...[
                  const SizedBox(height: 16),
                  ModelFormField(
                    label: 'API Key',
                    hint: '输入 API 密钥',
                    controller: _apiKeyCtrl,
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  ModelFormField(
                    label: 'Base URL',
                    hint: '输入服务地址',
                    controller: _baseUrlCtrl,
                  ),
                  const SizedBox(height: 16),
                  ModelFormField(
                    label: '模型',
                    hint: '输入模型名称',
                    controller: _modelCtrl,
                  ),
                  const SizedBox(height: 16),
                  ModelFormField(
                    label: widget.kind == TtsProviderKind.gemini
                        ? '语音名称 (voiceName)'
                        : '语音 (voice)',
                    hint: '输入语音标识',
                    controller: _voiceCtrl,
                  ),
                  if (widget.kind == TtsProviderKind.azure) ...[
                    const SizedBox(height: 16),
                    ModelFormField(
                      label: '区域 (Region)',
                      hint: '例如 eastus',
                      controller: _regionCtrl,
                    ),
                  ],
                  if (widget.kind == TtsProviderKind.minimax) ...[
                    const SizedBox(height: 16),
                    ModelFormField(
                      label: 'Group ID',
                      hint: '输入 MiniMax Group ID',
                      controller: _groupIdCtrl,
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                _SliderRow(
                  icon: LucideIcons.gauge,
                  accent: const Color(0xFF8B5CF6),
                  label: '播放速度',
                  value: _speed,
                  min: 0.5,
                  max: 2.0,
                  divisions: 6,
                  valueLabel: '${_speed}x',
                  onChanged: (v) => setState(() => _speed = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ASR Provider Detail Page
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
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ModelSettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ModelSectionTitle('基本设置'),
                const SizedBox(height: 16),
                _ToggleRow(
                  icon: LucideIcons.power,
                  accent: const Color(0xFF10B981),
                  label: '启用',
                  description: '开启后此提供商可用于语音识别',
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
                if (!isSystem) ...[
                  const SizedBox(height: 16),
                  ModelFormField(
                    label: 'API Key',
                    hint: '输入 API 密钥',
                    controller: _apiKeyCtrl,
                    obscureText: true,
                  ),
                  if (!isRealtime) ...[
                    const SizedBox(height: 16),
                    ModelFormField(
                      label: 'Base URL',
                      hint: '输入服务地址',
                      controller: _baseUrlCtrl,
                    ),
                  ],
                  if (isRealtime) ...[
                    const SizedBox(height: 16),
                    ModelFormField(
                      label: 'WebSocket URL',
                      hint: '输入 WebSocket 地址',
                      controller: _wsUrlCtrl,
                    ),
                  ],
                  const SizedBox(height: 16),
                  ModelFormField(
                    label: '模型',
                    hint: '输入模型名称',
                    controller: _modelCtrl,
                  ),
                  if (isRealtime) ...[
                    const SizedBox(height: 20),
                    _SliderRow(
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
                    const SizedBox(height: 12),
                    _SliderRow(
                      icon: LucideIcons.timer,
                      accent: const Color(0xFFEF4444),
                      label: '静默持续时间',
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
// Shared private widgets — matching behavior_settings_page / network_proxy
// ---------------------------------------------------------------------------

class _VoiceCard extends StatelessWidget {
  const _VoiceCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.title,
    required this.description,
    this.trailing,
  });
  final String title;
  final String description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: theme.colorScheme.onSurface.withValues(alpha: 0.015),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 3),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 12.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.enabled});
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        enabled ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        enabled ? '已启用' : '已禁用',
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.accent,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final Color accent;
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    height: 1.3,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CustomSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                valueLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
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
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: valueLabel,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    required this.icon,
    required this.accent,
    required this.name,
    required this.isActive,
    required this.isConfigured,
    required this.isLast,
    required this.onTap,
    required this.onSetActive,
  });
  final IconData icon;
  final Color accent;
  final String name;
  final bool isActive;
  final bool isConfigured;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onSetActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          onLongPress: onSetActive,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
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
                Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (!isLast) Divider(height: 1, indent: 56, color: theme.dividerColor),
      ],
    );
  }
}
