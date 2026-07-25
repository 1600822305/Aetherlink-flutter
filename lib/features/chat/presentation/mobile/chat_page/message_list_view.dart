import 'package:aetherlink_perf/aetherlink_perf.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent, ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollview_observer/scrollview_observer.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_nav_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/message_selection_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar/sidebar_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/sidebar_settings.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/chat_page/deferred_bubble.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/chat_page/message_list_states.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/chat_page/message_row_decorations.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/deferred_content.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/message_selection_area.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_navigation.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/multi_model/multi_model_message_group.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/plain_style_message.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/system_prompt_bubble.dart';
import 'package:aetherlink_flutter/shared/widgets/auto_scroll_controller.dart';
import 'package:aetherlink_flutter/shared/widgets/no_implicit_scroll_physics.dart';

/// The scrollable message region. Reflects the real read provider: loading →
/// spinner, failure → error notice, empty → empty state, and a list of message
/// bubbles otherwise.
class ChatMessageList extends ConsumerWidget {
  const ChatMessageList({
    super.key,
    this.showSystemPromptBubble = false,
    this.bottomReserve = 0,
    this.isSelecting = false,
  });

  /// Whether the system-prompt bubble shows at the top of the list (it scrolls
  /// with the messages, like the web original — never selectable).
  final bool showSystemPromptBubble;

  /// Extra bottom padding so the list's tail clears the composer floating over
  /// it (the composer's measured height; see `_ChatBodyState`).
  final double bottomReserve;

  final bool isSelecting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initial load / failure depend only on the async phase, never on content,
    // so the spinner/error states never rebuild while a reply streams in.
    final hasValue = ref.watch(
      chatControllerProvider.select((a) => a.hasValue),
    );
    if (!hasValue) {
      final error = ref.watch(chatControllerProvider.select((a) => a.error));
      return error != null
          ? ChatErrorNotice(error: error)
          : const Center(child: CircularProgressIndicator());
    }

    // Subscribe to message *order* only (ids joined into one key string) so this
    // list rebuilds when a message is added/removed/reordered — but NOT when an
    // existing message's content streams in. Each bubble watches its own view by
    // id, so a streaming token rebuilds only the affected bubble, not the list.
    final orderKey = ref.watch(chatControllerProvider.select(_messageOrderKey));
    if (orderKey.isEmpty) {
      return ChatEmptyState(
        showSystemPromptBubble: showSystemPromptBubble && !isSelecting,
      );
    }
    final rows = <List<String>>[
      for (final row in orderKey.split('\u0000')) row.split(','),
    ];
    return ChatMessageListView(
      rows,
      showSystemPromptBubble: showSystemPromptBubble && !isSelecting,
      bottomReserve: bottomReserve,
      isSelecting: isSelecting,
    );
  }
}

/// Encodes the conversation's render *rows* into a single string so Riverpod's
/// `select` dedup short-circuits in-place content updates (streaming) — the key
/// changes only when the set/order/grouping of messages changes.
///
/// Rows are separated by `\u0000`; a row's member ids by `,`. Consecutive
/// assistant siblings sharing one `siblingsGroupId (>0)` and `askId` collapse
/// into a single multi-member row (the 对比 group); every other message is its
/// own single-member row.
String _messageOrderKey(AsyncValue<ChatState> async) {
  final messages = async.value?.messages;
  if (messages == null || messages.isEmpty) return '';
  final rows = <String>[];
  var i = 0;
  while (i < messages.length) {
    final m = messages[i];
    if (m.role == MessageRole.assistant &&
        m.siblingsGroupId > 0 &&
        m.askId != null) {
      final members = <String>[];
      while (i < messages.length) {
        final n = messages[i];
        if (n.role == MessageRole.assistant &&
            n.siblingsGroupId == m.siblingsGroupId &&
            n.askId == m.askId) {
          members.add(n.id);
          i++;
        } else {
          break;
        }
      }
      rows.add(members.join(','));
    } else {
      rows.add(m.id);
      i++;
    }
  }
  return rows.join('\u0000');
}

/// One bubble per message (M4.2.1). Each [ChatMessageBubble] reads its own
/// `main_text` blocks through the real provider and aligns by role. With a
/// fresh database this list is empty, so the empty state shows instead.
///
/// 自动下滑 (设置 tab 常规设置 → [SidebarSettings.autoScrollToBottom]) lives in
/// [AutoScrollController] (the port of the web `ChatScrollController`); this
/// widget only owns the [AutoFollowScrollController] and tells the state
/// machine which message change is an explicit pin:
/// * initial entry / switching topics (first-message id changes) / the user
///   sending (message count grows) → [AutoScrollController.pinToBottom].
/// In-place growth such as streaming needs nothing here — the custom
/// [AutoFollowScrollController] follows it during layout when sticking.
class ChatMessageListView extends ConsumerStatefulWidget {
  const ChatMessageListView(
    this.rows, {
    super.key,
    this.showSystemPromptBubble = false,
    this.bottomReserve = 0,
    this.isSelecting = false,
  });

  /// Render rows of the current conversation: a single-element row is one
  /// message, a multi-element row is a multi-model 对比 group. Each bubble watches
  /// its own [ChatMessageView] by id, so streaming content rebuilds only that
  /// bubble — never this whole list.
  final List<List<String>> rows;

  /// Renders the system-prompt bubble as the first (scrolling) list item, like
  /// the web original, instead of pinning it above the list.
  final bool showSystemPromptBubble;

  /// Reserves room under the last bubble for the composer floating over the
  /// list (mirrors the original `messageContainer` `paddingBottom`).
  final double bottomReserve;

  final bool isSelecting;

  @override
  ConsumerState<ChatMessageListView> createState() =>
      _ChatMessageListViewState();
}

class _ChatMessageListViewState extends ConsumerState<ChatMessageListView> {
  /// Rows rendered when entering a topic (kelivo's initial history window).
  /// Entering pins to the bottom, which lays the list out from the top — so
  /// the very first frame pays for every row it can reach. Windowing caps
  /// that first-frame build to the most recent rows; older history is
  /// revealed page-by-page as the user scrolls near the top.
  static const int _kInitialWindowRows = 30;

  /// Rows in the very first frame of a topic entry/switch — roughly one
  /// screenful. The rest of the initial window is ramped in over the next
  /// frames ([_rampStep]), so even a heavy conversation never pays for 30
  /// rows on the single frame that runs the page transition (WeChat-style
  /// instant entry; older rows stream in with no artificial delay).
  static const int _kFirstFrameRows = 8;

  /// Rows added per frame while ramping up to [_kInitialWindowRows].
  static const int _kRampRowsPerFrame = 8;

  /// Rows revealed per load when scrolling near the hidden history.
  static const int _kRevealPageRows = 30;

  /// Distance (px) from the top that triggers revealing another page.
  static const double _kRevealThreshold = 200;

  final AutoFollowScrollController _scrollController =
      AutoFollowScrollController();
  late final ListObserverController _observerController;
  late final AutoScrollController _autoScroll;

  /// Identifies the loaded conversation so a topic switch (first-message change)
  /// can be told apart from appends / in-place content growth. Tracked over the
  /// flattened message ids so multi-model groups don't confuse the heuristic.
  String? _firstId;
  int _count = 0;

  /// Chained anchor for 上一条/下一条 (kelivo's `_lastJumpUserMessageId`
  /// pattern): the row index the last jump landed on. Consecutive taps step
  /// from here directly — no per-tap viewport observation (cheaper, no jank
  /// from a forced observe pass) and immune to the landing position being
  /// clamped near the list's ends. Cleared as soon as the user scrolls.
  int? _navAnchorIndex;

  /// QQ's `getExtraLayoutSpace` pattern: the enlarged cache extent is only
  /// engaged while a navigation jump is in flight (so the glide path is
  /// pre-built), and released back to the framework default afterwards —
  /// off-viewport layout work and memory stay small during normal use.
  bool _navCacheBoost = false;

  /// Leading rows of the conversation currently *not* rendered (the hidden
  /// history window). Always indexes into [widget.rows] space.
  int _hiddenRowCount = 0;
  bool _revealScheduled = false;
  DateTime? _lastRevealAt;

  /// Frame-by-frame expansion of the entry window (see [_kFirstFrameRows]).
  bool _ramping = false;
  int _rampTargetHidden = 0;

  int get _effectiveHiddenRows =>
      widget.isSelecting ? 0 : _hiddenRowCount.clamp(0, widget.rows.length);

  /// The system-prompt bubble is only the first item once the full history is
  /// revealed — it belongs at the very top of the conversation.
  int get _headerCount =>
      widget.showSystemPromptBubble && _effectiveHiddenRows == 0 ? 1 : 0;

  /// A slim spinner row sits above the window while history is still hidden
  /// (loaded on scroll), WeChat-style. Mutually exclusive with [_headerCount]
  /// (the prompt bubble only shows once everything is revealed).
  int get _loaderCount => _effectiveHiddenRows > 0 ? 1 : 0;

  /// Every message id in display order (groups flattened) — for the autoscroll
  /// heuristic and mini-map scroll-to-message lookups.
  List<String> get _flatIds => [for (final row in widget.rows) ...row];

  @override
  void initState() {
    super.initState();
    _observerController = ListObserverController(controller: _scrollController)
      ..cacheJumpIndexOffset = false;
    _autoScroll = AutoScrollController(
      scrollController: _scrollController,
      isEnabled: () =>
          ref.read(sidebarSettingsControllerProvider).autoScrollToBottom,
    );
    final ids = _flatIds;
    _firstId = ids.isEmpty ? null : ids.first;
    _count = ids.length;
    _beginWindowRamp();
    _scrollController.addListener(_onUserScrollResetNavAnchor);
    registerChatNavigationHandler(_handleNavigation);
    // Initial entry pins to the bottom (latest message), like the web's mount.
    _autoScroll.pinToBottom();
  }

  @override
  void didUpdateWidget(covariant ChatMessageListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keyboard show/hide (or the composer growing) changes the bottom reserve;
    // pan the content by the same delta so what was visible above the composer
    // stays visible — WeChat-style whole-content shift.
    final reserveDelta = widget.bottomReserve - oldWidget.bottomReserve;
    if (reserveDelta.abs() > 0.5) {
      _scrollController.pendingAdjust += reserveDelta;
    }
    final ids = _flatIds;
    final firstId = ids.isEmpty ? null : ids.first;
    final count = ids.length;
    final topicSwitched = firstId != _firstId;
    final appended = !topicSwitched && count > _count;
    _firstId = firstId;
    _count = count;

    if (topicSwitched) {
      _beginWindowRamp();
    } else {
      _hiddenRowCount = _hiddenRowCount.clamp(0, widget.rows.length);
      _rampTargetHidden = _rampTargetHidden.clamp(0, widget.rows.length);
    }

    if (topicSwitched || appended) {
      _navAnchorIndex = null;
      _autoScroll.pinToBottom();
    }
  }

  /// Sets the entry window to [_kFirstFrameRows] and schedules the frame-by-
  /// frame ramp up to [_kInitialWindowRows] — pure post-frame callbacks, no
  /// timers, so short topics still mount whole in one frame.
  void _beginWindowRamp() {
    final total = widget.rows.length;
    _rampTargetHidden = (total - _kInitialWindowRows).clamp(0, total);
    _hiddenRowCount = (total - _kFirstFrameRows).clamp(0, total);
    if (_hiddenRowCount <= _rampTargetHidden) {
      _hiddenRowCount = _rampTargetHidden;
      _ramping = false;
      return;
    }
    if (!_ramping) {
      _ramping = true;
      WidgetsBinding.instance.addPostFrameCallback(_rampStep);
    }
  }

  /// One ramp increment per frame. Rows are prepended with stable keys
  /// (`findChildIndexCallback`), so the sliver keeps the existing elements and
  /// issues its own scroll-offset correction for the extent inserted above —
  /// the viewport stays still without any manual compensation.
  void _rampStep(Duration _) {
    if (!mounted || !_ramping) return;
    if (_hiddenRowCount <= _rampTargetHidden) {
      _ramping = false;
      return;
    }
    setState(() {
      _hiddenRowCount = (_hiddenRowCount - _kRampRowsPerFrame).clamp(
        _rampTargetHidden,
        widget.rows.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _ramping = false;
        return;
      }
      _rampStep(Duration.zero);
    });
  }

  /// Reveals another page of hidden history when the user scrolls near the
  /// top. The per-row keys + `findChildIndexCallback` let the sliver keep the
  /// existing elements and self-correct the scroll offset by the *actual*
  /// extent laid out above, so no manual estimate-based compensation is
  /// needed (an extra `extentAnchor` shift here would double-correct and
  /// throw the viewport toward the bottom on fast flings).
  void _maybeRevealMore(ScrollMetrics metrics) {
    if (_revealScheduled || _ramping || _effectiveHiddenRows == 0) return;
    if (metrics.pixels > _kRevealThreshold) return;
    final last = _lastRevealAt;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(milliseconds: 120)) {
      return;
    }
    _revealScheduled = true;
    _lastRevealAt = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _revealScheduled = false;
        return;
      }
      setState(() {
        _hiddenRowCount = (_hiddenRowCount - _kRevealPageRows).clamp(
          0,
          widget.rows.length,
        );
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _revealScheduled = false;
        // At the very top no further scroll notifications arrive (pixels
        // can't go below zero), so continue revealing from here until the
        // viewport is off the threshold or history is exhausted. Delayed past
        // the throttle window so each page still lands on its own frame.
        Future<void>.delayed(const Duration(milliseconds: 120), () {
          if (!mounted || !_scrollController.hasClients) return;
          if (_scrollController.positions.length != 1) return;
          _maybeRevealMore(_scrollController.position);
        });
      });
    });
  }

  /// Reveals hidden history down to (at most) [targetRow]; the sliver's own
  /// offset correction keeps the viewport on the same content.
  Future<void> _revealDownTo(int targetRow) async {
    if (targetRow >= _effectiveHiddenRows) return;
    _ramping = false;
    setState(() {
      _hiddenRowCount = targetRow.clamp(0, widget.rows.length);
    });
    await WidgetsBinding.instance.endOfFrame;
  }

  /// A user scroll invalidates the chained jump anchor — the next 上一条/
  /// 下一条 re-observes the viewport instead (kelivo resets its anchor the
  /// same way).
  void _onUserScrollResetNavAnchor() {
    if (_navAnchorIndex == null || !_scrollController.hasClients) return;
    if (_scrollController.position.userScrollDirection !=
        ScrollDirection.idle) {
      _navAnchorIndex = null;
    }
  }

  @override
  void dispose() {
    unregisterChatNavigationHandler(_handleNavigation);
    _scrollController.removeListener(_onUserScrollResetNavAnchor);
    _autoScroll.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Executes a 对话导航 action (invoked directly by [ChatNavigationOverlay]
  /// through the handler registry). 上一条/下一条 step from the chained
  /// [_navAnchorIndex] when present, otherwise from the first row currently
  /// visible (observed via [ListObserverController]), falling back to
  /// 回顶/回底 at the ends — mirroring the web `ChatNavigation`.
  Future<void> _handleNavigation(ChatNavigationAction action) async {
    if (!_navCacheBoost && mounted) {
      setState(() => _navCacheBoost = true);
      // Let the boosted cache build before measuring/jumping.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    try {
      await _runNavigation(action);
    } finally {
      if (mounted && _navCacheBoost) {
        setState(() => _navCacheBoost = false);
      }
    }
  }

  /// 距离自适应滑行时长（千问 FlyOutSmoothScroller 的思路）：时长随剩余距离
  /// 占视口的比例缩放并 clamp 在 80–350ms —— 目标就在附近时近似瞬时到位，
  /// 长滑保持现有速度感。
  static Duration _glideDuration(double distancePx, double viewportPx) {
    if (viewportPx <= 0) return const Duration(milliseconds: 300);
    final ms = (distancePx.abs() / viewportPx * 350).clamp(80.0, 350.0);
    return Duration(milliseconds: ms.round());
  }

  Future<void> _runNavigation(ChatNavigationAction action) async {
    switch (action) {
      case ChatNavigationAction.top:
        _navAnchorIndex = null;
        _autoScroll.unstick();
        if (!_scrollController.hasClients) return;
        // Long-distance smooth scrolls would lazily build every message on
        // the way (the web keeps the whole DOM alive, Flutter doesn't), which
        // is what dropped frames. Teleport close to the target first, then
        // finish with a short glide. The glide distance must stay *within*
        // the scrollCacheExtent (1 viewport): everything the glide passes is
        // then already built by the teleport frame, so the animation itself
        // runs completely build-free.
        final topPosition = _scrollController.position;
        final topFar = topPosition.viewportDimension * 0.8;
        if (_effectiveHiddenRows > 0) {
          // Reveal the whole history and land near the top *in the same
          // frame*: the relayout then only builds the top screen, never the
          // hidden rows in between.
          _ramping = false;
          setState(() => _hiddenRowCount = 0);
          _scrollController.jumpTo(topFar);
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted || !_scrollController.hasClients) return;
        } else if (topPosition.pixels > topFar) {
          _scrollController.jumpTo(topFar);
          // Let the teleport frame's build storm (target screen + cache)
          // finish before starting the glide, so the animation's first
          // frames aren't the ones paying for it.
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted || !_scrollController.hasClients) return;
        }
        await _scrollController.animateTo(
          0,
          duration: _glideDuration(
            _scrollController.position.pixels,
            _scrollController.position.viewportDimension,
          ),
          curve: Curves.easeOutCubic,
        );
      case ChatNavigationAction.bottom:
        _navAnchorIndex = null;
        if (_scrollController.hasClients) {
          // Same near-jump + cache-covered short glide as 回顶.
          final position = _scrollController.position;
          final far = position.viewportDimension * 0.8;
          if (position.maxScrollExtent - position.pixels > far) {
            _scrollController.jumpTo(position.maxScrollExtent - far);
            await WidgetsBinding.instance.endOfFrame;
            if (!mounted) return;
          }
          if (!_scrollController.hasClients) return;
          await _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: _glideDuration(
              _scrollController.position.maxScrollExtent -
                  _scrollController.position.pixels,
              _scrollController.position.viewportDimension,
            ),
            curve: Curves.easeOutCubic,
          );
        }
        // Re-stick and settle any residual gap (estimated extents can shift
        // while the destination screen builds).
        _autoScroll.pinToBottom();
      case ChatNavigationAction.prevMessage:
      case ChatNavigationAction.nextMessage:
        // The anchor lives in full-row space ([widget.rows] index) so it
        // survives history reveals shifting the list indices.
        var anchorRow = _navAnchorIndex;
        if (anchorRow == null) {
          // isForce: without it the observer skips re-dispatch when the scroll
          // offset hasn't changed since the last observation (e.g. resting at
          // the bottom after the entry pin), returning a null result.
          final result = await _observerController.dispatchOnceObserve(
            isForce: true,
            isDependObserveCallback: false,
          );
          final first = result.observeResult?.firstChild?.index;
          if (first == null || !mounted) return;
          anchorRow =
              first - _headerCount - _loaderCount + _effectiveHiddenRows;
        }
        final delta = action == ChatNavigationAction.prevMessage ? -1 : 1;
        final targetRow = anchorRow + delta;
        if (targetRow < 0) {
          return _handleNavigation(ChatNavigationAction.top);
        }
        if (targetRow >= widget.rows.length) {
          return _handleNavigation(ChatNavigationAction.bottom);
        }
        if (targetRow < _effectiveHiddenRows) {
          // Stepping into hidden history: reveal a page above it first.
          await _revealDownTo(
            (targetRow - _kRevealPageRows + 1).clamp(0, targetRow),
          );
          if (!mounted) return;
        }
        _navAnchorIndex = targetRow;
        _autoScroll.unstick();
        // Smooth scroll like the web's `scrollIntoView({behavior: 'smooth'})`.
        // The enlarged scrollCacheExtent keeps the neighbouring bubbles built
        // ahead of time, so the animation runs without mid-flight builds.
        // 上/下一条只跨一行，短时长快速到位（FlyOutSmoothScroller 的
        // 短距离快档），消除拖拽感。
        await _observerController.animateTo(
          index: targetRow - _effectiveHiddenRows + _headerCount + _loaderCount,
          alignment: 0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
        if (mounted && targetRow < widget.rows.length) {
          ref
              .read(navHighlightMessageIdProvider.notifier)
              .flash(widget.rows[targetRow].first);
        }
    }
  }

  /// Handles a mini-map scroll-to-message request, revealing hidden history
  /// first when the target is above the current window.
  Future<void> _scrollToMessageFromMiniMap(String messageId) async {
    final rowIndex = widget.rows.indexWhere((row) => row.contains(messageId));
    if (rowIndex < 0) return;
    if (rowIndex < _effectiveHiddenRows) {
      await _revealDownTo(rowIndex);
      if (!mounted) return;
    }
    _navAnchorIndex = rowIndex;
    _autoScroll.unstick();
    ref.read(navHighlightMessageIdProvider.notifier).flash(messageId);
    var listIndex =
        rowIndex - _effectiveHiddenRows + _headerCount + _loaderCount;
    if (widget.isSelecting) {
      // Multi-select expands 对比 groups into one list item per message.
      var expanded = 0;
      for (var i = 0; i < rowIndex; i++) {
        expanded += widget.rows[i].length;
      }
      listIndex = expanded + widget.rows[rowIndex].indexOf(messageId);
    }
    await _observerController.animateTo(
      index: listIndex,
      alignment: 0.1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSelecting = widget.isSelecting;
    // Multi-select shows every message individually so each can be ticked; the
    // 对比 grouping only applies to the normal (read) view.
    final hiddenRows = _effectiveHiddenRows;
    final allRows = isSelecting
        ? <List<String>>[
            for (final row in widget.rows)
              for (final id in row) <String>[id],
          ]
        : widget.rows;
    // Kelivo-style history window: only the most recent rows are rendered on
    // entry; older history is revealed page-by-page near the top.
    final rows = hiddenRows > 0 ? allRows.sublist(hiddenRows) : allRows;
    final headerCount = _headerCount;
    final loaderCount = _loaderCount;
    // Stable row-key → index map for `findChildIndexCallback`: when a history
    // reveal prepends rows, the sliver re-maps the existing elements to their
    // shifted indices instead of rebuilding every visible row as a different
    // message (which flashed skeletons and lost the scroll anchor).
    final rowIndexByKey = <String, int>{
      for (var i = 0; i < rows.length; i++) rows[i].first: i,
    };
    final selectedIds = isSelecting
        ? ref.watch(messageSelectionProvider.select((s) => s.selectedIds))
        : const <String>{};

    // Listen for scroll-to-message requests from the mini map.
    ref.listen<String?>(scrollToMessageIdProvider, (prev, messageId) {
      if (messageId == null) return;
      ref.read(scrollToMessageIdProvider.notifier).clear();
      _scrollToMessageFromMiniMap(messageId);
    });

    // 消息分割线 (设置 tab 常规设置)：开启时在相邻消息之间画一条分割线。
    final showDivider = ref.watch(
      sidebarSettingsControllerProvider.select((s) => s.showMessageDivider),
    );
    final isPlain = ref.watch(
      sidebarSettingsControllerProvider.select(
        (s) => s.messageStyle == MessageStyle.plain,
      ),
    );
    // Report the visible message count and live scroll state to the performance
    // monitor, so scroll jank can be attributed to "/chat scrolling". Both are
    // no-ops while the monitor is stopped.
    PerfMonitor.instance.setMessages(allRows.length);
    // 消息可选中复制: a tap anywhere in the list clears a lingering text
    // selection held by a message's [MessageSelectionArea] (each message wraps
    // its own small SelectionArea, so a tap on another bubble / blank space
    // never reaches the area holding the selection).
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) =>
          MessageSelectionArea.clearOutside(event.position),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollStartNotification) {
            PerfMonitor.instance.setScrolling(true);
            DeferredContentScheduler.instance.setScrolling(true);
          } else if (n is ScrollEndNotification) {
            PerfMonitor.instance.setScrolling(false);
            DeferredContentScheduler.instance.setScrolling(false);
          } else if (n is ScrollUpdateNotification && n.depth == 0) {
            _maybeRevealMore(n.metrics);
          }
          return false;
        },
        child: ListViewObserver(
          controller: _observerController,
          child: ListView.builder(
            controller: _scrollController,
            // 千问式拦截：禁用焦点 / showOnScreen 驱动的隐式滚动，气泡内
            // 文本选择、可聚焦控件获焦都不再拉动列表。
            physics: const NoImplicitScrollPhysics(),
            // QQ getExtraLayoutSpace pattern: enlarged only while a navigation
            // jump is in flight (so the glide path is pre-built); the framework
            // default otherwise, keeping off-viewport layout and memory small.
            scrollCacheExtent: _navCacheBoost
                ? const ScrollCacheExtent.viewport(1)
                : null,
            padding: EdgeInsets.fromLTRB(0, 8, 0, 8 + widget.bottomReserve),
            itemCount: rows.length + headerCount + loaderCount,
            findChildIndexCallback: (key) {
              if (key is! ValueKey<String>) return null;
              final rowIndex = rowIndexByKey[key.value];
              if (rowIndex == null) return null;
              return rowIndex + headerCount + loaderCount;
            },
            itemBuilder: (context, index) {
              // A slim spinner tops the list while older history is hidden — it
              // loads in as the user scrolls up (WeChat-style), never eagerly.
              if (loaderCount == 1 && index == 0) {
                return const _HistoryLoadingRow();
              }
              // The system-prompt bubble is the first item when enabled; it scrolls
              // with the list and is never part of multi-select.
              if (headerCount == 1 && index == 0) {
                return const SystemPromptBubble();
              }
              final rowIndex = index - headerCount - loaderCount;
              final row = rows[rowIndex];
              // A multi-member row is a multi-model 对比 group; a single-member row is
              // an ordinary message.
              Widget item;
              if (row.length > 1) {
                item = MultiModelMessageGroup(
                  key: ValueKey('group:${row.join(',')}'),
                  memberIds: row,
                );
              } else {
                final id = row.first;
                // Stable per-message key so Flutter's element diff reuses the
                // existing bubble across appends/reorders.
                final Widget bubble = isPlain
                    ? PlainStyleMessage(key: ValueKey(id), messageId: id)
                    : ChatMessageBubble(key: ValueKey(id), messageId: id);
                // Wrap with selection checkbox when in multi-select mode.
                item = isSelecting
                    ? SelectableMessageRow(
                        messageId: id,
                        selected: selectedIds.contains(id),
                        child: bubble,
                      )
                    : bubble;
              }

              // Heavy terminal bubbles first mount as a skeleton and materialize
              // over the following frames — the frame that runs the page
              // transition never pays for a giant bubble's build.
              if (!isSelecting) {
                item = DeferredBubble(rowIds: row, child: item);
              }

              // Navigation landing flash (web scrollToMessage's 1.6s highlight).
              item = NavFlashHighlight(messageId: row.first, child: item);

              // Plain style uses its own bottom border; bubble style uses a Divider
              // when the setting is on.
              final needsDivider =
                  isPlain || (showDivider && rowIndex < rows.length - 1);
              // The stable per-row key on the sliver's direct child is what
              // `findChildIndexCallback` resolves, keeping elements (and their
              // keep-alive / deferred state) across history reveals.
              final rowKey = ValueKey<String>(row.first);
              if (!needsDivider) return KeepAliveItem(key: rowKey, child: item);
              final dividerColor =
                  Theme.of(context).brightness == Brightness.dark
                  ? const Color(0x1AFFFFFF)
                  : const Color(0x14000000);
              return KeepAliveItem(
                key: rowKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    item,
                    Divider(height: 1, thickness: 1, color: dividerColor),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The slim spinner row shown above the rendered window while older history
/// is still hidden (revealed page-by-page as the user scrolls up).
class _HistoryLoadingRow extends StatelessWidget {
  const _HistoryLoadingRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
