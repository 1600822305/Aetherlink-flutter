import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/agent_prompt_selector.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

/// The three edit modes of the 系统提示词设置 dialog (web `EditMode`).
enum _EditMode { combined, assistant, topic }

/// Opens the 系统提示词设置 dialog for [assistant] / [topic]. 1:1 port of the web
/// `SystemPromptDialog` (`src/components/dialogs/SystemPromptDialog.tsx`):
/// 组合预览 / 助手提示词 / 话题提示词 modes, live Token estimate and smart save.
Future<void> showSystemPromptDialog(
  BuildContext context, {
  required Assistant? assistant,
  required Topic? topic,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0x80000000),
    // The mobile layout is a full-screen sheet whose surface must reach behind
    // the status bar and system navigation bar; the default useSafeArea would
    // inset the whole dialog and leave those bands showing the page behind it.
    // The inner SafeArea around the body still keeps content clear of the bars.
    useSafeArea: false,
    builder: (_) => _SystemPromptDialog(assistant: assistant, topic: topic),
  );
}

/// Smart token estimate — `estimateTokens` (CJK ×2, latin words ×1.3).
int estimateSystemPromptTokens(String text) {
  if (text.isEmpty) return 0;
  final words = RegExp(r'\b\w+\b').allMatches(text).length;
  final cjk = RegExp(
    r'[\u4e00-\u9fa5\u3040-\u309f\u30a0-\u30ff]',
  ).allMatches(text).length;
  return (words * 1.3 + cjk * 2).ceil();
}

class _SystemPromptDialog extends ConsumerStatefulWidget {
  const _SystemPromptDialog({required this.assistant, required this.topic});

  final Assistant? assistant;
  final Topic? topic;

  @override
  ConsumerState<_SystemPromptDialog> createState() =>
      _SystemPromptDialogState();
}

class _SystemPromptDialogState extends ConsumerState<_SystemPromptDialog> {
  final TextEditingController _controller = TextEditingController();
  late _EditMode _editMode;
  bool _saving = false;
  int _tokensCount = 0;
  String? _error;

  Assistant? get _assistant => widget.assistant;
  Topic? get _topic => widget.topic;

  bool get _hasAssistantPrompt => (_assistant?.systemPrompt ?? '').isNotEmpty;
  bool get _hasTopicPrompt => (_topic?.prompt ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Smart initial mode (web useEffect on open).
    final _EditMode initialMode;
    if (_hasAssistantPrompt && !_hasTopicPrompt) {
      initialMode = _EditMode.assistant;
    } else if (!_hasAssistantPrompt && _hasTopicPrompt) {
      initialMode = _EditMode.topic;
    } else {
      initialMode = _EditMode.combined;
    }
    _editMode = initialMode;
    final initialPrompt = _promptForMode(initialMode);
    _controller.text = initialPrompt;
    _tokensCount = estimateSystemPromptTokens(initialPrompt);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The prompt text shown for [mode] — shared by init and mode switching.
  String _promptForMode(_EditMode mode) {
    switch (mode) {
      case _EditMode.assistant:
        return _assistant?.systemPrompt ?? '';
      case _EditMode.topic:
        return _topic?.prompt ?? '';
      case _EditMode.combined:
        final assistantPrompt = _assistant?.systemPrompt;
        final topicPrompt = _topic?.prompt;
        if (assistantPrompt != null && assistantPrompt.isNotEmpty) {
          if (topicPrompt != null && topicPrompt.trim().isNotEmpty) {
            return '$assistantPrompt\n\n[追加] $topicPrompt';
          }
          return assistantPrompt;
        } else if (topicPrompt != null && topicPrompt.trim().isNotEmpty) {
          return topicPrompt;
        }
        return '点击此处编辑系统提示词';
    }
  }

  /// 当前编辑目标描述 (web `getSaveTarget`).
  String get _saveTarget {
    switch (_editMode) {
      case _EditMode.assistant:
        return '助手提示词';
      case _EditMode.topic:
        return '话题提示词';
      case _EditMode.combined:
        if (_hasAssistantPrompt && _hasTopicPrompt) {
          return '组合提示词（需选择具体编辑目标）';
        } else if (_hasAssistantPrompt) {
          return '助手提示词';
        } else if (_hasTopicPrompt) {
          return '话题提示词';
        }
        return '新提示词';
    }
  }

  void _changeMode(_EditMode mode) {
    final next = _promptForMode(mode);
    setState(() {
      _editMode = mode;
      _controller.text = next;
      _tokensCount = estimateSystemPromptTokens(next);
    });
  }

  void _onPromptChanged(String text) {
    setState(() => _tokensCount = estimateSystemPromptTokens(text));
  }

  Future<void> _pickPreset() async {
    final selected = await showAgentPromptSelector(context);
    if (selected == null || !mounted) return;
    setState(() {
      _controller.text = selected;
      _tokensCount = estimateSystemPromptTokens(selected);
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final trimmed = _controller.text.trim();
      switch (_editMode) {
        case _EditMode.assistant:
          final assistant = _assistant;
          if (assistant == null) {
            throw StateError('没有找到助手信息');
          }
          await ref
              .read(assistantsProvider.notifier)
              .updateSystemPrompt(assistant.id, trimmed);
        case _EditMode.topic:
          await _saveToTopic(trimmed);
        case _EditMode.combined:
          if (_hasAssistantPrompt && !_hasTopicPrompt) {
            await ref
                .read(assistantsProvider.notifier)
                .updateSystemPrompt(_assistant!.id, trimmed);
          } else {
            await _saveToTopic(trimmed);
          }
      }
      // The bubble reads currentTopic, which does not watch topicsProvider —
      // refresh it so the appended 话题提示词 shows immediately after save.
      ref.invalidate(currentTopicProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError ? error.message : '保存系统提示词失败',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// web `handleSaveToTopic`: update the topic's prompt, creating a new topic
  /// first when there is none but an assistant exists.
  Future<void> _saveToTopic(String content) async {
    final topic = _topic;
    final assistant = _assistant;
    if (topic == null) {
      if (assistant == null) return;
      await ref
          .read(topicsProvider.notifier)
          .setPrompt(assistantId: assistant.id, prompt: content);
      return;
    }
    await ref
        .read(topicsProvider.notifier)
        .setPrompt(
          topicId: topic.id,
          assistantId: assistant?.id,
          prompt: content,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final isMobile = mq.size.width < 600;
    final combined = _editMode == _EditMode.combined;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _title(theme, isMobile),
        if (isMobile)
          Expanded(child: _content(theme, isMobile, combined))
        else
          SizedBox(
            height: math
                .min(mq.size.height * 0.7, mq.size.height - 160)
                .clamp(320, double.infinity),
            child: _content(theme, isMobile, combined),
          ),
        _actions(theme, isMobile, combined),
      ],
    );

    if (isMobile) {
      return Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: theme.colorScheme.surface,
        shape: const RoundedRectangleBorder(),
        child: SafeArea(child: body),
      );
    }
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: body,
      ),
    );
  }

  // ---- Title ----------------------------------------------------------------

  Widget _title(ThemeData theme, bool isMobile) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 12, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '系统提示词设置',
              style: TextStyle(
                fontSize: isMobile ? 20 : 16,
                fontWeight: isMobile ? FontWeight.w500 : FontWeight.w400,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            iconSize: 22,
            color: theme.colorScheme.onSurface,
            icon: const Icon(LucideIcons.x),
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }

  // ---- Content --------------------------------------------------------------

  Widget _content(ThemeData theme, bool isMobile, bool combined) {
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        16,
        isMobile ? 16 : 24,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            _Alert(message: _error!, severity: _AlertSeverity.error),
            const SizedBox(height: 16),
          ],
          if (_topic == null && !_saving) ...[
            const _Alert(
              message: '保存将创建新话题并应用此系统提示词',
              severity: _AlertSeverity.info,
            ),
            const SizedBox(height: 16),
          ],
          Text(
            '编辑模式',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          _modeToggle(theme, isMobile),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '当前编辑: $_saveTarget',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 11,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: combined ? null : _pickPreset,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('选择预设提示词'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, thickness: 1, color: theme.dividerColor),
          const SizedBox(height: 16),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: _onPromptChanged,
              enabled: !combined,
              autofocus: !isMobile,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(fontSize: isMobile ? 16 : 14, height: 1.5),
              decoration: InputDecoration(
                hintText: combined ? '组合预览（只读）' : '输入系统提示词...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    combined ? '预览模式：显示最终生效的提示词' : '编辑模式：修改后点击保存',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ),
                Text(
                  '估计Token数量: $_tokensCount',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeToggle(ThemeData theme, bool isMobile) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Expanded(
              child: _modeButton(
                theme,
                isMobile,
                mode: _EditMode.combined,
                icon: LucideIcons.messageSquare,
                label: '组合预览',
              ),
            ),
            _toggleDivider(theme),
            Expanded(
              child: _modeButton(
                theme,
                isMobile,
                mode: _EditMode.assistant,
                icon: LucideIcons.user,
                label: '助手提示词',
                disabled: _assistant == null,
              ),
            ),
            _toggleDivider(theme),
            Expanded(
              child: _modeButton(
                theme,
                isMobile,
                mode: _EditMode.topic,
                icon: LucideIcons.messageSquare,
                label: '话题提示词',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleDivider(ThemeData theme) => SizedBox(
    width: 1,
    height: 32,
    child: ColoredBox(color: theme.dividerColor),
  );

  Widget _modeButton(
    ThemeData theme,
    bool isMobile, {
    required _EditMode mode,
    required IconData icon,
    required String label,
    bool disabled = false,
  }) {
    final selected = _editMode == mode;
    final onSurface = theme.colorScheme.onSurface;
    final Color fg = disabled
        ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
        : selected
        ? onSurface
        : theme.colorScheme.onSurfaceVariant;
    final iconSize = isMobile ? 16.0 : 14.0;
    return InkWell(
      onTap: disabled ? null : () => _changeMode(mode),
      child: Container(
        constraints: BoxConstraints(minHeight: isMobile ? 40 : 32),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 12,
          vertical: isMobile ? 8 : 4,
        ),
        color: selected
            ? theme.colorScheme.onSurface.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: iconSize, color: fg),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isMobile ? 14 : 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Actions --------------------------------------------------------------

  Widget _actions(ThemeData theme, bool isMobile, bool combined) {
    return Container(
      padding: isMobile
          ? const EdgeInsets.fromLTRB(24, 16, 24, 16)
          : const EdgeInsets.fromLTRB(24, 8, 24, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurface,
            ),
            child: const Text('取消'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: (_saving || combined) ? null : _save,
            child: Text(_saving ? '保存中...' : '保存到$_saveTarget'),
          ),
        ],
      ),
    );
  }
}

enum _AlertSeverity { error, info }

/// A minimal MUI `<Alert>` stand-in (error / info severities).
class _Alert extends StatelessWidget {
  const _Alert({required this.message, required this.severity});

  final String message;
  final _AlertSeverity severity;

  @override
  Widget build(BuildContext context) {
    final isError = severity == _AlertSeverity.error;
    final Color accent = isError
        ? const Color(0xFFEF4444)
        : const Color(0xFF0288D1);
    final icon = isError ? LucideIcons.circleAlert : LucideIcons.info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: accent.withValues(alpha: 0.12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(fontSize: 14, color: accent)),
          ),
        ],
      ),
    );
  }
}
