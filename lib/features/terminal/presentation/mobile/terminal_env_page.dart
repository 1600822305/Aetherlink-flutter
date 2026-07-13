// 终端环境管理页：两个 tab ——
// · 镜像源：系统源（apk/apt）、pip、npm 三组，内置多镜像 + 自定义源，
//   选中即应用（系统源写 rootfs 配置文件，pip/npm 在终端里回放配置命令）。
// · 环境 / 包：预设包按分类勾选，静默检测已装状态，一键合成安装命令
//   回放进当前终端会话。
//
// 参考 Operit 的 SetupScreen/SourceManager 设计，适配本项目的
// Alpine/Ubuntu 双发行版与交互式终端回放模式。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/terminal/application/terminal_engine_manager.dart';
import 'package:aetherlink_flutter/features/terminal/application/terminal_mirror_store.dart';
import 'package:aetherlink_flutter/features/terminal/application/terminal_silent_exec.dart';
import 'package:aetherlink_flutter/features/terminal/domain/terminal_distro.dart';
import 'package:aetherlink_flutter/features/terminal/domain/terminal_env_presets.dart';
import 'package:aetherlink_flutter/features/terminal/domain/terminal_mirrors.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_session_pool.dart';
import 'package:aetherlink_flutter/features/workspace/data/proot_local_backend.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';
import 'package:aetherlink_flutter/shared/widgets/instant_switch_tab_view.dart';

/// 打开终端环境管理页。[onRunCommand] 把一条命令送进当前终端会话。
Future<void> showTerminalEnvPage(
  BuildContext context, {
  required void Function(String command) onRunCommand,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => TerminalEnvPage(onRunCommand: onRunCommand),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}

class TerminalEnvPage extends ConsumerStatefulWidget {
  const TerminalEnvPage({super.key, required this.onRunCommand});

  final void Function(String command) onRunCommand;

  @override
  ConsumerState<TerminalEnvPage> createState() => _TerminalEnvPageState();
}

class _TerminalEnvPageState extends ConsumerState<TerminalEnvPage>
    with SingleTickerProviderStateMixin {
  TerminalDistro _distro = TerminalDistro.alpine;

  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    TerminalEngineManager.instance.installedDistro().then((distro) {
      if (mounted && distro != null) setState(() => _distro = distro);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 回放命令进终端并退回终端页，让用户实时看到执行过程。
  void _runInTerminal(String command) {
    widget.onRunCommand(command);
    Navigator.of(context).pop();
  }

  /// 清理内置终端环境：二次确认后先关掉所有 PRoot 会话，再删除
  /// rootfs 目录（只动应用私有目录，/sdcard 是绑定挂载的手机存储，
  /// 不受影响）。清理后退回终端页，下次进入会重新引导安装。
  Future<void> _cleanEngine() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清理内置终端环境'),
        content: const Text(
          '将删除已安装的 Alpine/Ubuntu 环境（rootfs、已装的软件包、'
          '/root 主目录里的文件）并关闭所有内置终端会话，释放存储空间。\n\n'
          '/sdcard 是绑定挂载的手机存储，里面的文件不会被删除。\n'
          '清理后可随时重新下载安装。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('清理'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(workspaceSessionPoolManagerProvider)
          .closeBackends((b) => b is ProotLocalBackend);
      await TerminalEngineManager.instance.uninstall();
      if (!mounted) return;
      AppToast.success(context, '已清理内置终端环境');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, '清理失败：$e');
    }
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
            color: theme.colorScheme.primary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: const Text('终端环境管理'),
        actions: [
          IconButton(
            tooltip: '清理内置终端环境',
            icon: const Icon(LucideIcons.trash2, size: 20),
            color: theme.colorScheme.error,
            onPressed: _cleanEngine,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _TabBarHeader(controller: _tabController),
          Expanded(
            child: InstantSwitchTabView(
              controller: _tabController,
              children: [
                _MirrorTab(distro: _distro, runInTerminal: _runInTerminal),
                _PackagesTab(distro: _distro, runInTerminal: _runInTerminal),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 设置页同款分段 tab 条（外观设置页 `_TabBarHeader` 的圆角描边轨道 +
/// 主色淡底胶囊指示器）。
class _TabBarHeader extends StatelessWidget {
  const _TabBarHeader({required this.controller});

  final TabController controller;

  static const List<(IconData, String)> _tabs = [
    (LucideIcons.databaseZap, '镜像源'),
    (LucideIcons.package, '环境 / 包'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
          color: theme.colorScheme.surface,
        ),
        padding: const EdgeInsets.all(3),
        child: TabBar(
          controller: controller,
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
            for (final (icon, label) in _tabs)
              Tab(
                height: 34,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 15),
                    const SizedBox(width: 5),
                    Text(label),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 设置页同款卡片：圆角 16 + 描边 + 软阴影，内容裁切圆角。
class _EnvCard extends StatelessWidget {
  const _EnvCard({required this.child});

  final Widget child;

  static const double _radius = 16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: theme.dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: Material(
          type: MaterialType.transparency,
          child: child,
        ),
      ),
    );
  }
}

// ===== 镜像源 tab =====

class _MirrorTab extends StatefulWidget {
  const _MirrorTab({required this.distro, required this.runInTerminal});

  final TerminalDistro distro;
  final void Function(String command) runInTerminal;

  @override
  State<_MirrorTab> createState() => _MirrorTabState();
}

class _MirrorTabState extends State<_MirrorTab> {
  static const _store = TerminalMirrorStore();

  final Map<TerminalMirrorKind, String?> _selected = {};
  final Map<TerminalMirrorKind, List<TerminalMirror>> _custom = {};
  bool _loaded = false;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final kind in TerminalMirrorKind.values) {
      _selected[kind] = await _store.selectedId(kind);
      _custom[kind] = await _store.customMirrors(kind);
    }
    if (mounted) setState(() => _loaded = true);
  }

  List<TerminalMirror> _builtIn(TerminalMirrorKind kind) => switch (kind) {
        TerminalMirrorKind.system => kTerminalMirrors,
        TerminalMirrorKind.pip => kPipMirrors,
        TerminalMirrorKind.npm => kNpmMirrors,
      };

  Future<void> _apply(TerminalMirrorKind kind, TerminalMirror mirror) async {
    if (_applying) return;
    setState(() => _applying = true);
    try {
      await _store.setSelectedId(kind, mirror.id);
      switch (kind) {
        case TerminalMirrorKind.system:
          await TerminalEngineManager.instance.setPackageMirror(mirror);
          if (!mounted) return;
          widget.runInTerminal(refreshIndexCommandFor(widget.distro));
        case TerminalMirrorKind.pip:
          widget.runInTerminal(pipMirrorCommand(mirror));
        case TerminalMirrorKind.npm:
          widget.runInTerminal(npmMirrorCommand(mirror));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _applying = false);
      AppToast.error(context, '切换失败：$e');
    }
  }

  Future<void> _addCustom(TerminalMirrorKind kind) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _AddMirrorDialog(kind: kind, distro: widget.distro),
    );
    if (result == null) return;
    final (name, url) = result;
    await _store.addCustomMirror(kind, name: name, baseUrl: url);
    _custom[kind] = await _store.customMirrors(kind);
    if (mounted) setState(() {});
  }

  Future<void> _removeCustom(TerminalMirrorKind kind, String id) async {
    await _store.removeCustomMirror(kind, id);
    _custom[kind] = await _store.customMirrors(kind);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final systemTitle =
        widget.distro == TerminalDistro.ubuntu ? 'apt 软件源' : 'apk 软件源';
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        _section(
          kind: TerminalMirrorKind.system,
          title: systemTitle,
          subtitle: '系统包管理器的软件源，选中后立即写入 rootfs 并刷新索引。',
        ),
        const SizedBox(height: 12),
        _section(
          kind: TerminalMirrorKind.pip,
          title: 'pip 源',
          subtitle: '写入 ~/.config/pip/pip.conf，需已安装 Python/pip。',
        ),
        const SizedBox(height: 12),
        _section(
          kind: TerminalMirrorKind.npm,
          title: 'npm 源',
          subtitle: '通过 npm config set registry 配置，需已安装 Node/npm。',
        ),
      ],
    );
  }

  Widget _section({
    required TerminalMirrorKind kind,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final selectedId = _selected[kind] ?? 'official';
    final mirrors = [..._builtIn(kind), ...?_custom[kind]];
    return _EnvCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            RadioGroup<String>(
              groupValue: selectedId,
              onChanged: (id) {
                if (_applying || id == null) return;
                final mirror = mirrors.firstWhere((m) => m.id == id);
                _apply(kind, mirror);
              },
              child: Column(
                children: [
                  for (final mirror in mirrors)
                    RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: mirror.id,
                      enabled: !_applying,
                      title: Text(mirror.name),
                      subtitle: Text(
                        mirror.baseUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      secondary: mirror.id.startsWith('custom_')
                          ? IconButton(
                              tooltip: '删除',
                              icon: const Icon(LucideIcons.trash2, size: 18),
                              onPressed: () => _removeCustom(kind, mirror.id),
                            )
                          : null,
                    ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _addCustom(kind),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('添加自定义源'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMirrorDialog extends StatefulWidget {
  const _AddMirrorDialog({required this.kind, required this.distro});

  final TerminalMirrorKind kind;
  final TerminalDistro distro;

  @override
  State<_AddMirrorDialog> createState() => _AddMirrorDialogState();
}

class _AddMirrorDialogState extends State<_AddMirrorDialog> {
  final _name = TextEditingController();
  final _url = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  String get _hint => switch (widget.kind) {
        TerminalMirrorKind.system => widget.distro == TerminalDistro.ubuntu
            ? '仓库根 URL，如 https://mirrors.xxx.com/ubuntu-ports'
            : '仓库根 URL，如 https://mirrors.xxx.com/alpine',
        TerminalMirrorKind.pip => 'index-url，如 https://mirrors.xxx.com/pypi/simple',
        TerminalMirrorKind.npm => 'registry，如 https://mirrors.xxx.com/npm/',
      };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加自定义源'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '名称'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _url,
            decoration: InputDecoration(labelText: 'URL', hintText: _hint),
            keyboardType: TextInputType.url,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            final url = _url.text.trim();
            if (name.isEmpty || !url.startsWith('http')) {
              AppToast.error(context, '请填写名称和有效的 URL');
              return;
            }
            Navigator.of(context).pop((name, url));
          },
          child: const Text('添加'),
        ),
      ],
    );
  }
}

// ===== 环境 / 包 tab =====

enum _PkgStatus { checking, installed, notInstalled }

class _PackagesTab extends StatefulWidget {
  const _PackagesTab({required this.distro, required this.runInTerminal});

  final TerminalDistro distro;
  final void Function(String command) runInTerminal;

  @override
  State<_PackagesTab> createState() => _PackagesTabState();
}

class _PackagesTabState extends State<_PackagesTab> {
  List<TerminalEnvCategory> _categories = const [];
  final Map<String, _PkgStatus> _status = {};
  final Set<String> _selected = {};
  bool _checkFailed = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant _PackagesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.distro != widget.distro) _reload();
  }

  Future<void> _reload() async {
    final categories = envCategoriesFor(widget.distro);
    final packages = [for (final c in categories) ...c.packages];
    setState(() {
      _categories = categories;
      _checkFailed = false;
      _status
        ..clear()
        ..addEntries(packages.map((p) => MapEntry(p.id, _PkgStatus.checking)));
      _selected.clear();
    });
    try {
      final result = await const TerminalSilentExec()
          .run(batchCheckCommandFor(packages));
      if (!mounted) return;
      final installed = parseBatchCheckOutput(result.stdout);
      setState(() {
        for (final p in packages) {
          _status[p.id] = installed.contains(p.id)
              ? _PkgStatus.installed
              : _PkgStatus.notInstalled;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkFailed = true;
        for (final p in packages) {
          _status[p.id] = _PkgStatus.notInstalled;
        }
      });
    }
  }

  void _install() {
    final packages = [
      for (final c in _categories)
        for (final p in c.packages)
          if (_selected.contains(p.id)) p,
    ];
    if (packages.isEmpty) return;
    widget.runInTerminal(installCommandFor(widget.distro, packages));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        if (_checkFailed)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '已装状态检测失败（终端未安装或探测超时），可直接勾选安装。',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final category = _categories[i];
              return _EnvCard(
                child: ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: Text(category.name),
                  subtitle: Text(
                    category.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  children: [
                    for (final pkg in category.packages)
                      CheckboxListTile(
                        dense: true,
                        value: _status[pkg.id] == _PkgStatus.installed ||
                            _selected.contains(pkg.id),
                        onChanged: _status[pkg.id] == _PkgStatus.notInstalled
                            ? (checked) => setState(() {
                                  if (checked == true) {
                                    _selected.add(pkg.id);
                                  } else {
                                    _selected.remove(pkg.id);
                                  }
                                })
                            : null,
                        title: Text(pkg.name),
                        subtitle: Text(pkg.description),
                        secondary: _statusChip(_status[pkg.id]),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: FilledButton.icon(
              onPressed: _selected.isEmpty ? null : _install,
              icon: const Icon(LucideIcons.download, size: 18),
              label: Text(
                _selected.isEmpty ? '勾选要安装的包' : '安装所选（${_selected.length}）',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusChip(_PkgStatus? status) {
    final theme = Theme.of(context);
    return switch (status) {
      _PkgStatus.checking => const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      _PkgStatus.installed => Text(
          '已装',
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.primary),
        ),
      _ => Text(
          '未装',
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
    };
  }
}
