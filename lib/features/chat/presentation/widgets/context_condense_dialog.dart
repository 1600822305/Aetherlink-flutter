import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/context_condense_service.dart';

/// Shows the context compression dialog. Returns the [CondenseResult] or null
/// if cancelled.
Future<CondenseResult?> showContextCondenseDialog(BuildContext context) {
  return showDialog<CondenseResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ContextCondenseDialog(),
  );
}

class _ContextCondenseDialog extends ConsumerStatefulWidget {
  const _ContextCondenseDialog();

  @override
  ConsumerState<_ContextCondenseDialog> createState() =>
      _ContextCondenseDialogState();
}

class _ContextCondenseDialogState
    extends ConsumerState<_ContextCondenseDialog> {
  bool _showAdvanced = false;
  bool _isCompressing = false;
  String _statusText = '';
  CancelToken? _cancelToken;

  // Advanced options
  int _keepRecentMessages = 3;
  int _targetTokens = 2000;
  final TextEditingController _additionalPromptController =
      TextEditingController();

  static const _keepOptions = [0, 3, 8, 16];
  static const _tokenOptions = [500, 1000, 2000, 4000];

  @override
  void dispose() {
    _cancelToken?.cancel();
    _additionalPromptController.dispose();
    super.dispose();
  }

  Future<void> _startCompress() async {
    final cancelToken = CancelToken();
    setState(() {
      _isCompressing = true;
      _statusText = '准备中…';
      _cancelToken = cancelToken;
    });

    final service = ref.read(contextCondenseServiceProvider);
    final result = await service.compress(
      options: CondenseOptions(
        keepRecentMessages: _keepRecentMessages,
        targetTokens: _targetTokens,
        additionalPrompt: _additionalPromptController.text,
      ),
      onProgress: (status) {
        if (mounted) setState(() => _statusText = status);
      },
      cancelToken: cancelToken,
    );

    if (!mounted) return;

    if (result.success) {
      Navigator.of(context).pop(result);
    } else {
      // If cancelled, just close
      if (cancelToken.isCancelled) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _isCompressing = false;
        _statusText = '';
        _cancelToken = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? '压缩失败'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _cancel() {
    _cancelToken?.cancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: _isCompressing
              ? _buildCompressing(cs)
              : _buildForm(cs, isDark),
        ),
      ),
    );
  }

  Widget _buildCompressing(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 3, color: cs.primary),
        ),
        const SizedBox(height: 16),
        Text(_statusText, style: TextStyle(fontSize: 14, color: cs.onSurface)),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _cancel,
          child: const Text('取消'),
        ),
      ],
    );
  }

  Widget _buildForm(ColorScheme cs, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            Icon(LucideIcons.scrollText, size: 20, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '压缩上下文',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '将对话历史压缩为精简摘要，释放上下文空间，同时保留关键信息。',
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),

        // Advanced toggle
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _showAdvanced = !_showAdvanced),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  _showAdvanced
                      ? LucideIcons.chevronDown
                      : LucideIcons.chevronRight,
                  size: 16,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  '高级选项',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Advanced options
        if (_showAdvanced) ...[
          const SizedBox(height: 8),
          _buildSegmentLabel('保留最近消息数', cs),
          const SizedBox(height: 6),
          _buildSegmentRow(
            options: _keepOptions,
            selected: _keepRecentMessages,
            onSelect: (v) => setState(() => _keepRecentMessages = v),
            labelBuilder: (v) => '$v',
            cs: cs,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildSegmentLabel('目标 Token 数', cs),
          const SizedBox(height: 6),
          _buildSegmentRow(
            options: _tokenOptions,
            selected: _targetTokens,
            onSelect: (v) => setState(() => _targetTokens = v),
            labelBuilder: (v) => '$v',
            cs: cs,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildSegmentLabel('附加指令（可选）', cs),
          const SizedBox(height: 6),
          TextField(
            controller: _additionalPromptController,
            maxLines: 3,
            style: TextStyle(fontSize: 13, color: cs.onSurface),
            decoration: InputDecoration(
              hintText: '例如：重点保留代码相关的讨论',
              hintStyle: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.35),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: cs.primary),
              ),
            ),
          ),
        ],

        // Warning
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.triangleAlert, size: 14, color: cs.error),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '压缩后被替换的消息将无法恢复',
                style: TextStyle(fontSize: 12, color: cs.error),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _startCompress,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('开始压缩'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSegmentLabel(String label, ColorScheme cs) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: cs.onSurface.withValues(alpha: 0.6),
      ),
    );
  }

  Widget _buildSegmentRow({
    required List<int> options,
    required int selected,
    required ValueChanged<int> onSelect,
    required String Function(int) labelBuilder,
    required ColorScheme cs,
    required bool isDark,
  }) {
    return Row(
      children: options.map((opt) {
        final isSelected = opt == selected;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: opt == options.last ? 0 : 6),
            child: GestureDetector(
              onTap: () => onSelect(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? cs.primary.withValues(alpha: isDark ? 0.25 : 0.12)
                      : cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? cs.primary.withValues(alpha: 0.5)
                        : cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  labelBuilder(opt),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
