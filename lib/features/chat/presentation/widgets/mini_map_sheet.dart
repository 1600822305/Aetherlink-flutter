import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/message_selection_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';

/// Shows the mini-map bottom sheet and returns the tapped message ID (or null).
Future<String?> showMiniMapSheet(
  BuildContext context,
  List<ChatMessageView> messages, {
  bool selecting = false,
  WidgetRef? ref,
}) async {
  return await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) =>
        _MiniMapSheet(messages: messages, selecting: selecting, ref: ref),
  );
}

class _MiniMapSheet extends StatefulWidget {
  const _MiniMapSheet({
    required this.messages,
    this.selecting = false,
    this.ref,
  });

  final List<ChatMessageView> messages;
  final bool selecting;
  final WidgetRef? ref;

  @override
  State<_MiniMapSheet> createState() => _MiniMapSheetState();
}

class _MiniMapSheetState extends State<_MiniMapSheet> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late List<_QaPair> _pairs;
  String _query = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _pairs = _buildPairs(widget.messages);
  }

  @override
  void didUpdateWidget(covariant _MiniMapSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.messages, widget.messages)) {
      _pairs = _buildPairs(widget.messages);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() => _isSearching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _clearOrCloseSearch({bool close = false}) {
    setState(() {
      _query = '';
      _searchController.clear();
      if (close) _isSearching = false;
    });
    if (close) {
      _searchFocusNode.unfocus();
    } else {
      _searchFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final searchWidth = min(MediaQuery.sizeOf(context).width * 0.6, 260.0);

    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (ctx, controller) {
          final pairs = _filteredPairs(_pairs);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Title row
                Row(
                  children: [
                    Icon(LucideIcons.map, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '迷你地图',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      height: 36,
                      width: 36,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          LucideIcons.chevronsDown,
                          size: 18,
                          color: cs.onSurface,
                        ),
                        tooltip: '滚动到底部',
                        onPressed: () {
                          if (controller.hasClients &&
                              controller.position.maxScrollExtent > 0) {
                            controller.jumpTo(
                              controller.position.maxScrollExtent,
                            );
                          }
                        },
                      ),
                    ),
                    _buildSearchToggle(context, searchWidth),
                  ],
                ),
                const SizedBox(height: 12),
                // Scrollable content
                Expanded(
                  child: pairs.isEmpty
                      ? Center(
                          child: Text(
                            _query.isNotEmpty ? '无匹配消息' : '暂无消息',
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        )
                      : Scrollbar(
                          controller: controller,
                          thumbVisibility: true,
                          child: ListView.builder(
                            controller: controller,
                            itemCount: pairs.length,
                            itemBuilder: (context, index) {
                              return _MiniMapRow(
                                pair: pairs[index],
                                selecting: widget.selecting,
                                ref: widget.ref,
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchToggle(BuildContext context, double maxWidth) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = cs.outlineVariant.withValues(alpha: isDark ? 0.5 : 0.8);

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (child, animation) {
          return SizeTransition(
            sizeFactor: animation,
            axis: Axis.horizontal,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: _isSearching
            ? ConstrainedBox(
                key: const ValueKey('miniMapSearchField'),
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: (value) => setState(() => _query = value),
                          textInputAction: TextInputAction.search,
                          textAlignVertical: TextAlignVertical.center,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: '搜索消息',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            filled: true,
                            fillColor: cs.surfaceContainerHighest.withValues(
                              alpha: isDark ? 0.35 : 0.6,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: cs.primary),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 36,
                      width: 36,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          LucideIcons.x,
                          size: 18,
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                        onPressed: () => _clearOrCloseSearch(close: true),
                        tooltip: '关闭搜索',
                      ),
                    ),
                  ],
                ),
              )
            : SizedBox(
                key: const ValueKey('miniMapSearchButton'),
                height: 36,
                width: 36,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(LucideIcons.search, size: 20, color: cs.onSurface),
                  onPressed: _startSearch,
                  tooltip: '搜索',
                ),
              ),
      ),
    );
  }

  List<_QaPair> _buildPairs(List<ChatMessageView> items) {
    final pairs = <_QaPair>[];
    ChatMessageView? pendingUser;
    for (final m in items) {
      if (m.role == MessageRole.user) {
        if (pendingUser != null) {
          pairs.add(_QaPair(user: pendingUser, assistant: null));
        }
        pendingUser = m;
      } else if (m.role == MessageRole.assistant) {
        if (pendingUser != null) {
          pairs.add(_QaPair(user: pendingUser, assistant: m));
          pendingUser = null;
        } else {
          pairs.add(_QaPair(user: null, assistant: m));
        }
      }
    }
    if (pendingUser != null) {
      pairs.add(_QaPair(user: pendingUser, assistant: null));
    }
    return pairs;
  }

  List<_QaPair> _filteredPairs(List<_QaPair> base) {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return base;
    return base.where((pair) {
      final user = pair.user?.text.toLowerCase() ?? '';
      final asst = pair.assistant?.text.toLowerCase() ?? '';
      return user.contains(needle) || asst.contains(needle);
    }).toList();
  }
}

class _QaPair {
  _QaPair({required this.user, required this.assistant});
  final ChatMessageView? user;
  final ChatMessageView? assistant;
}

class _MiniMapRow extends StatelessWidget {
  const _MiniMapRow({required this.pair, this.selecting = false, this.ref});

  final _QaPair pair;
  final bool selecting;
  final WidgetRef? ref;

  String _oneLine(String s) {
    return s
        .replaceAll(
          RegExp(
            r'<(?:think|thought)>[\s\S]*?</(?:think|thought)>',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\[image:[^\]]+\]'), '')
        .replaceAll(RegExp(r'\[file:[^\]]+\]'), '')
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userText = pair.user?.text ?? '';
    final asstText = pair.assistant?.text ?? '';

    Set<String>? selectedIds;
    if (selecting && ref != null) {
      selectedIds = ref!.watch(
        messageSelectionProvider.select((s) => s.selectedIds),
      );
    }

    final bool userSelected =
        selectedIds != null &&
        pair.user != null &&
        selectedIds.contains(pair.user!.id);
    final bool assistantSelected =
        selectedIds != null &&
        pair.assistant != null &&
        selectedIds.contains(pair.assistant!.id);

    final userBg = isDark
        ? cs.primary.withValues(alpha: 0.15)
        : cs.primary.withValues(alpha: 0.08);
    final userSelectedBg = isDark
        ? cs.primary.withValues(alpha: 0.26)
        : cs.primary.withValues(alpha: 0.14);
    final userBorder = cs.primary.withValues(alpha: isDark ? 0.45 : 0.35);

    final assistantBg = cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.04);
    final assistantSelectedBg = isDark
        ? cs.primary.withValues(alpha: 0.18)
        : cs.primary.withValues(alpha: 0.10);
    final assistantBorder = cs.primary.withValues(alpha: isDark ? 0.38 : 0.28);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // User bubble (right aligned)
          if (pair.user != null)
            Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.75 - 32,
                ),
                child: _buildBubble(
                  context: context,
                  text: userText.isNotEmpty ? _oneLine(userText) : ' ',
                  bg: userSelected ? userSelectedBg : userBg,
                  border: userSelected ? userBorder : null,
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.4,
                    color: cs.onSurface,
                  ),
                  onTap: selecting && ref != null
                      ? () => ref!
                            .read(messageSelectionProvider.notifier)
                            .toggleMessage(pair.user!.id)
                      : () => Navigator.of(context).pop(pair.user!.id),
                ),
              ),
            ),
          if (pair.user != null) const SizedBox(height: 6),
          // Assistant bubble (left aligned)
          if (pair.assistant != null)
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width - 32,
                ),
                child: _buildBubble(
                  context: context,
                  text: asstText.isNotEmpty ? _oneLine(asstText) : ' ',
                  bg: assistantSelected ? assistantSelectedBg : assistantBg,
                  border: assistantSelected ? assistantBorder : null,
                  style: const TextStyle(fontSize: 15.7, height: 1.5),
                  onTap: selecting && ref != null
                      ? () => ref!
                            .read(messageSelectionProvider.notifier)
                            .toggleMessage(pair.assistant!.id)
                      : () => Navigator.of(context).pop(pair.assistant!.id),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBubble({
    required BuildContext context,
    required String text,
    required Color bg,
    required TextStyle style,
    required VoidCallback onTap,
    Color? border,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: border != null ? Border.all(color: border, width: 1) : null,
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
            textAlign: TextAlign.left,
          ),
        ),
      ),
    );
  }
}
