import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/voice/application/asr_controller.dart';

/// Shows the voice input modal as a bottom sheet. Returns the recognized text
/// or `null` if cancelled.
Future<String?> showVoiceInputModal(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _VoiceInputSheet(),
  );
}

class _VoiceInputSheet extends ConsumerStatefulWidget {
  const _VoiceInputSheet();

  @override
  ConsumerState<_VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends ConsumerState<_VoiceInputSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Auto-start recording on open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(asrControllerProvider.notifier).startRecording();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asrState = ref.watch(asrControllerProvider);

    final isRecording = asrState.status == AsrStatus.recording;
    final isProcessing = asrState.status == AsrStatus.processing;
    final isError = asrState.status == AsrStatus.error;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle.
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Status text.
          Text(
            isRecording
                ? '正在聆听...'
                : isProcessing
                    ? '正在识别...'
                    : isError
                        ? asrState.error ?? '识别失败'
                        : '点击开始录音',
            style: theme.textTheme.titleMedium?.copyWith(
              color: isError
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // Recognized text preview.
          if (asrState.text.isNotEmpty)
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 120),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                reverse: true,
                child: Text(
                  asrState.text,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          const SizedBox(height: 24),

          // Controls row.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Cancel button.
              _CircleButton(
                icon: LucideIcons.x,
                label: '取消',
                color: theme.colorScheme.error,
                onTap: () {
                  ref.read(asrControllerProvider.notifier).cancelRecording();
                  Navigator.of(context).pop();
                },
              ),

              // Mic button (pulsing when recording).
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = isRecording
                      ? 1.0 + _pulseController.value * 0.15
                      : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: GestureDetector(
                  onTap: () async {
                    if (isRecording) {
                      await ref.read(asrControllerProvider.notifier).stopRecording();
                    } else if (!isProcessing) {
                      await ref.read(asrControllerProvider.notifier).startRecording();
                    }
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isRecording
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                      boxShadow: [
                        if (isRecording)
                          BoxShadow(
                            color: theme.colorScheme.error.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                      ],
                    ),
                    child: isProcessing
                        ? const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            ),
                          )
                        : Icon(
                            isRecording ? LucideIcons.micOff : LucideIcons.mic,
                            color: Colors.white,
                            size: 32,
                          ),
                  ),
                ),
              ),

              // Confirm button.
              _CircleButton(
                icon: LucideIcons.check,
                label: '确认',
                color: theme.colorScheme.primary,
                onTap: asrState.text.isNotEmpty
                    ? () {
                        ref.read(asrControllerProvider.notifier).cancelRecording();
                        Navigator.of(context).pop(asrState.text);
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled
                  ? color.withValues(alpha: 0.15)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.08),
            ),
            child: Icon(
              icon,
              size: 22,
              color: enabled
                  ? color
                  : theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: enabled
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
