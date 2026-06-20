import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_search_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/search/chat_search.dart';

/// Opens the 聊天搜索 modal — the Flutter port of the web `ChatSearchInterface`
/// (`src/components/search/ChatSearchInterface.tsx`). Selecting a hit switches
/// the current topic (and its owning assistant) and closes the dialog.
///
/// Jump-to-message-by-id is intentionally out of scope (the chat view has no
/// scroll-to-message mechanism yet), so a message hit lands on its topic, like
/// a topic hit.
Future<void> showChatSearchDialog(BuildContext context) {
  // Drop the chat input's focus first so opening the dialog doesn't immediately
  // raise the keyboard, and closing it doesn't re-focus the input box on the
  // way back to chat (mirrors `showModelSelectorDialog`).
  FocusManager.instance.primaryFocus?.unfocus();
  return showGeneralDialog<void>(
    context: context,
    barrierColor: const Color(0x80000000),
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    pageBuilder: (context, _, _) => const _ChatSearchDialog(),
    transitionBuilder: (context, animation, _, child) => child,
    transitionDuration: Duration.zero,
  );
}

const String _searchHint = '搜索话题和消息…(用 " " 包裹精确短语)';
const Duration _debounce = Duration(milliseconds: 300);

class _ChatSearchDialog extends ConsumerStatefulWidget {
  const _ChatSearchDialog();

  @override
  ConsumerState<_ChatSearchDialog> createState() => _ChatSearchDialogState();
}

class _ChatSearchDialogState extends ConsumerState<_ChatSearchDialog> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = <int, GlobalKey>{};
  late final FocusNode _fieldFocus = FocusNode(onKeyEvent: _onFieldKey);

  ChatSearchMode _mode = ChatSearchMode.and;
  String _pendingQuery = '';
  String _committedQuery = '';
  int _activeIndex = 0;
  Timer? _debounceTimer;
  List<ChatSearchHit> _hits = const <ChatSearchHit>[];
  String? _recordedQuery;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() {
      _pendingQuery = value;
      _activeIndex = 0;
    });
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      if (!mounted) return;
      setState(() => _committedQuery = value);
    });
  }

  void _setQueryImmediately(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
    _debounceTimer?.cancel();
    setState(() {
      _pendingQuery = value;
      _committedQuery = value;
      _activeIndex = 0;
    });
  }

  int get _safeActiveIndex =>
      _hits.isEmpty ? 0 : _activeIndex.clamp(0, _hits.length - 1);

  void _select(ChatSearchHit hit) {
    if (hit.assistantId != null) {
      ref.read(currentAssistantIdProvider.notifier).set(hit.assistantId);
    }
    ref.read(currentTopicIdProvider.notifier).set(hit.topicId);
    Navigator.of(context).pop();
  }

  KeyEventResult _onFieldKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    if (_hits.isEmpty) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(
        () => _activeIndex = (_safeActiveIndex + 1).clamp(0, _hits.length - 1),
      );
      _scrollActiveIntoView();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(
        () => _activeIndex = (_safeActiveIndex - 1).clamp(0, _hits.length - 1),
      );
      _scrollActiveIntoView();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _select(_hits[_safeActiveIndex]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _scrollActiveIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _itemKeys[_safeActiveIndex]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 120),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final isNarrow = size.width < 600;

    final committed = _committedQuery.trim();
    final hasQuery = committed.isNotEmpty;
    final request = ChatSearchRequest(query: _committedQuery, mode: _mode);
    final resultsAsync = hasQuery
        ? ref.watch(chatSearchResultsProvider(request))
        : null;
    final recent = ref.watch(chatSearchRecentProvider);

    final results = resultsAsync?.asData?.value;
    _hits = results?.hits ?? const <ChatSearchHit>[];
    _itemKeys.clear();

    final isDebouncing = _pendingQuery.trim() != committed;
    final isSearching =
        hasQuery && (isDebouncing || (resultsAsync?.isLoading ?? false));
    final hasError = resultsAsync?.hasError ?? false;

    // Record to recent once a search resolves (port of the web `commitRecent`).
    if (results != null &&
        committed.isNotEmpty &&
        committed != _recordedQuery) {
      _recordedQuery = committed;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(chatSearchRecentProvider.notifier).add(committed);
      });
    }

    final body = SafeArea(
      top: isNarrow,
      bottom: isNarrow,
      left: false,
      right: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(
            theme,
            isNarrow: isNarrow,
            hasQuery: committed.isNotEmpty || _pendingQuery.isNotEmpty,
            isSearching: isSearching,
            hasError: hasError,
            results: results,
          ),
          Expanded(
            child: _body(
              theme,
              isNarrow: isNarrow,
              committed: committed,
              recent: recent,
              resultsAsync: resultsAsync,
              isSearching: isSearching,
            ),
          ),
        ],
      ),
    );

    // Mirror `showModelSelectorDialog`'s responsive presentation: a full-bleed
    // surface on phones (< 600px), a centred card otherwise.
    if (isNarrow) {
      return Material(color: theme.colorScheme.surface, child: body);
    }
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 760,
          maxHeight: size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Material(
            color: theme.colorScheme.surface,
            elevation: 8,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: body,
          ),
        ),
      ),
    );
  }

  // ---- Header ---------------------------------------------------------------

  Widget _header(
    ThemeData theme, {
    required bool isNarrow,
    required bool hasQuery,
    required bool isSearching,
    required bool hasError,
    required ChatSearchResultSet? results,
  }) {
    return Container(
      padding: EdgeInsets.all(isNarrow ? 16 : 24),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '搜索话题和消息',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                iconSize: 20,
                color: theme.colorScheme.onSurfaceVariant,
                icon: const Icon(LucideIcons.x),
                tooltip: '关闭搜索',
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            focusNode: _fieldFocus,
            style: const TextStyle(fontSize: 15),
            textInputAction: TextInputAction.search,
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              isDense: true,
              hintText: _searchHint,
              prefixIcon: Icon(
                LucideIcons.search,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              suffixIcon: _pendingQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => _setQueryImmediately(''),
                      iconSize: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                      icon: const Icon(LucideIcons.x),
                      tooltip: '清除搜索',
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SegmentedButton<ChatSearchMode>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 13),
                ),
                segments: const <ButtonSegment<ChatSearchMode>>[
                  ButtonSegment<ChatSearchMode>(
                    value: ChatSearchMode.and,
                    label: Text('全部匹配'),
                  ),
                  ButtonSegment<ChatSearchMode>(
                    value: ChatSearchMode.or,
                    label: Text('任意匹配'),
                  ),
                ],
                selected: <ChatSearchMode>{_mode},
                onSelectionChanged: (selection) {
                  setState(() => _mode = selection.first);
                },
              ),
              const Spacer(),
              if (hasQuery)
                _statLabel(
                  theme,
                  isSearching: isSearching,
                  hasError: hasError,
                  results: results,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statLabel(
    ThemeData theme, {
    required bool isSearching,
    required bool hasError,
    required ChatSearchResultSet? results,
  }) {
    if (isSearching) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            '搜索中…',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }
    if (hasError) {
      return Text(
        '搜索出错,请重试',
        style: TextStyle(fontSize: 13, color: theme.colorScheme.error),
      );
    }
    if (results == null) return const SizedBox.shrink();
    final shown = results.hits.length;
    final suffix = results.truncated ? ',显示前 $shown 个' : '';
    return Flexible(
      child: Text(
        '找到 ${results.total} 个结果 (${results.tookMs}ms)$suffix',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  // ---- Body -----------------------------------------------------------------

  Widget _body(
    ThemeData theme, {
    required bool isNarrow,
    required String committed,
    required List<String> recent,
    required AsyncValue<ChatSearchResultSet>? resultsAsync,
    required bool isSearching,
  }) {
    final padding = EdgeInsets.all(isNarrow ? 16 : 24);

    if (committed.isEmpty) {
      if (recent.isEmpty) {
        return _hint(theme, '输入关键词开始搜索');
      }
      return SingleChildScrollView(
        padding: padding,
        child: _recentSection(theme, recent),
      );
    }

    if (resultsAsync == null || isSearching && resultsAsync.asData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          _emptyState(theme, title: '搜索出错,请重试', subtitle: '换个关键词再试试'),
      data: (results) {
        if (results.hits.isEmpty) {
          return _emptyState(
            theme,
            title: '没有找到匹配的结果',
            subtitle: '换个关键词,或切换为「任意匹配」试试',
          );
        }
        return _resultList(theme, padding, results.hits);
      },
    );
  }

  Widget _hint(ThemeData theme, String text) {
    return Center(
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _emptyState(
    ThemeData theme, {
    required String title,
    required String subtitle,
  }) {
    final muted = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.search,
            size: 44,
            color: muted.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 16, color: muted)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 13, color: muted)),
        ],
      ),
    );
  }

  Widget _recentSection(ThemeData theme, List<String> recent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '最近搜索',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            InkWell(
              onTap: () => ref.read(chatSearchRecentProvider.notifier).clear(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  '清空',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final query in recent)
              InputChip(
                avatar: Icon(
                  LucideIcons.clock,
                  size: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                label: Text(query),
                onPressed: () {
                  _setQueryImmediately(query);
                  _fieldFocus.requestFocus();
                },
                onDeleted: () =>
                    ref.read(chatSearchRecentProvider.notifier).remove(query),
              ),
          ],
        ),
      ],
    );
  }

  Widget _resultList(
    ThemeData theme,
    EdgeInsets padding,
    List<ChatSearchHit> hits,
  ) {
    final children = <Widget>[];
    String? currentDate;
    for (var i = 0; i < hits.length; i++) {
      final hit = hits[i];
      final date = _formatDate(hit.createdAt);
      if (date != currentDate) {
        currentDate = date;
        children.add(
          Padding(
            padding: EdgeInsets.only(top: children.isEmpty ? 0 : 16, bottom: 4),
            child: Text(
              date,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
        children.add(Divider(height: 1, color: theme.dividerColor));
        children.add(const SizedBox(height: 8));
      }
      final key = GlobalKey();
      _itemKeys[i] = key;
      children.add(
        Padding(
          key: key,
          padding: const EdgeInsets.only(bottom: 8),
          child: _ResultItem(
            hit: hit,
            active: i == _safeActiveIndex,
            onSelect: () => _select(hit),
          ),
        ),
      );
    }
    return ListView(
      controller: _scrollController,
      padding: padding,
      children: children,
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }
}

/// A single search result row (port of the web `SearchResultItem`): icon +
/// topic name + type chip, a two-line highlighted snippet, and the timestamp.
class _ResultItem extends StatelessWidget {
  const _ResultItem({
    required this.hit,
    required this.active,
    required this.onSelect,
  });

  final ChatSearchHit hit;
  final bool active;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTopic = hit.kind == ChatSearchHitKind.topic;

    return Material(
      color: active
          ? theme.colorScheme.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? theme.colorScheme.primary : theme.dividerColor,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isTopic ? LucideIcons.hash : LucideIcons.messageSquare,
                    size: 15,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      hit.topicName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _TypeChip(label: isTopic ? '话题' : _roleLabel(hit.role)),
                ],
              ),
              const SizedBox(height: 6),
              _HighlightedText(
                text: hit.snippet,
                ranges: hit.matchRanges,
                baseStyle: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    LucideIcons.clock,
                    size: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(hit.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _roleLabel(MessageRole? role) {
    switch (role) {
      case MessageRole.assistant:
        return '助手';
      case MessageRole.system:
        return '系统';
      case MessageRole.user:
      case null:
        return '用户';
    }
  }

  static String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}/${two(local.month)}/${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

/// A small outlined chip labelling the hit kind / message role.
class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Renders [text] with [ranges] highlighted (port of the web `HighlightedText`)
/// — split into spans rather than injecting HTML, so it stays safe.
class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.ranges,
    required this.baseStyle,
  });

  final String text;
  final List<MatchRange> ranges;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlightStyle = baseStyle.copyWith(
      backgroundColor: theme.colorScheme.tertiaryContainer,
      color: theme.colorScheme.onTertiaryContainer,
      fontWeight: FontWeight.w600,
    );

    final length = text.length;
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final range in ranges) {
      final start = range.start.clamp(0, length);
      final end = range.end.clamp(start, length);
      if (start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, start)));
      }
      if (end > start) {
        spans.add(
          TextSpan(text: text.substring(start, end), style: highlightStyle),
        );
      }
      cursor = end;
    }
    if (cursor < length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
