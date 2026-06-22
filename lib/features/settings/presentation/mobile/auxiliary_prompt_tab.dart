import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/settings/application/auxiliary_model_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

/// Tab 2 — 提示词设置: 5 prompt editors (translate, title, suggestion, ocr,
/// compress) with reset-to-default. Uses Aetherlink-flutter's existing
/// collapsible card UI style.
class AuxiliaryPromptTab extends ConsumerStatefulWidget {
  const AuxiliaryPromptTab({super.key});

  @override
  ConsumerState<AuxiliaryPromptTab> createState() => _AuxiliaryPromptTabState();
}

class _AuxiliaryPromptTabState extends ConsumerState<AuxiliaryPromptTab> {
  late final TextEditingController _translateController;
  late final TextEditingController _titleController;
  late final TextEditingController _suggestionController;
  late final TextEditingController _ocrController;
  late final TextEditingController _compressController;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _translateController = TextEditingController();
    _titleController = TextEditingController();
    _suggestionController = TextEditingController();
    _ocrController = TextEditingController();
    _compressController = TextEditingController();
  }

  @override
  void dispose() {
    _translateController.dispose();
    _titleController.dispose();
    _suggestionController.dispose();
    _ocrController.dispose();
    _compressController.dispose();
    super.dispose();
  }

  void _syncControllers(AuxiliaryModelState state) {
    if (!_initialized) {
      _translateController.text = state.translatePrompt;
      _titleController.text = state.titlePrompt;
      _suggestionController.text = state.suggestionPrompt;
      _ocrController.text = state.ocrPrompt;
      _compressController.text = state.compressPrompt;
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(auxiliaryModelControllerProvider);
    final ctrl = ref.read(auxiliaryModelControllerProvider.notifier);

    _syncControllers(state);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        AuxiliaryPromptCard(
          icon: LucideIcons.languages,
          iconColor: const Color(0xFF3B82F6),
          title: '翻译提示词',
          description: '用于指导模型如何进行文本翻译',
          controller: _translateController,
          onReset: () {
            ctrl.resetTranslatePrompt();
            _translateController.text = kDefaultTranslatePrompt;
          },
          onChanged: ctrl.setTranslatePrompt,
        ),
        const SizedBox(height: 12),
        AuxiliaryPromptCard(
          icon: LucideIcons.type,
          iconColor: const Color(0xFF8B5CF6),
          title: '标题提示词',
          description: '用于指导模型如何生成对话标题',
          controller: _titleController,
          onReset: () {
            ctrl.resetTitlePrompt();
            _titleController.text = kDefaultTitlePrompt;
          },
          onChanged: ctrl.setTitlePrompt,
        ),
        const SizedBox(height: 12),
        AuxiliaryPromptCard(
          icon: LucideIcons.lightbulb,
          iconColor: const Color(0xFF10B981),
          title: '建议提示词',
          description: '用于指导模型如何生成后续问题建议',
          controller: _suggestionController,
          onReset: () {
            ctrl.resetSuggestionPrompt();
            _suggestionController.text = kDefaultSuggestionPrompt;
          },
          onChanged: ctrl.setSuggestionPrompt,
        ),
        const SizedBox(height: 12),
        AuxiliaryPromptCard(
          icon: LucideIcons.eye,
          iconColor: const Color(0xFFEC4899),
          title: 'OCR 提示词',
          description: '用于指导视觉模型如何描述图片内容',
          controller: _ocrController,
          onReset: () {
            ctrl.resetOcrPrompt();
            _ocrController.text = kDefaultOcrPrompt;
          },
          onChanged: ctrl.setOcrPrompt,
        ),
        const SizedBox(height: 12),
        AuxiliaryPromptCard(
          icon: LucideIcons.foldVertical,
          iconColor: const Color(0xFF14B8A6),
          title: '压缩提示词',
          description: '用于指导模型如何压缩对话历史',
          controller: _compressController,
          onReset: () {
            ctrl.resetCompressPrompt();
            _compressController.text = kDefaultCompressPrompt;
          },
          onChanged: ctrl.setCompressPrompt,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable building block
// ─────────────────────────────────────────────────────────────────────────────

/// A collapsible card with a prompt editor and a reset button.
class AuxiliaryPromptCard extends StatefulWidget {
  const AuxiliaryPromptCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.controller,
    required this.onReset,
    this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final TextEditingController controller;
  final VoidCallback onReset;
  final ValueChanged<String>? onChanged;

  @override
  State<AuxiliaryPromptCard> createState() => _AuxiliaryPromptCardState();
}

class _AuxiliaryPromptCardState extends State<AuxiliaryPromptCard> {
  bool _expanded = false;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.all(14),
              color: theme.colorScheme.onSurface.withValues(alpha: 0.015),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: widget.iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon, size: 18, color: widget.iconColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12.5,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: widget.controller,
                    maxLines: 8,
                    minLines: 3,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
                    onChanged: widget.onChanged,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '输入自定义提示词...',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ModelTonalButton(
                      label: '恢复默认',
                      icon: LucideIcons.rotateCcw,
                      onPressed: () {
                        widget.onReset();
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
