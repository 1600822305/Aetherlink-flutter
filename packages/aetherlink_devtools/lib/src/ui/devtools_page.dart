import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../panel.dart';

/// The in-app developer tools page: an [AppBar] action row over a [TabBar] whose
/// tabs come from [DevToolsRegistry]. Each registered [DevToolsPanel] is one
/// tab — the host (later phases) only registers panels; this page never changes.
///
/// Styled to match the app's other full-screen pages (surface AppBar, bottom
/// divider, primary-tinted back button), mirroring `about_page.dart`.
class DevToolsPage extends StatefulWidget {
  const DevToolsPage({super.key});

  @override
  State<DevToolsPage> createState() => _DevToolsPageState();
}

class _DevToolsPageState extends State<DevToolsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final List<DevToolsPanel> _panels;

  @override
  void initState() {
    super.initState();
    _panels = DevToolsRegistry.panels;
    _tabs = TabController(length: _panels.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  DevToolsPanel? get _activePanel {
    if (_panels.isEmpty) return null;
    final i = _panels.length == 1 ? 0 : _tabs.index;
    return _panels[i];
  }

  Future<void> _copyActive() async {
    final text = _activePanel?.exportAsText() ?? '';
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前面板暂无可复制内容')));
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已复制')));
    }
  }

  void _clearActive() => _activePanel?.onClear();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 4,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        iconTheme: IconThemeData(color: theme.colorScheme.primary),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        // Tabs live inline in the top bar (no separate title text); a lone panel
        // falls back to its own name so the bar isn't empty.
        title: _panels.length > 1
            ? _SegmentedTabs(controller: _tabs, panels: _panels)
            : Text(_panels.isEmpty ? '开发者工具' : _panels.first.title),
        actions: [
          IconButton(
            tooltip: '复制',
            onPressed: _copyActive,
            icon: const Icon(Icons.copy_outlined, size: 20),
          ),
          IconButton(
            tooltip: '清空',
            onPressed: _clearActive,
            icon: const Icon(Icons.delete_outline, size: 20),
          ),
        ],
      ),
      // Respect the bottom (and side) insets so the last list row / action isn't
      // hidden behind the system navigation bar in the edge-to-edge app shell.
      body: SafeArea(
        top: false,
        child: _panels.isEmpty
            ? const Center(child: Text('未注册任何面板'))
            : (_panels.length == 1
                  ? _panels.first.build(context)
                  : TabBarView(
                      controller: _tabs,
                      children: [for (final p in _panels) p.build(context)],
                    )),
      ),
    );
  }
}

/// The app's unified segmented tab control (rounded container + pill indicator +
/// scrollable, content-sized tabs), replicated here because this package stays
/// dependency-free of the app's `lib/`. Used inline as the [AppBar] title so the
/// tabs sit in the top bar rather than a separate row below it.
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.controller, required this.panels});

  final TabController controller;
  final List<DevToolsPanel> panels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
        color: theme.colorScheme.surface,
      ),
      padding: const EdgeInsets.all(3),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerHeight: 0,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        tabs: [
          for (final p in panels)
            Tab(
              height: 34,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(p.icon, size: 15),
                  const SizedBox(width: 5),
                  Text(p.title),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
