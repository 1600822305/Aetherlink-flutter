import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// The 翻译 page (1:1 functional port of the web `TranslatePage`).
///
/// Mobile (< 900px) lays the input above the output in a column with the
/// history shown as a bottom sheet; desktop (>= 900px) lays them side by side
/// with the history in a right drawer — matching the web's
/// `useMediaQuery(down('md'))` split. Selected languages / model and the
/// history are persisted through [translate_controller]'s providers; the
/// translation itself streams from the configured translate model.
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
    await Clipboard.setData(ClipboardData(text: _output));
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
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= _wideBreakpoint;

    final input = _InputCard(
      controller: _input,
      isWide: isWide,
      isTranslating: _isTranslating,
      onChanged: () => setState(() {}),
      onClear: _clear,
      onTranslate: _translate,
    );
    final output = _OutputCard(
      text: _output,
      isWide: isWide,
      copied: _copied,
      onCopy: _copy,
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.colorScheme.surface,
      endDrawer: isWide
          ? Drawer(width: 360, child: _HistoryPanel(onSelect: _applyHistory))
          : null,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              onBack: () => Navigator.of(context).maybePop(),
              onModel: _pickModel,
              onHistory: _openHistory,
            ),
            _LanguageBar(onSwap: _swapLanguages),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(isWide ? 16 : 0),
                child: isWide
                    ? Row(
                        children: [
                          Expanded(child: input),
                          const SizedBox(width: 16),
                          Expanded(child: output),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(child: input),
                          const Divider(height: 1),
                          Expanded(child: output),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top navigation bar: back · 翻译 title, model-picker icon, history icon.
class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.onBack,
    required this.onModel,
    required this.onHistory,
  });

  final VoidCallback onBack;
  final VoidCallback onModel;
  final VoidCallback onHistory;

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

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(LucideIcons.arrowLeft, size: 20),
          ),
          const Icon(LucideIcons.languages, size: 22),
          const SizedBox(width: 8),
          Text(
            '翻译',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Tooltip(
            message: current?.model.name ?? current?.model.id ?? '选择模型',
            child: InkWell(
              onTap: onModel,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.asset(
                    iconPath,
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Icon(LucideIcons.bot, size: 20),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onHistory,
            icon: const Icon(LucideIcons.history, size: 20),
          ),
        ],
      ),
    );
  }
}

/// Source / target language selectors with a swap button between them.
class _LanguageBar extends ConsumerWidget {
  const _LanguageBar({required this.onSwap});

  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final source = ref.watch(translateSourceLanguageProvider);
    final target = ref.watch(translateTargetLanguageProvider);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _LanguageDropdown(
            value: source,
            showAuto: true,
            onChanged: (v) =>
                ref.read(translateSourceLanguageProvider.notifier).set(v),
          ),
          IconButton(
            onPressed: source == kTranslateAutoLang ? null : onSwap,
            icon: const Icon(LucideIcons.arrowRightLeft, size: 18),
          ),
          _LanguageDropdown(
            value: target,
            showAuto: false,
            onChanged: (v) =>
                ref.read(translateTargetLanguageProvider.notifier).set(v),
          ),
        ],
      ),
    );
  }
}

class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown({
    required this.value,
    required this.showAuto,
    required this.onChanged,
  });

  final String value;
  final bool showAuto;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        borderRadius: BorderRadius.circular(8),
        items: [
          if (showAuto)
            const DropdownMenuItem(
              value: kTranslateAutoLang,
              child: Text('🔍 自动检测'),
            ),
          for (final lang in builtinTranslateLanguages)
            DropdownMenuItem(
              value: lang.langCode,
              child: Text('${lang.emoji} ${lang.label}'),
            ),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

/// The input editor with its bottom bar (char count, clear, send/stop FAB).
class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.controller,
    required this.isWide,
    required this.isTranslating,
    required this.onChanged,
    required this.onClear,
    required this.onTranslate,
  });

  final TextEditingController controller;
  final bool isWide;
  final bool isTranslating;
  final VoidCallback onChanged;
  final VoidCallback onClear;
  final VoidCallback onTranslate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Panel(
      isWide: isWide,
      background: theme.colorScheme.surface,
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              expands: true,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: '输入要翻译的文本...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '${controller.text.length} 字符',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (controller.text.isNotEmpty)
                  IconButton(
                    onPressed: onClear,
                    icon: const Icon(LucideIcons.x, size: 18),
                  ),
                const SizedBox(width: 4),
                FloatingActionButton.small(
                  heroTag: 'translate-send',
                  onPressed: (controller.text.trim().isEmpty || isTranslating)
                      ? null
                      : onTranslate,
                  child: isTranslating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(LucideIcons.send, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The output display with a copy FAB in its bottom bar.
class _OutputCard extends StatelessWidget {
  const _OutputCard({
    required this.text,
    required this.isWide,
    required this.copied,
    required this.onCopy,
  });

  final String text;
  final bool isWide;
  final bool copied;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Panel(
      isWide: isWide,
      background: theme.colorScheme.onSurface.withValues(alpha: 0.04),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  text.isEmpty ? '翻译结果将显示在这里...' : text,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: text.isEmpty
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'translate-copy',
                  elevation: 0,
                  backgroundColor: copied
                      ? Colors.green
                      : theme.colorScheme.surfaceContainerHighest,
                  foregroundColor: copied
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                  onPressed: text.isEmpty ? null : onCopy,
                  child: Icon(
                    copied ? LucideIcons.check : LucideIcons.copy,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A panel that is borderless edge-to-edge on mobile and a rounded bordered
/// card on desktop, mirroring the web `Paper` per-breakpoint styling.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.isWide,
    required this.background,
    required this.child,
  });

  final bool isWide;
  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: isWide ? BorderRadius.circular(12) : null,
        border: isWide
            ? Border.all(color: theme.dividerColor.withValues(alpha: 0.5))
            : null,
      ),
      child: ClipRRect(
        borderRadius: isWide ? BorderRadius.circular(12) : BorderRadius.zero,
        child: child,
      ),
    );
  }
}

/// The 翻译历史 list (shared by the mobile bottom sheet and desktop drawer):
/// header with 清空 / 关闭, then the records with star / delete actions.
class _HistoryPanel extends ConsumerWidget {
  const _HistoryPanel({required this.onSelect});

  final void Function(TranslateHistory history) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historiesAsync = ref.watch(translateHistoryStoreProvider);
    final histories = historiesAsync.value ?? const <TranslateHistory>[];

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Text('翻译历史', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (histories.isNotEmpty)
                  IconButton(
                    onPressed: () => _confirmClear(context, ref),
                    color: theme.colorScheme.error,
                    icon: const Icon(LucideIcons.trash2, size: 18),
                  ),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(LucideIcons.x, size: 18),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: histories.isEmpty
                ? Center(
                    child: Text(
                      '暂无翻译历史',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: histories.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
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
    final secondary = theme.colorScheme.onSurfaceVariant;
    final from = translateLanguageByCode(history.sourceLanguage);
    final to = translateLanguageByCode(history.targetLanguage);
    final fromLabel = history.sourceLanguage == kTranslateAutoLang
        ? '自动检测'
        : from.label;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '$fromLabel → ${to.label}',
                  style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                ),
                const Spacer(),
                Text(
                  _formatDate(history.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              history.sourceText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              history.targetText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onStar,
                  icon: Icon(
                    history.star ? LucideIcons.star : LucideIcons.starOff,
                    size: 16,
                    color: history.star ? const Color(0xFFF59E0B) : null,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: const Icon(LucideIcons.trash2, size: 16),
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
