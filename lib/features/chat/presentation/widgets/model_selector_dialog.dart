import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:aetherlink_flutter/shared/utils/provider_icons.dart';

/// Pixel-level 1:1 port of the SolidJS `DialogModelSelector`
/// (`src/solid/components/ModelSelector/DialogModelSelector.solid.tsx` +
/// `.solid.css`). Colours, spacing, font sizes, radii and behaviours mirror the
/// original's design tokens (`src/shared/design-tokens`, default theme) and CSS.
///
/// By default selecting a model sets the app-level current chat model. Callers
/// that pick a model for a different purpose (e.g. the 翻译 page's model button)
/// pass [onSelect] to receive the chosen `(provider, model)` instead, with
/// [selectedProviderId] / [selectedModelId] highlighting the current choice.
Future<void> showModelSelectorDialog(
  BuildContext context, {
  void Function(ModelProvider provider, Model model)? onSelect,
  String? selectedProviderId,
  String? selectedModelId,
}) {
  return showGeneralDialog<void>(
    context: context,
    // CSS: .solid-dialog-backdrop background-color: rgba(0, 0, 0, 0.5)
    barrierColor: const Color(0x80000000),
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    pageBuilder: (context, _, _) => _ModelSelectorView(
      onSelect: onSelect,
      selectedProviderId: selectedProviderId,
      selectedModelId: selectedModelId,
    ),
    transitionBuilder: (context, animation, _, child) => child,
    transitionDuration: Duration.zero,
  );
}

/// Default-theme design tokens (`src/shared/design-tokens/index.ts`) resolved
/// per brightness — the exact values the original injects into the CSS
/// variables the selector reads.
class _Tokens {
  _Tokens(this.brightness);

  final Brightness brightness;
  bool get _dark => brightness == Brightness.dark;

  // --theme-bg-paper
  Color get bgPaper => _dark ? const Color(0xFF2A2A2A) : const Color(0xFFFFFFFF);
  // --theme-bg-elevated
  Color get bgElevated =>
      _dark ? const Color(0xFF333333) : const Color(0xFFFAFAFA);
  // --theme-text-primary
  Color get textPrimary =>
      _dark ? const Color(0xFFF0F0F0) : const Color(0xFF1E293B);
  // --theme-text-secondary
  Color get textSecondary =>
      _dark ? const Color(0xFFB0B0B0) : const Color(0xFF64748B);
  // --theme-border-default
  Color get border =>
      _dark ? const Color(0x1FFFFFFF) : const Color(0x1F000000);
  // --theme-primary (mode-independent: tokens.primary.value)
  Color get primary => const Color(0xFF64748B);
  // --theme-hover-bg : rgba(100,116,139, 0.08 light / 0.16 dark)
  Color get hover =>
      _dark ? const Color(0x2964748B) : const Color(0x1464748B);
  // --theme-active-bg : rgba(100,116,139, 0.12 light / 0.24 dark)
  Color get active =>
      _dark ? const Color(0x3D64748B) : const Color(0x1F64748B);
  // --theme-selected-bg : rgba(100,116,139, 0.16 light / 0.32 dark)
  Color get selected =>
      _dark ? const Color(0x5264748B) : const Color(0x2964748B);

  // Inline badge colour from the title's <span style="color:#90caf9">.
  static const Color badge = Color(0xFF90CAF9);
}

/// A flattened (provider, model) pair — the original works with a flat
/// `availableModels: Model[]` whose `provider` field carries the vendor id.
class _Entry {
  const _Entry(this.provider, this.model);
  final ModelProvider provider;
  final Model model;
}

/// Lets the tab strip be dragged horizontally with a mouse (the original's
/// grab/grab-drag handlers) in addition to touch.
class _DragScrollBehavior extends MaterialScrollBehavior {
  const _DragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

class _ModelSelectorView extends ConsumerStatefulWidget {
  const _ModelSelectorView({
    this.onSelect,
    this.selectedProviderId,
    this.selectedModelId,
  });

  final void Function(ModelProvider provider, Model model)? onSelect;
  final String? selectedProviderId;
  final String? selectedModelId;

  @override
  ConsumerState<_ModelSelectorView> createState() => _ModelSelectorViewState();
}

class _ModelSelectorViewState extends ConsumerState<_ModelSelectorView> {
  final ScrollController _tabsController = ScrollController();
  final ScrollController _listController = ScrollController();

  // null until the first build resolves the open-time default (the original's
  // createEffect that switches 'all' -> 'frequently-used' when a model is set).
  String? _activeTab;
  bool _didInitTab = false;
  String? _scrolledFor;
  bool _showLeftArrow = false;
  bool _showRightArrow = false;

  @override
  void initState() {
    super.initState();
    _tabsController.addListener(_updateScrollButtons);
  }

  @override
  void dispose() {
    _tabsController
      ..removeListener(_updateScrollButtons)
      ..dispose();
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _Tokens(Theme.of(context).brightness);
    final mq = MediaQuery.of(context);
    // useMediaQuery(theme.breakpoints.down('sm')) -> width < 600px.
    final fullScreen = mq.size.width < 600;

    final providersAsync = ref.watch(appModelProvidersProvider);
    final currentAsync = ref.watch(appCurrentModelProvider);
    final providers = providersAsync.value ?? const [];
    final current = currentAsync.value;

    // availableModels: every model, in provider-defined order, tagged with its
    // vendor. (Parent passes enabled models flattened; mirror that here.)
    final available = <_Entry>[
      for (final p in providers)
        for (final m in p.models) _Entry(p, m),
    ];

    // groupedModels(): models grouped by vendor + the ordered vendor list of
    // those that actually have models.
    final groups = <String, List<_Entry>>{};
    final orderedProviders = <ModelProvider>[];
    for (final e in available) {
      final id = e.provider.id;
      if (!groups.containsKey(id)) {
        groups[id] = [];
        orderedProviders.add(e.provider);
      }
      groups[id]!.add(e);
    }

    // When [onSelect] is set the dialog highlights the caller's pre-selected
    // model instead of the app current chat model.
    final useExternalSelection = widget.onSelect != null;
    final currentProviderId = useExternalSelection
        ? widget.selectedProviderId
        : current?.provider.id;
    final selectedKey = useExternalSelection
        ? (widget.selectedProviderId != null && widget.selectedModelId != null
              ? _identity(widget.selectedProviderId!, widget.selectedModelId!)
              : null)
        : (current == null
              ? null
              : _identity(current.provider.id, current.model.id));

    // Open-time default: 'frequently-used' when a current model exists. Defer
    // until both providers and current model have resolved, otherwise the first
    // (still-loading) frame locks the tab to 'all'.
    if (!_didInitTab && !providersAsync.isLoading && !currentAsync.isLoading) {
      _didInitTab = true;
      _activeTab = (currentProviderId != null && groups.containsKey(currentProviderId))
          ? 'frequently-used'
          : 'all';
    }
    final activeTab = _activeTab ?? 'all';

    final displayed = _displayed(available, groups, currentProviderId, activeTab);

    _scheduleArrowUpdate();
    _scrollSelectedIntoView(displayed, selectedKey, activeTab);

    final body = _DialogBody(
      tokens: t,
      fullScreen: fullScreen,
      mediaQuery: mq,
      header: _header(t),
      tabs: _tabs(t, fullScreen, groups, orderedProviders, currentProviderId, activeTab),
      content: _content(t, fullScreen, mq, displayed, selectedKey),
    );

    if (fullScreen) {
      return Material(color: t.bgPaper, child: body);
    }
    // Card mode (>= 600px): centred, 8px radius, max 600px wide / 80vh tall,
    // MUI dialog elevation shadow.
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: mq.size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: t.bgPaper,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  offset: Offset(0, 11),
                  blurRadius: 15,
                  spreadRadius: -7,
                ),
                BoxShadow(
                  color: Color(0x24000000),
                  offset: Offset(0, 24),
                  blurRadius: 38,
                  spreadRadius: 3,
                ),
                BoxShadow(
                  color: Color(0x1F000000),
                  offset: Offset(0, 9),
                  blurRadius: 46,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Material(color: Colors.transparent, child: body),
            ),
          ),
        ),
      ),
    );
  }

  // ---- Header ----------------------------------------------------------------

  Widget _header(_Tokens t) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    '选择模型',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20, // 1.25rem
                      fontWeight: FontWeight.w500,
                      height: 1.6,
                      color: t.textPrimary,
                    ),
                  ),
                ),
                // <span style="margin-left:8px;font-size:12px;color:#90caf9">
                //   ⚡ SolidJS
                // </span>
                const SizedBox(width: 8),
                const Text(
                  '⚡ SolidJS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: _Tokens.badge,
                  ),
                ),
              ],
            ),
          ),
          // .solid-dialog-close-btn : 8px padding, 50% radius, text-secondary.
          _CloseButton(tokens: t, onTap: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }

  // ---- Tabs ------------------------------------------------------------------

  Widget _tabs(
    _Tokens t,
    bool compact,
    Map<String, List<_Entry>> groups,
    List<ModelProvider> orderedProviders,
    String? currentProviderId,
    String activeTab,
  ) {
    final hasCurrent =
        currentProviderId != null && groups.containsKey(currentProviderId);
    final currentProvider = hasCurrent
        ? orderedProviders.firstWhere((p) => p.id == currentProviderId)
        : null;

    final tabs = <Widget>[
      _tab(t, label: '全部', id: 'all', activeTab: activeTab, compact: compact),
      if (currentProvider != null)
        _tab(
          t,
          label: currentProvider.name,
          id: 'frequently-used',
          activeTab: activeTab,
          compact: compact,
        ),
      for (final p in orderedProviders)
        if (p.id != currentProviderId)
          _tab(t, label: p.name, id: p.id, activeTab: activeTab, compact: compact),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Stack(
        children: [
          Listener(
            onPointerSignal: (event) {
              // Wheel: vertical delta -> horizontal scroll (the original maps
              // deltaY to scrollLeft).
              if (event is PointerScrollEvent && _tabsController.hasClients) {
                final pos = _tabsController.position;
                final target = (_tabsController.offset + event.scrollDelta.dy)
                    .clamp(pos.minScrollExtent, pos.maxScrollExtent);
                _tabsController.jumpTo(target);
              }
            },
            child: ScrollConfiguration(
              behavior: const _DragScrollBehavior(),
              child: SingleChildScrollView(
                controller: _tabsController,
                scrollDirection: Axis.horizontal,
                child: IntrinsicHeight(child: Row(children: tabs)),
              ),
            ),
          ),
          if (_showLeftArrow)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: _ScrollArrow(
                tokens: t,
                isLeft: true,
                onTap: () => _scrollTabs(-200),
              ),
            ),
          if (_showRightArrow)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: _ScrollArrow(
                tokens: t,
                isLeft: false,
                onTap: () => _scrollTabs(200),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tab(
    _Tokens t, {
    required String label,
    required String id,
    required String activeTab,
    required bool compact,
  }) {
    final active = activeTab == id;
    return _TabButton(
      tokens: t,
      compact: compact,
      // text-transform: uppercase
      label: label.toUpperCase(),
      active: active,
      onTap: () {
        if (_activeTab == id) return;
        setState(() {
          _activeTab = id;
          _scrolledFor = null;
        });
      },
    );
  }

  // ---- Content ---------------------------------------------------------------

  Widget _content(
    _Tokens t,
    bool fullScreen,
    MediaQueryData mq,
    List<_Entry> displayed,
    String? selectedKey,
  ) {
    // .solid-dialog-content padding: 8px 12px 12px (mobile media query);
    // fullscreen overrides bottom to max(16, safeBottom + 16).
    final bottom = fullScreen
        ? (mq.padding.bottom + 16).clamp(16.0, double.infinity)
        : 16.0;
    final horizontal = fullScreen ? 12.0 : 16.0;
    final topBottomDefault = fullScreen ? 12.0 : 16.0;

    return ListView.separated(
      controller: _listController,
      padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, fullScreen ? bottom : topBottomDefault),
      itemCount: displayed.length,
      // .solid-model-list gap: 4px
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, i) {
        final e = displayed[i];
        final isSelected =
            selectedKey == _identity(e.provider.id, e.model.id);
        return _ModelItem(
          tokens: t,
          provider: e.provider,
          model: e.model,
          isSelected: isSelected,
          onTap: () => _select(e.provider, e.model),
        );
      },
    );
  }

  // ---- Logic -----------------------------------------------------------------

  List<_Entry> _displayed(
    List<_Entry> available,
    Map<String, List<_Entry>> groups,
    String? currentProviderId,
    String tab,
  ) {
    if (tab == 'all') return available;
    if (tab == 'frequently-used' && currentProviderId != null) {
      return groups[currentProviderId] ?? const [];
    }
    return groups[tab] ?? const [];
  }

  Future<void> _select(ModelProvider provider, Model model) async {
    final onSelect = widget.onSelect;
    if (onSelect != null) {
      onSelect(provider, model);
    } else {
      await ref
          .read(modelStoreProvider.notifier)
          .selectCurrentModel(providerId: provider.id, modelId: model.id);
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _scrollTabs(double delta) {
    if (!_tabsController.hasClients) return;
    final pos = _tabsController.position;
    final target = (_tabsController.offset + delta)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent)
        .toDouble();
    _tabsController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _updateScrollButtons() {
    if (!_tabsController.hasClients) return;
    final pos = _tabsController.position;
    final showLeft = pos.pixels > pos.minScrollExtent + 1;
    final showRight = pos.pixels < pos.maxScrollExtent - 1;
    if (showLeft == _showLeftArrow && showRight == _showRightArrow) return;
    setState(() {
      _showLeftArrow = showLeft;
      _showRightArrow = showRight;
    });
  }

  void _scheduleArrowUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateScrollButtons();
    });
  }

  void _scrollSelectedIntoView(
    List<_Entry> displayed,
    String? selectedKey,
    String activeTab,
  ) {
    if (selectedKey == null) return;
    final key = '$activeTab::$selectedKey';
    if (_scrolledFor == key) return;
    final index = displayed.indexWhere(
      (e) => selectedKey == _identity(e.provider.id, e.model.id),
    );
    if (index < 0) return;
    _scrolledFor = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_listController.hasClients) return;
      final pos = _listController.position;
      // Approximate scrollIntoView({block:'center'}): centre the row.
      final target = (index * 58.0 - pos.viewportDimension / 2 + 29)
          .clamp(pos.minScrollExtent, pos.maxScrollExtent)
          .toDouble();
      _listController.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    });
  }

  // JSON.stringify({id, provider}) equivalent — used only for equality.
  static String _identity(String providerId, String modelId) =>
      '$modelId\u0000$providerId';
}

/// Lays out header / tabs / scrollable content as a flex column, sizing to
/// content (card) or filling the screen (fullscreen) like the CSS flex column.
class _DialogBody extends StatelessWidget {
  const _DialogBody({
    required this.tokens,
    required this.fullScreen,
    required this.mediaQuery,
    required this.header,
    required this.tabs,
    required this.content,
  });

  final _Tokens tokens;
  final bool fullScreen;
  final MediaQueryData mediaQuery;
  final Widget header;
  final Widget tabs;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    // Header padding: base 16x24; mobile media query 12x16; fullscreen top is
    // max(16, safe-area-top). Left/right get safe-area insets in fullscreen.
    final hPad = fullScreen ? 16.0 : 24.0;
    final vPad = fullScreen ? 12.0 : 16.0;
    final topPad = fullScreen
        ? (mediaQuery.padding.top > 16 ? mediaQuery.padding.top : 16.0)
        : vPad;
    final safeLeft = fullScreen ? mediaQuery.padding.left : 0.0;
    final safeRight = fullScreen ? mediaQuery.padding.right : 0.0;

    final column = Column(
      mainAxisSize: fullScreen ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, topPad, hPad, vPad),
          child: header,
        ),
        tabs,
        if (fullScreen) Expanded(child: content) else Flexible(child: content),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(left: safeLeft, right: safeRight),
      child: column,
    );
  }
}

class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.tokens, required this.onTap});
  final _Tokens tokens;
  final VoidCallback onTap;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hover ? widget.tokens.hover : Colors.transparent,
          ),
          // X icon: svg 24x24, stroke-width 2.
          child: Icon(Icons.close, size: 24, color: widget.tokens.textSecondary),
        ),
      ),
    );
  }
}

class _TabButton extends StatefulWidget {
  const _TabButton({
    required this.tokens,
    required this.compact,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final _Tokens tokens;
  final bool compact;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final color = widget.active ? t.primary : t.textSecondary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          // .solid-tab padding: 12px 16px (base); 10px 12px (<=600px). The
          // border-bottom 2px is part of the box, so bottom padding loses 2px.
          padding: widget.compact
              ? const EdgeInsets.fromLTRB(12, 10, 12, 8)
              : const EdgeInsets.fromLTRB(16, 12, 16, 10),
          decoration: BoxDecoration(
            color: _hover && !widget.active ? t.hover : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                width: 2,
                color: widget.active ? t.primary : Colors.transparent,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              // 0.875rem (14px) base; 0.8125rem (13px) at <=600px.
              fontSize: widget.compact ? 13 : 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrollArrow extends StatelessWidget {
  const _ScrollArrow({
    required this.tokens,
    required this.isLeft,
    required this.onTap,
  });

  final _Tokens tokens;
  final bool isLeft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tokens.bgPaper,
      // box-shadow: 0 2px 8px rgba(0,0,0,0.15)
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.bgPaper,
          border: Border(
            left: isLeft
                ? BorderSide.none
                : BorderSide(color: tokens.border),
            right: isLeft
                ? BorderSide(color: tokens.border)
                : BorderSide.none,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              offset: Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            // .solid-tab-scroll-button padding: 8px 4px
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Icon(
              isLeft ? Icons.chevron_left : Icons.chevron_right,
              size: 24,
              color: tokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ModelItem extends StatefulWidget {
  const _ModelItem({
    required this.tokens,
    required this.provider,
    required this.model,
    required this.isSelected,
    required this.onTap,
  });

  final _Tokens tokens;
  final ModelProvider provider;
  final Model model;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_ModelItem> createState() => _ModelItemState();
}

class _ModelItemState extends State<_ModelItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final selected = widget.isSelected;

    // .solid-model-item background: transparent; selected -> selected-bg;
    // hover -> hover-bg; selected:hover -> active-bg.
    Color bg;
    if (selected) {
      bg = _hover ? t.active : t.selected;
    } else {
      bg = _hover ? t.hover : Colors.transparent;
    }

    final providerName = widget.provider.name;
    final description = (widget.model.description?.trim().isNotEmpty ?? false)
        ? widget.model.description!.trim()
        : '$providerName模型';

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          // .solid-model-item padding: 8px 12px; border-radius: 4px.
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              _ProviderIcon(
                tokens: t,
                provider: widget.provider,
                model: widget.model,
              ),
              // .solid-model-icon margin-right: 12px
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.model.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16, // 1rem
                        // selected -> font-weight 500, else 400
                        fontWeight:
                            selected ? FontWeight.w500 : FontWeight.w400,
                        color: t.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    // .solid-model-name margin-bottom: 2px
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 12, // 0.75rem
                        color: t.textSecondary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Padding(
                  // .solid-model-check margin-left: 8px; color: primary.
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.check, size: 20, color: t.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderIcon extends StatelessWidget {
  const _ProviderIcon({
    required this.tokens,
    required this.provider,
    required this.model,
  });

  final _Tokens tokens;
  final ModelProvider provider;
  final Model model;

  @override
  Widget build(BuildContext context) {
    final isDark = tokens.brightness == Brightness.dark;
    final providerId =
        model.provider.isNotEmpty ? model.provider : provider.id;
    final asset = getModelOrProviderIcon(model.id, providerId, isDark: isDark);

    // .solid-model-icon : 28x28; img object-fit contain, 4px radius, soft shadow.
    return SizedBox(
      width: 28,
      height: 28,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              offset: Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.asset(
            asset,
            width: 28,
            height: 28,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _fallback(),
          ),
        ),
      ),
    );
  }

  // .solid-model-icon-fallback : provider name's first letter on bg-elevated.
  Widget _fallback() {
    final name = provider.name;
    final label = name.isNotEmpty ? name.characters.first : '?';
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.bgElevated,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: tokens.textSecondary,
        ),
      ),
    );
  }
}
