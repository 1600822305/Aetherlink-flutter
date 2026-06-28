import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/translate_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/features/chat/domain/translate/translate_history.dart';
import 'package:aetherlink_flutter/features/chat/domain/translate/translate_language.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/model_selector_dialog.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/shared/utils/provider_icons.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

class TranslatePage extends ConsumerStatefulWidget {
  const TranslatePage({super.key});

  @override
  ConsumerState<TranslatePage> createState() => _TranslatePageState();
}

class _TranslatePageState extends ConsumerState<TranslatePage> {
  static const double _wideBreakpoint = 900;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _input = TextEditingController();

  String _output = '';
  bool _isTranslating = false;
  bool _copied = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    final text = _input.text.trim();
    if (text.isEmpty || _isTranslating) return;

    final current = await ref.read(translateModelProvider.future);
    if (!mounted) return;
    if (current == null) {
      _snack('请先在「模型」中配置可用模型');
      return;
    }
    final effective = effectiveModelFor(current);
    final targetCode = ref.read(translateTargetLanguageProvider);
    final target = translateLanguageByCode(targetCode);

    setState(() {
      _isTranslating = true;
      _output = '';
    });

    final request = LlmChatRequest(
      model: effective,
      messages: [
        LlmMessage(
          role: MessageRole.user,
          content: buildTranslatePrompt(target, text),
        ),
      ],
      extraHeaders: effective.providerExtraHeaders,
      extraBody: effective.providerExtraBody,
    );

    final gateway = ref.read(llmGatewayFactoryProvider).forModel(effective);
    final buffer = StringBuffer();
    try {
      await for (final chunk in gateway.streamChat(request)) {
        if (!mounted) return;
        switch (chunk) {
          case LlmTextDelta(:final text):
            buffer.write(text);
            setState(() => _output = buffer.toString());
          case LlmReasoningDelta():
            break;
          case LlmToolCallChunk():
            break;
          case LlmDone():
            break;
        }
      }
      final result = buffer.toString().trim();
      if (!mounted) return;
      setState(() => _output = result);
      await ref
          .read(translateHistoryStoreProvider.notifier)
          .add(
            sourceText: text,
            targetText: result,
            sourceLanguage: ref.read(translateSourceLanguageProvider),
            targetLanguage: targetCode,
          );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _output = '翻译失败: $error');
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  void _swapLanguages() {
    final source = ref.read(translateSourceLanguageProvider);
    if (source == kTranslateAutoLang) return;
    final target = ref.read(translateTargetLanguageProvider);
    ref.read(translateSourceLanguageProvider.notifier).set(target);
    ref.read(translateTargetLanguageProvider.notifier).set(source);
    setState(() {
      final text = _input.text;
      _input.text = _output;
      _output = text;
    });
  }

  Future<void> _copy() async {
    if (_output.isEmpty) return;
    await AppToast.copy(context, _output);
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _clear() {
    setState(() {
      _input.clear();
      _output = '';
    });
  }

  Future<void> _pickModel() async {
    final current = await ref.read(translateModelProvider.future);
    if (!mounted) return;
    await showModelSelectorDialog(
      context,
      selectedProviderId: current?.provider.id,
      selectedModelId: current?.model.id,
      onSelect: (provider, model) {
        ref
            .read(translateModelSelectionProvider.notifier)
            .set(provider.id, model.id);
      },
    );
  }

  void _openHistory() {
    if (MediaQuery.of(context).size.width >= _wideBreakpoint) {
      _scaffoldKey.currentState?.openEndDrawer();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.7,
        child: _HistoryPanel(onSelect: _applyHistory),
      ),
    );
  }

  void _applyHistory(TranslateHistory history) {
    ref
        .read(translateSourceLanguageProvider.notifier)
        .set(history.sourceLanguage);
    ref
        .read(translateTargetLanguageProvider.notifier)
        .set(history.targetLanguage);
    setState(() {
      _input.text = history.sourceText;
      _output = history.targetText;
    });
  }

  void _snack(String message) {
    AppToast.info(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isWide = MediaQuery.of(context).size.width >= _wideBreakpoint;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: cs.surfaceContainerLowest,
      endDrawer: isWide
          ? Drawer(width: 360, child: _HistoryPanel(onSelect: _applyHistory))
          : null,
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        centerTitle: false,
        titleSpacing: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        leadingWidth: 44,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: const Icon(LucideIcons.arrowLeft, size: 24),
            color: cs.primary,
            onPressed: () =>
                context.canPop() ? context.pop() : Navigator.of(context).pop(),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
        title: const Text('翻译'),
        actions: [
          _ModelButton(onTap: _pickModel),
          IconButton(
            onPressed: _openHistory,
            icon: const Icon(LucideIcons.history, size: 20),
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _LanguageBar(onSwap: _swapLanguages),
          Expanded(
            child: isWide
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _InputSection(
                            controller: _input,
                            isTranslating: _isTranslating,
                            isWide: true,
                            onChanged: () => setState(() {}),
                            onClear: _clear,
                            onTranslate: _translate,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _OutputSection(
                            text: _output,
                            copied: _copied,
                            isWide: true,
                            onCopy: _copy,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: _InputSection(
                          controller: _input,
                          isTranslating: _isTranslating,
                          isWide: false,
                          onChanged: () => setState(() {}),
                          onClear: _clear,
                          onTranslate: _translate,
                        ),
                      ),
                      Expanded(
                        child: _OutputSection(
                          text: _output,
                          copied: _copied,
                          isWide: false,
                          onCopy: _copy,
                        ),
                      ),
                    ],
                  ),
          ),
          SizedBox(height: bottomPad),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Model button (appbar action)
// ---------------------------------------------------------------------------

class _ModelButton extends ConsumerWidget {
  const _ModelButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final current = ref.watch(translateModelProvider).value;
    final iconPath = current == null
        ? getProviderIcon('custom', isDark: isDark)
        : getModelOrProviderIcon(
            current.model.id,
            current.provider.id,
            isDark: isDark,
          );

    return Tooltip(
      message: current?.model.name ?? current?.model.id ?? '选择模型',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.asset(
              iconPath,
              width: 20,
              height: 20,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Icon(LucideIcons.bot, size: 18),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Language bar
// ---------------------------------------------------------------------------

class _LanguageBar extends ConsumerWidget {
  const _LanguageBar({required this.onSwap});

  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final source = ref.watch(translateSourceLanguageProvider);
    final target = ref.watch(translateTargetLanguageProvider);

    final sourceLang = source == kTranslateAutoLang
        ? null
        : builtinTranslateLanguages
            .where((l) => l.langCode == source)
            .firstOrNull;
    final targetLang = builtinTranslateLanguages
        .where((l) => l.langCode == target)
        .firstOrNull;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _LanguagePill(
              emoji: sourceLang?.emoji ?? '🔍',
              label: sourceLang?.label ?? '自动检测',
              onTap: () => _pickLanguage(
                context,
                ref,
                current: source,
                showAuto: true,
                onSelect: (v) =>
                    ref.read(translateSourceLanguageProvider.notifier).set(v),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GestureDetector(
              onTap: source == kTranslateAutoLang ? null : onSwap,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  LucideIcons.arrowRightLeft,
                  size: 16,
                  color: source == kTranslateAutoLang
                      ? cs.onSurfaceVariant.withValues(alpha: 0.3)
                      : cs.primary,
                ),
              ),
            ),
          ),
          Expanded(
            child: _LanguagePill(
              emoji: targetLang?.emoji ?? '🇬🇧',
              label: targetLang?.label ?? '英文',
              onTap: () => _pickLanguage(
                context,
                ref,
                current: target,
                showAuto: false,
                onSelect: (v) =>
                    ref.read(translateTargetLanguageProvider.notifier).set(v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _pickLanguage(
    BuildContext context,
    WidgetRef ref, {
    required String current,
    required bool showAuto,
    required ValueChanged<String> onSelect,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final items = <({String code, String emoji, String label})>[
          if (showAuto) (code: kTranslateAutoLang, emoji: '🔍', label: '自动检测'),
          for (final lang in builtinTranslateLanguages)
            (code: lang.langCode, emoji: lang.emoji, label: lang.label),
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '选择语言',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    final selected = item.code == current;
                    return ListTile(
                      leading: Text(
                        item.emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                      title: Text(
                        item.label,
                        style: TextStyle(
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected ? cs.primary : cs.onSurface,
                        ),
                      ),
                      trailing: selected
                          ? Icon(LucideIcons.check, size: 18, color: cs.primary)
                          : null,
                      onTap: () {
                        onSelect(item.code);
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.chevronDown,
              size: 14,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Input section
// ---------------------------------------------------------------------------

class _InputSection extends StatelessWidget {
  const _InputSection({
    required this.controller,
    required this.isTranslating,
    required this.isWide,
    required this.onChanged,
    required this.onClear,
    required this.onTranslate,
  });

  final TextEditingController controller;
  final bool isTranslating;
  final bool isWide;
  final VoidCallback onChanged;
  final VoidCallback onClear;
  final VoidCallback onTranslate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasText = controller.text.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: isWide ? BorderRadius.circular(16) : null,
        border: isWide
            ? Border.all(color: theme.dividerColor)
            : Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.5),
                ),
              ),
        boxShadow: isWide
            ? const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // Label row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Text(
                  '原文',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${controller.text.length} 字符',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
                const Spacer(),
                if (hasText)
                  _MiniIconButton(
                    icon: LucideIcons.x,
                    onTap: onClear,
                    color: cs.onSurfaceVariant,
                  ),
              ],
            ),
          ),
          // Text field
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              expands: true,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              style: theme.textTheme.bodyLarge,
              decoration: const InputDecoration(
                hintText: '输入要翻译的文本...',
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
          // Bottom action
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _TranslateButton(
                  isTranslating: isTranslating,
                  enabled: controller.text.trim().isNotEmpty && !isTranslating,
                  onTap: onTranslate,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TranslateButton extends StatelessWidget {
  const _TranslateButton({
    required this.isTranslating,
    required this.enabled,
    required this.onTap,
  });

  final bool isTranslating;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? cs.primary : cs.onSurface.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isTranslating) ...[
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.onPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '翻译中',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onPrimary,
                ),
              ),
            ] else ...[
              Icon(
                LucideIcons.languages,
                size: 16,
                color: enabled
                    ? cs.onPrimary
                    : cs.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 6),
              Text(
                '翻译',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? cs.onPrimary
                      : cs.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Output section
// ---------------------------------------------------------------------------

class _OutputSection extends StatelessWidget {
  const _OutputSection({
    required this.text,
    required this.copied,
    required this.isWide,
    required this.onCopy,
  });

  final String text;
  final bool copied;
  final bool isWide;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasText = text.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: isWide ? BorderRadius.circular(16) : null,
        border: isWide ? Border.all(color: theme.dividerColor) : null,
        boxShadow: isWide
            ? const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // Label row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Text(
                  '译文',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                if (hasText)
                  _MiniIconButton(
                    icon: copied ? LucideIcons.check : LucideIcons.copy,
                    onTap: onCopy,
                    color: copied ? Colors.green : cs.onSurfaceVariant,
                  ),
              ],
            ),
          ),
          // Output text
          Expanded(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.topLeft,
                child: SelectableText(
                  hasText ? text : '翻译结果将显示在这里...',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: hasText
                        ? cs.onSurface
                        : cs.onSurfaceVariant.withValues(alpha: 0.5),
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mini icon button (used in label rows)
// ---------------------------------------------------------------------------

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.icon,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History panel (shared by bottom sheet and desktop drawer)
// ---------------------------------------------------------------------------

class _HistoryPanel extends ConsumerWidget {
  const _HistoryPanel({required this.onSelect});

  final void Function(TranslateHistory history) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final historiesAsync = ref.watch(translateHistoryStoreProvider);
    final histories = historiesAsync.value ?? const <TranslateHistory>[];

    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Text(
                  '翻译历史',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (histories.isNotEmpty)
                  _MiniIconButton(
                    icon: LucideIcons.trash2,
                    onTap: () => _confirmClear(context, ref),
                    color: cs.error,
                  ),
                _MiniIconButton(
                  icon: LucideIcons.x,
                  onTap: () => Navigator.of(context).maybePop(),
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child: histories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.history,
                          size: 40,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '暂无翻译历史',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: histories.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, i) {
                      final h = histories[i];
                      return _HistoryTile(
                        history: h,
                        onTap: () {
                          Navigator.of(context).maybePop();
                          onSelect(h);
                        },
                        onStar: () => ref
                            .read(translateHistoryStoreProvider.notifier)
                            .toggleStar(h.id),
                        onDelete: () => ref
                            .read(translateHistoryStoreProvider.notifier)
                            .remove(h.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const Text('确定要清空所有翻译历史吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(translateHistoryStoreProvider.notifier).clear();
    }
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.history,
    required this.onTap,
    required this.onStar,
    required this.onDelete,
  });

  final TranslateHistory history;
  final VoidCallback onTap;
  final VoidCallback onStar;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final secondary = cs.onSurfaceVariant;
    final from = translateLanguageByCode(history.sourceLanguage);
    final to = translateLanguageByCode(history.targetLanguage);
    final fromLabel = history.sourceLanguage == kTranslateAutoLang
        ? '自动检测'
        : from.label;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language + date row
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$fromLabel → ${to.label}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(history.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: secondary.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Source text
            Text(
              history.sourceText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            // Target text
            Text(
              history.targetText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: secondary.withValues(alpha: 0.7),
              ),
            ),
            // Actions row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _MiniIconButton(
                  icon:
                      history.star ? LucideIcons.star : LucideIcons.starOff,
                  onTap: onStar,
                  color: history.star ? const Color(0xFFF59E0B) : secondary,
                ),
                const SizedBox(width: 4),
                _MiniIconButton(
                  icon: LucideIcons.trash2,
                  onTap: onDelete,
                  color: secondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '${local.year}/$m/$d';
  }
}
