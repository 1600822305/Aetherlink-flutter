import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/shared/services/llm_auto_retry.dart';

/// 「网络中断，N 秒后重试（1/3）」提示条（对齐 kelivo 气泡内倒计时）。
/// [retryKey] 无进行中的重试时不占位。点开可看触发重试的错误原文。
class LlmRetryNotice extends ConsumerWidget {
  const LlmRetryNotice({required this.retryKey, this.margin, super.key});

  final String retryKey;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      llmRetryStatusProvider.select((m) => m[retryKey]),
    );
    if (status == null) return const SizedBox.shrink();
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: _RetryBar(key: ValueKey(status.retryAt), status: status),
    );
  }
}

class _RetryBar extends StatefulWidget {
  const _RetryBar({required this.status, super.key});

  final LlmRetryStatus status;

  @override
  State<_RetryBar> createState() => _RetryBarState();
}

class _RetryBarState extends State<_RetryBar> {
  Timer? _ticker;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.status;
    final left = s.retryAt.difference(DateTime.now()).inMilliseconds;
    final seconds = (left / 1000).ceil();
    final label = seconds > 0
        ? '网络中断，$seconds 秒后重试（${s.attempt}/${s.maxRetries}）'
        : '正在重试（${s.attempt}/${s.maxRetries}）…';
    const amber = Color(0xFFB45309);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: amber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: amber.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.refreshCw, size: 13, color: amber),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(color: amber),
                  ),
                ),
              ],
            ),
            if (_expanded && s.error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  s.error,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: amber.withValues(alpha: 0.8),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
