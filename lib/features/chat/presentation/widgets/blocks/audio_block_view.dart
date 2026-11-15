import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';

/// Inline audio player for generated audio (`FILE` blocks with an `audio/*`
/// mime — audio has no dedicated block type in the generated union).
/// Sources are either the inline base64 payload (decoded to a temp file, the
/// same write-then-play flow as `_loadVideoSource`) or a remote URL.
class AudioBlockView extends StatefulWidget {
  const AudioBlockView({required this.block, super.key});

  final FileBlock block;

  @override
  State<AudioBlockView> createState() => _AudioBlockViewState();
}

class _AudioBlockViewState extends State<AudioBlockView> {
  final AudioPlayer _player = AudioPlayer();
  File? _tempFile;
  String? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initSource());
  }

  Future<void> _initSource() async {
    try {
      final dataUri = widget.block.file?.base64Data ?? '';
      final url = widget.block.url;
      if (dataUri.startsWith('data:')) {
        final marker = dataUri.indexOf(';base64,');
        if (marker == -1) throw StateError('empty audio payload');
        final bytes = base64Decode(dataUri.substring(marker + 8));
        if (bytes.isEmpty) throw StateError('empty audio payload');
        final dir = await getTemporaryDirectory();
        final file = File(
          '${dir.path}/gen_audio_${widget.block.id}${_ext(widget.block.mimeType)}',
        );
        await file.writeAsBytes(bytes, flush: true);
        _tempFile = file;
        await _player.setFilePath(file.path);
      } else if (url.startsWith('http://') || url.startsWith('https://')) {
        await _player.setUrl(url);
      } else {
        throw StateError('no playable audio source');
      }
      if (mounted) setState(() => _ready = true);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  static String _ext(String mimeType) => switch (mimeType) {
    'audio/ogg' => '.ogg',
    'audio/aac' => '.aac',
    'audio/flac' => '.flac',
    'audio/wav' => '.wav',
    _ => '.mp3',
  };

  @override
  void dispose() {
    _player.dispose();
    unawaited(_tempFile?.delete().catchError((_) => _tempFile!));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_error != null) {
      return _card(
        theme,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.volumeOff,
              size: 18,
              color: theme.colorScheme.error,
            ),
            const SizedBox(width: 8),
            Text(
              '音频不可用',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      );
    }

    return _card(
      theme,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (context, snap) {
              final playing = snap.data?.playing ?? false;
              final processing = snap.data?.processingState;
              final buffering =
                  processing == ProcessingState.loading ||
                  processing == ProcessingState.buffering ||
                  !_ready;
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: buffering
                    ? null
                    : () =>
                        playing ? _player.pause() : unawaited(_player.play()),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  ),
                  child: buffering
                      ? const Padding(
                          padding: EdgeInsets.all(9),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          playing ? LucideIcons.pause : LucideIcons.play,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Flexible(
            child: StreamBuilder<Duration?>(
              stream: _player.durationStream,
              builder: (context, durationSnap) {
                final total = durationSnap.data ?? Duration.zero;
                return StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  builder: (context, posSnap) {
                    final pos = posSnap.data ?? Duration.zero;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 20,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 5,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 10,
                              ),
                            ),
                            child: Slider(
                              value: total.inMilliseconds <= 0
                                  ? 0
                                  : (pos.inMilliseconds / total.inMilliseconds)
                                        .clamp(0.0, 1.0),
                              onChanged: total.inMilliseconds <= 0
                                  ? null
                                  : (v) => _player.seek(
                                      Duration(
                                        milliseconds:
                                            (v * total.inMilliseconds).round(),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        Text(
                          '${_fmt(pos)} / ${_fmt(total)}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(ThemeData theme, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: DefaultTextStyle(
        style:
            theme.textTheme.bodySmall ??
            const TextStyle(fontSize: 12, color: Colors.black),
        child: child,
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
