import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../console/console_store.dart';
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

  Future<void> _copyConsole() async {
    final lines = ConsoleStore.instance.filtered.map((e) => e.toLine());
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已复制控制台日志')));
    }
  }

  void _clearActive() {
    // P0 only hosts the Console; later panels clear their own store keyed off
    // the active tab index.
    ConsoleStore.instance.clear();
  }

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
        titleSpacing: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        iconTheme: IconThemeData(color: theme.colorScheme.primary),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: const Text('开发者工具'),
        actions: [
          IconButton(
            tooltip: '复制',
            onPressed: _copyConsole,
            icon: const Icon(Icons.copy_outlined, size: 20),
          ),
          IconButton(
            tooltip: '清空',
            onPressed: _clearActive,
            icon: const Icon(Icons.delete_outline, size: 20),
          ),
        ],
        bottom: _panels.length > 1
            ? TabBar(
                controller: _tabs,
                tabs: [
                  for (final p in _panels)
                    Tab(
                      height: 44,
                      icon: Icon(p.icon, size: 18),
                      iconMargin: EdgeInsets.zero,
                      child: Text(p.title),
                    ),
                ],
              )
            : null,
      ),
      body: _panels.isEmpty
          ? const Center(child: Text('未注册任何面板'))
          : (_panels.length == 1
                ? _panels.first.build(context)
                : TabBarView(
                    controller: _tabs,
                    children: [for (final p in _panels) p.build(context)],
                  )),
    );
  }
}
