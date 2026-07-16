// 远程工作区（SSH / Termux）环境管理页：与内置终端的 TerminalEnvPage
// 同构的两个 tab（镜像源 / 环境·包），差别在于：
// · 环境画像与包已装状态经调用方注入的静默 exec 通道探测
//   （WorkspaceBackend.exec，不依赖 proot）；
// · 一切写操作（切源 / 装包）只生成命令回放进终端，让用户全程可见——
//   远程环境归用户所有，不做静默改写；
// · 镜像源选择按工作区 id 作用域持久化，与内置终端的全局选择互不干扰。

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/terminal/application/terminal_mirror_store.dart';
import 'package:aetherlink_flutter/features/terminal/domain/remote_env.dart';
import 'package:aetherlink_flutter/features/terminal/domain/terminal_env_presets.dart';
import 'package:aetherlink_flutter/features/terminal/domain/terminal_mirrors.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';
import 'package:aetherlink_flutter/shared/widgets/instant_switch_tab_view.dart';

/// 静默执行一条命令并拿到输出（调用方桥接 WorkspaceBackend.exec）。
typedef WorkspaceEnvExec = Future<({String stdout, int exitCode})> Function(
  String command,
);

/// 打开远程工作区环境管理页。[mirrorScope] 为镜像选择的持久化作用域
/// （传工作区 id）；[silentExec] 做只读探测；[onRunCommand] 把命令
/// 回放进当前终端会话。
Future<void> showWorkspaceEnvPage(
  BuildContext context, {
  required String workspaceName,
  required String mirrorScope,
  required WorkspaceEnvExec silentExec,
  required void Function(String command) onRunCommand,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => WorkspaceEnvPage(
        workspaceName: workspaceName,
        mirrorScope: mirrorScope,
        silentExec: silentExec,
        onRunCommand: onRunCommand,
      ),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}

class WorkspaceEnvPage extends StatefulWidget {
  const WorkspaceEnvPage({
    super.key,
    required this.workspaceName,
    required this.mirrorScope,
    required this.silentExec,
    required this.onRunCommand,
  });

  final String workspaceName;
  final String mirrorScope;
  final WorkspaceEnvExec silentExec;
  final void Function(String command) onRunCommand;

  @override
  State<WorkspaceEnvPage> createState() => _WorkspaceEnvPageState();
}

class _WorkspaceEnvPageState extends State<WorkspaceEnvPage>
    with SingleTickerProviderStateMixin {
  RemoteEnvInfo? _env;
  String? _probeError;

  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _probe();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _probe() async {
    setState(() {
      _env = null;
      _probeError = null;
    });
    try {
      final result = await widget.silentExec(kRemoteEnvProbeCommand);
      if (!mounted) return;
      setState(() => _env = parseRemoteEnvProbe(result.stdout));
    } catch (e) {
      if (!mounted) return;
      setState(() => _probeError = '$e');
    }
  }

  /// 回放命令进终端并退回终端页，让用户实时看到执行过程。
  void _runInTerminal(String command) {
    widget.onRunCommand(command);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final env = _env;
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('环境管理'),
            Text(
              env == null ? widget.workspaceName : '${widget.workspaceName} · ${env.label}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '重新探测环境',
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            onPressed: _probe,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _probeError != null
          ? _probeFailed(theme)
          : env == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _TabBarHeader(controller: _tabController),
                    Expanded(
                      child: InstantSwitchTabView(
                        controller: _tabController,
                        children: [
                          _RemoteMirrorTab(
                            env: env,
                            scope: widget.mirrorScope,
                            runInTerminal: _runInTerminal,
                          ),
                          _RemotePackagesTab(
                            env: env,
                            silentExec: widget.silentExec,
                            runInTerminal: _runInTerminal,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _probeFailed(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '环境探测失败（连接不可用？）\n$_probeError',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _probe,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 内置终端环境管理页同款分段 tab 条。
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

/// 内置终端环境管理页同款卡片。
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
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

// ===== 镜像源 tab =====

class _RemoteMirrorTab extends StatefulWidget {
  const _RemoteMirrorTab({
    required this.env,
    required this.scope,
    required this.runInTerminal,
  });

  final RemoteEnvInfo env;
  final String scope;
  final void Function(String command) runInTerminal;

  @override
  State<_RemoteMirrorTab> createState() => _RemoteMirrorTabState();
}

class _RemoteMirrorTabState extends State<_RemoteMirrorTab> {
  static const _store = TerminalMirrorStore();

  final Map<TerminalMirrorKind, String?> _selected = {};
  final Map<TerminalMirrorKind, List<TerminalMirror>> _custom = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final kind in TerminalMirrorKind.values) {
      _selected[kind] = await _store.selectedId(kind, scope: widget.scope);
      _custom[kind] = await _store.customMirrors(kind, scope: widget.scope);
    }
    if (mounted) setState(() => _loaded = true);
  }

  List<TerminalMirror> _builtIn(TerminalMirrorKind kind) => switch (kind) {
        TerminalMirrorKind.system => remoteSystemMirrorsFor(widget.env),
        TerminalMirrorKind.pip => kPipMirrors,
        TerminalMirrorKind.npm => kNpmMirrors,
      };

  Future<void> _apply(TerminalMirrorKind kind, TerminalMirror mirror) async {
    final command = switch (kind) {
      TerminalMirrorKind.system =>
        remoteSystemMirrorCommand(widget.env, mirror),
      TerminalMirrorKind.pip => pipMirrorCommand(mirror),
      TerminalMirrorKind.npm => npmMirrorCommand(mirror),
    };
    if (command == null) {
      AppToast.info(context, '当前环境暂不支持切换系统源');
      return;
    }
    await _store.setSelectedId(kind, mirror.id, scope: widget.scope);
    if (!mounted) return;
    widget.runInTerminal(command);
  }

  Future<void> _addCustom(TerminalMirrorKind kind) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _AddMirrorDialog(kind: kind),
    );
    if (result == null) return;
    final (name, url) = result;
    await _store.addCustomMirror(
      kind,
      name: name,
      baseUrl: url,
      scope: widget.scope,
    );
    _custom[kind] = await _store.customMirrors(kind, scope: widget.scope);
    if (mounted) setState(() {});
  }

  Future<void> _removeCustom(TerminalMirrorKind kind, String id) async {
    await _store.removeCustomMirror(kind, id, scope: widget.scope);
    _custom[kind] = await _store.customMirrors(kind, scope: widget.scope);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final env = widget.env;
    final systemMirrors = remoteSystemMirrorsFor(env);
    final needsSudoHint =
        !env.isTermux && !env.isRoot && !env.hasSudo && systemMirrors.isNotEmpty;
    final systemSubtitle = env.isTermux
        ? '写入 \$PREFIX/etc/apt/sources.list 并刷新索引（无需 root）。'
        : '生成写系统源配置的命令在终端里执行'
            '${env.sudoPrefix.isEmpty ? '' : '（经 sudo）'}，全程可见。';
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (needsSudoHint)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '当前用户非 root 且没有 sudo，写系统源配置可能失败。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ),
        if (systemMirrors.isEmpty)
          _EnvCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '当前环境（${env.label}）暂不支持切换系统软件源，'
                'pip / npm 源仍可配置。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          )
        else
          _section(
            kind: TerminalMirrorKind.system,
            title: env.isTermux ? 'Termux 软件源' : '系统软件源',
            subtitle: systemSubtitle,
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
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            RadioGroup<String>(
              groupValue: selectedId,
              onChanged: (id) {
                if (id == null) return;
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
  const _AddMirrorDialog({required this.kind});

  final TerminalMirrorKind kind;

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
        TerminalMirrorKind.system => '仓库根 URL，如 https://mirrors.xxx.com/…',
        TerminalMirrorKind.pip =>
          'index-url，如 https://mirrors.xxx.com/pypi/simple',
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

class _RemotePackagesTab extends StatefulWidget {
  const _RemotePackagesTab({
    required this.env,
    required this.silentExec,
    required this.runInTerminal,
  });

  final RemoteEnvInfo env;
  final WorkspaceEnvExec silentExec;
  final void Function(String command) runInTerminal;

  @override
  State<_RemotePackagesTab> createState() => _RemotePackagesTabState();
}

class _RemotePackagesTabState extends State<_RemotePackagesTab> {
  List<TerminalEnvCategory> _categories = const [];
  final Map<String, _PkgStatus> _status = {};
  final Set<String> _selected = {};
  bool _checkFailed = false;

  bool get _installSupported => remoteInstallSupported(widget.env);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final categories = remoteEnvCategoriesFor(widget.env);
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
      final result = await widget.silentExec(batchCheckCommandFor(packages));
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
    final command = remoteInstallCommandFor(widget.env, packages);
    if (command == null) return;
    widget.runInTerminal(command);
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
              '已装状态检测失败（连接不可用或探测超时），可点右上角重新探测。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        if (!_installSupported)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '当前环境（${widget.env.label}）的安装命令未适配，仅显示已装检测结果。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
                        value:
                            _status[pkg.id] == _PkgStatus.installed ||
                            _selected.contains(pkg.id),
                        onChanged: _installSupported &&
                                _status[pkg.id] == _PkgStatus.notInstalled
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
        if (_installSupported)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: FilledButton.icon(
                onPressed: _selected.isEmpty ? null : _install,
                icon: const Icon(LucideIcons.download, size: 18),
                label: Text(
                  _selected.isEmpty
                      ? '勾选要安装的包'
                      : '安装所选（${_selected.length}）',
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
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      _ => Text(
          '未装',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
    };
  }
}
