import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/settings/application/model_combo_controller.dart';
import 'package:aetherlink_flutter/features/settings/application/model_combo_providers.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:aetherlink_flutter/shared/utils/provider_icons.dart';

part 'model_list_items.dart';
part 'selector_chrome.dart';

/// Pixel-level 1:1 port of the SolidJS `DialogModelSelector`
/// (`src/solid/components/ModelSelector/DialogModelSelector.solid.tsx` +
/// `.solid.css`). Colours, spacing, font sizes, radii and behaviours mirror the
/// original's design tokens (`src/shared/design-tokens`, default theme) and CSS.
///
/// By default selecting a model sets the app-level current chat model. Callers
/// that pick a model for a different purpose (e.g. the 翻译 page's model button)
/// pass [onSelect] to receive the chosen `(provider, model)` instead, with
/// [selectedProviderId] / [selectedModelId] highlighting the current choice.
///
/// [filter] restricts which models are listed (mirrors Cherry Studio's
/// `ModelSelector` `filter` prop): chat callers pass `(m) => !isNonChatModel(m)`
/// to hide embedding/rerank/生成类模型, the memory embedding picker passes
/// [isEmbeddingModel] to show only embedding models.
Future<void> showModelSelectorDialog(
  BuildContext context, {
  void Function(ModelProvider provider, Model model)? onSelect,
  String? selectedProviderId,
  String? selectedModelId,
  bool Function(Model model)? filter,
}) {
  // Drop the chat input's focus first so the modal route has no node to restore
  // on pop — otherwise closing this full-screen dialog re-focuses the input box
  // (and re-raises the keyboard) on the way back to the chat screen.
  FocusManager.instance.primaryFocus?.unfocus();
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
      filter: filter,
    ),
    transitionBuilder: (context, animation, _, child) => child,
    transitionDuration: Duration.zero,
  );
}

/// Structural design tokens resolved from the active [ThemeData] so the
/// selector follows the selected 主题风格 preset (its `ColorScheme`) rather than
/// fixed light/dark values. The neutral primary/hover/active/selected tints are
/// derived from `colorScheme.primary`; the inline title [badge] stays the
/// original's fixed accent.
class _Tokens {
  _Tokens(this.theme);

  final ThemeData theme;
  ColorScheme get _cs => theme.colorScheme;
  Brightness get brightness => theme.brightness;
  bool get _dark => brightness == Brightness.dark;

  // --theme-bg-paper
  Color get bgPaper => _cs.surface;
  // --theme-bg-elevated : a subtle tint over the surface.
  Color get bgElevated => Color.alphaBlend(
    _cs.onSurface.withValues(alpha: _dark ? 0.06 : 0.03),
    _cs.surface,
  );
  // --theme-text-primary
  Color get textPrimary => _cs.onSurface;
  // --theme-text-secondary
  Color get textSecondary => _cs.onSurfaceVariant;
  // --theme-border-default
  Color get border => _cs.onSurface.withValues(alpha: 0.12);
  // --theme-primary
  Color get primary => _cs.primary;
  // --theme-hover-bg : primary @ 0.08 light / 0.16 dark
  Color get hover => _cs.primary.withValues(alpha: _dark ? 0.16 : 0.08);
  // --theme-active-bg : primary @ 0.12 light / 0.24 dark
  Color get active => _cs.primary.withValues(alpha: _dark ? 0.24 : 0.12);
  // --theme-selected-bg : primary @ 0.16 light / 0.32 dark
  Color get selected => _cs.primary.withValues(alpha: _dark ? 0.32 : 0.16);

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
    this.filter,
  });

  final void Function(ModelProvider provider, Model model)? onSelect;
  final String? selectedProviderId;
  final String? selectedModelId;
  final bool Function(Model model)? filter;

  @override
  ConsumerState<_ModelSelectorView> createState() => _ModelSelectorViewState();
}

class _ModelSelectorViewState extends ConsumerState<_ModelSelectorView> {
  final ScrollController _tabsController = ScrollController();
  final ScrollController _listController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _searching = false;
  String _query = '';

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
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _Tokens(Theme.of(context));
    final mq = MediaQuery.of(context);
    // useMediaQuery(theme.breakpoints.down('sm')) -> width < 600px.
    final fullScreen = mq.size.width < 600;

    final providersAsync = ref.watch(allProvidersWithCombosProvider);
    final currentAsync = ref.watch(appCurrentModelProvider);
    final providers = providersAsync.value ?? const [];
    final current = currentAsync.value;

    // availableModels: every enabled provider's models, in provider-defined
    // order, tagged with their vendor — disabled providers are hidden, like
    // the web `ModelSelector`'s `provider.isEnabled` gate. When a [filter] is
    // supplied, models failing it are dropped — this is how the chat selector
    // hides embedding/rerank/生成类模型 (see Cherry Studio's `ModelSelector`
    // `filter` prop).
    final filter = widget.filter;
    final available = <_Entry>[
      for (final p in providers)
        if (p.isEnabled)
          for (final m in p.models)
            if (filter == null || filter(m)) _Entry(p, m),
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
    final comboState = ref.watch(modelComboControllerProvider);
    final activeComboId = comboState.selectedComboId;
    final String? currentProviderId;
    final String? selectedKey;
    if (useExternalSelection) {
      currentProviderId = widget.selectedProviderId;
      selectedKey =
          widget.selectedProviderId != null && widget.selectedModelId != null
          ? _identity(widget.selectedProviderId!, widget.selectedModelId!)
          : null;
    } else if (activeComboId != null) {
      currentProviderId = kModelComboProviderId;
      selectedKey = _identity(kModelComboProviderId, activeComboId);
    } else if (current != null) {
      currentProviderId = current.provider.id;
      selectedKey = _identity(current.provider.id, current.model.id);
    } else {
      currentProviderId = null;
      selectedKey = null;
    }

    // Open-time default: 'frequently-used' when a current model exists. Defer
    // until both providers and current model have resolved, otherwise the first
    // (still-loading) frame locks the tab to 'all'.
    if (!_didInitTab && !providersAsync.isLoading && !currentAsync.isLoading) {
      _didInitTab = true;
      _activeTab =
          (currentProviderId != null && groups.containsKey(currentProviderId))
          ? 'frequently-used'
          : 'all';
    }
    final activeTab = _activeTab ?? 'all';

    // Search results are grouped by provider: a header row per vendor followed
    // by its matching models, in the same provider order as the '全部' tab.
    final query = _query.trim().toLowerCase();
    final List<Object> rows;
    if (query.isNotEmpty) {
      final matches = [
        for (final e in available)
          if (e.model.name.toLowerCase().contains(query) ||
              e.model.id.toLowerCase().contains(query) ||
              e.provider.name.toLowerCase().contains(query))
            e,
      ];
      rows = <Object>[];
      String? lastProviderId;
      for (final e in matches) {
        if (e.provider.id != lastProviderId) {
          lastProviderId = e.provider.id;
          rows.add(e.provider);
        }
        rows.add(e);
      }
    } else {
      rows = _displayed(available, groups, currentProviderId, activeTab);
    }

    _scheduleArrowUpdate();
    if (query.isEmpty) {
      _scrollSelectedIntoView(rows.cast<_Entry>(), selectedKey, activeTab);
    }

    final body = _DialogBody(
      tokens: t,
      fullScreen: fullScreen,
      mediaQuery: mq,
      header: _header(t),
      tabs: query.isNotEmpty
          ? const SizedBox.shrink()
          : _tabs(
              t,
              fullScreen,
              groups,
              orderedProviders,
              currentProviderId,
              activeTab,
            ),
      content: _content(t, fullScreen, mq, rows, selectedKey),
    );

    // The raw showGeneralDialog route has no Scaffold/Dialog inset handling,
    // so pad the body above the software keyboard when the search field opens
    // it — otherwise the bottom of the model list hides behind the keyboard.
    final keyboardInset = EdgeInsets.only(bottom: mq.viewInsets.bottom);

    if (fullScreen) {
      return Material(
        color: t.bgPaper,
        child: Padding(padding: keyboardInset, child: body),
      );
    }
    // Card mode (>= 600px): centred, 8px radius, max 600px wide / 80vh tall,
    // MUI dialog elevation shadow.
    return Padding(
      padding: keyboardInset,
      child: Center(
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
          Expanded(child: _searching ? _searchField(t) : _title(t)),
          _HeaderIconButton(
            tokens: t,
            icon: _searching ? Icons.search_off : Icons.search,
            onTap: _toggleSearch,
          ),
          _HeaderIconButton(
            tokens: t,
            icon: Icons.close,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _searchField(_Tokens t) {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      autofocus: true,
      onChanged: (v) => setState(() => _query = v),
      style: TextStyle(fontSize: 16, color: t.textPrimary),
      cursorColor: t.primary,
      decoration: InputDecoration(
        isDense: true,
        hintText: '搜索模型',
        hintStyle: TextStyle(fontSize: 16, color: t.textSecondary),
        border: InputBorder.none,
        suffixIcon: _query.isEmpty
            ? null
            : GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
                child: Icon(Icons.clear, size: 18, color: t.textSecondary),
              ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 24,
          minHeight: 24,
        ),
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchController.clear();
        _query = '';
      }
    });
  }

  Widget _title(_Tokens t) {
    return Row(
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
          '⚡ Flutter',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: _Tokens.badge,
          ),
        ),
      ],
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
          _tab(
            t,
            label: p.name,
            id: p.id,
            activeTab: activeTab,
            compact: compact,
          ),
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
          // The arrows exist for mouse users; on the phone layout the strip
          // is swiped directly, so they only take up space over the tabs.
          if (!compact && _showLeftArrow)
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
          if (!compact && _showRightArrow)
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
    List<Object> displayed,
    String? selectedKey,
  ) {
    // .solid-dialog-content padding: 8px 12px 12px (mobile media query);
    // fullscreen overrides bottom to max(16, safeBottom + 16).
    final bottom = fullScreen
        ? (mq.padding.bottom + 16).clamp(16.0, double.infinity)
        : 16.0;
    final horizontal = fullScreen ? 12.0 : 16.0;
    final topBottomDefault = fullScreen ? 12.0 : 16.0;

    if (displayed.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '没有匹配的模型',
            style: TextStyle(fontSize: 14, color: t.textSecondary),
          ),
        ),
      );
    }

    return ListView.separated(
      controller: _listController,
      padding: EdgeInsets.fromLTRB(
        horizontal,
        8,
        horizontal,
        fullScreen ? bottom : topBottomDefault,
      ),
      itemCount: displayed.length,
      // .solid-model-list gap: 4px
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, i) {
        final row = displayed[i];
        if (row is ModelProvider) {
          return _GroupHeader(tokens: t, provider: row, isFirst: i == 0);
        }
        final e = row as _Entry;
        final isSelected = selectedKey == _identity(e.provider.id, e.model.id);
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
    } else if (provider.id == kModelComboProviderId) {
      // Combo models are virtual — store the selection in the combo controller
      // and clear the real model's isDefault so the UI picks it up.
      ref.read(modelComboControllerProvider.notifier).selectCombo(model.id);
    } else {
      // Normal model — clear any combo selection first.
      ref.read(modelComboControllerProvider.notifier).clearComboSelection();
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
