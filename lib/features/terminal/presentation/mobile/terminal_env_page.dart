// 终端环境管理页：三个 tab ——
// · 概览：发行版 / 架构 / 占用 / 可升级数，一键更新系统、清理缓存；
//   危险操作（清理 / 重装环境）集中在底部并二次确认。
// · 软件源：一键换源（系统 + pip + npm 同时切）、镜像测速、分组单选 + 自定义源。
// · 软件包：搜索 / 筛选，批量安装、升级、卸载，支持输入任意包名。
//
// 所有变更类操作都合成一条命令回放进当前终端会话，让用户实时看到执行过程；
// 只读探测（已装检测、概览）走 TerminalSilentExec 静默执行。

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/terminal_env_access.dart';
import 'package:aetherlink_flutter/core/platform/platform_providers.dart';
import 'package:aetherlink_flutter/features/terminal/application/terminal_engine_manager.dart';
import 'package:aetherlink_flutter/features/terminal/application/terminal_mirror_store.dart';
import 'package:aetherlink_flutter/features/terminal/application/terminal_silent_exec.dart';
import 'package:aetherlink_flutter/features/terminal/domain/terminal_distro.dart';
import 'package:aetherlink_flutter/features/terminal/domain/terminal_env_presets.dart';
import 'package:aetherlink_flutter/features/terminal/domain/terminal_mirrors.dart';
import 'package:aetherlink_flutter/features/terminal/presentation/mobile/terminal_setup_sheet.dart';
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
    length: 3,
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

  /// 清理内置终端环境：先关掉所有 PRoot 会话，再删除 rootfs（只动应用私有
  /// 目录，/sdcard 是绑定挂载的手机存储，不受影响）。[reinstall] 为 true 时
  /// 清理后立即弹出安装面板（可在面板里换发行版）。
  Future<void> _cleanEngine({required bool reinstall}) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(reinstall ? '重装终端环境' : '清理终端环境'),
        content: Text(
          '将删除已安装的 Alpine/Ubuntu 环境（rootfs、已装的软件包、'
          '/root 主目录里的文件）并关闭所有内置终端会话。\n\n'
          '/sdcard 是绑定挂载的手机存储，里面的文件不会被删除。'
          '${reinstall ? '\n清理后会打开安装面板，可重新选择发行版。' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(reinstall ? '清理并重装' : '清理'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(prootSessionsCloserProvider)();
      await TerminalEngineManager.instance.uninstall();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, '清理失败：$e');
      return;
    }
    if (!mounted) return;
    if (reinstall) {
      final installed = await showTerminalSetupSheet(
        context,
        ref.read(fileSystemApiProvider),
      );
      if (!mounted) return;
      if (installed) {
        final distro = await TerminalEngineManager.instance.installedDistro();
        if (!mounted) return;
        setState(() => _distro = distro ?? TerminalDistro.alpine);
        AppToast.success(context, '内置终端环境已重装');
      }
      return;
    }
    AppToast.success(context, '已清理内置终端环境');
    Navigator.of(context).pop();
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
      ),
      body: Column(
        children: [
          _TabBarHeader(controller: _tabController),
          Expanded(
            child: InstantSwitchTabView(
              controller: _tabController,
              children: [
                _OverviewTab(
                  key: ValueKey('overview_${_distro.name}'),
                  distro: _distro,
                  runInTerminal: _runInTerminal,
                  onClean: () => _cleanEngine(reinstall: false),
                  onReinstall: () => _cleanEngine(reinstall: true),
                ),
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

/// 设置页同款分段 tab 条（圆角描边轨道 + 主色淡底胶囊指示器）。
class _TabBarHeader extends StatelessWidget {
  const _TabBarHeader({required this.controller});

  final TabController controller;

  static const List<(IconData, String)> _tabs = [
    (LucideIcons.gauge, '概览'),
    (LucideIcons.databaseZap, '软件源'),
    (LucideIcons.package, '软件包'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelLarge?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );
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
          labelStyle: style,
          unselectedLabelStyle: style,
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
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
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

/// 卡片上方的小节标题（可带右侧操作）。
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text, {this.trailing, this.color});

  final String text;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.labelMedium?.copyWith(
                fontSize: 12.5,
                color: color ?? theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 小号状态胶囊。
class _Chip extends StatelessWidget {
  const _Chip(this.label, {required this.color, this.filled = true});

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.12) : null,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

Divider _divider(BuildContext context) => Divider(
  height: 1,
  thickness: 1,
  indent: 16,
  color: Theme.of(context).dividerColor,
);

// ===== 概览 tab =====

class _OverviewTab extends StatefulWidget {
  const _OverviewTab({
    super.key,
    required this.distro,
    required this.runInTerminal,
    required this.onClean,
    required this.onReinstall,
  });

  final TerminalDistro distro;
  final void Function(String command) runInTerminal;
  final VoidCallback onClean;
  final VoidCallback onReinstall;

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  bool _loading = true;
  bool _failed = false;
  String? _os;
  String? _arch;
  int? _upgradable;
  bool _sdcard = false;
  int? _sizeKb;
  bool _cleaning = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    unawaited(_loadSize());
    try {
      final result = await const TerminalSilentExec().run(
        overviewProbeCommandFor(widget.distro),
      );
      if (!mounted) return;
      final info = parseOverviewOutput(result.stdout);
      setState(() {
        _os = (info['OS']?.isNotEmpty ?? false) ? info['OS'] : null;
        _arch = info['ARCH'];
        _upgradable = int.tryParse(info['UPGRADABLE'] ?? '');
        _sdcard = info['SDCARD'] == '1';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  /// rootfs 占用：在宿主侧用 du 统计（不进 proot，避免把 /sdcard 算进去）。
  Future<void> _loadSize() async {
    try {
      final rootfs = await TerminalEngineManager.instance.rootfsPath();
      final result = await Process.run('du', ['-sk', rootfs]);
      final kb = int.tryParse(
        result.stdout.toString().trim().split(RegExp(r'\s+')).first,
      );
      if (mounted) setState(() => _sizeKb = kb);
    } catch (_) {
      // 统计失败不影响其它信息展示。
    }
  }

  Future<void> _cleanCache() async {
    if (_cleaning) return;
    setState(() => _cleaning = true);
    try {
      await const TerminalSilentExec().run(
        cleanCacheCommandFor(widget.distro),
        timeout: const Duration(seconds: 60),
      );
      if (!mounted) return;
      AppToast.success(context, '已清理软件包缓存');
      await _loadSize();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, '清理失败：$e');
    } finally {
      if (mounted) setState(() => _cleaning = false);
    }
  }

  String get _sizeText {
    final kb = _sizeKb;
    if (kb == null) return '—';
    if (kb >= 1024 * 1024) return '${(kb / 1024 / 1024).toStringAsFixed(1)} GB';
    return '${(kb / 1024).toStringAsFixed(0)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final distroName = widget.distro == TerminalDistro.ubuntu
        ? 'Ubuntu'
        : 'Alpine';
    final title = _os ?? distroName;
    final upgradable = _upgradable ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _EnvCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '当前环境',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_loading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (_failed)
                        _Chip('检测失败', color: cs.error)
                      else
                        const _Chip('运行正常', color: Color(0xFF16A34A)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _Stat(label: '架构', value: _arch ?? '—'),
                      const SizedBox(width: 8),
                      _Stat(label: '占用', value: _sizeText),
                      const SizedBox(width: 8),
                      _Stat(
                        label: '可升级',
                        value: _upgradable == null ? '—' : '$upgradable',
                        highlight: upgradable > 0,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _sdcard ? '/sdcard 已挂载 · 下拉刷新' : '/sdcard 未挂载 · 下拉刷新',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => widget.runInTerminal(
                            systemUpgradeCommandFor(widget.distro),
                          ),
                          icon: const Icon(LucideIcons.refreshCw, size: 16),
                          label: Text(
                            upgradable > 0 ? '更新系统（$upgradable）' : '更新系统',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _cleaning ? null : _cleanCache,
                          icon: _cleaning
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(LucideIcons.eraser, size: 16),
                          label: const Text('清理缓存'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _SectionHeader('危险操作', color: cs.error),
          _EnvCard(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(LucideIcons.rotateCcw, size: 18, color: cs.error),
                  title: Text('重装 / 切换发行版', style: TextStyle(color: cs.error)),
                  subtitle: const Text('清理后重新下载，可改选 Alpine / Ubuntu'),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: widget.onReinstall,
                ),
                _divider(context),
                ListTile(
                  leading: Icon(LucideIcons.trash2, size: 18, color: cs.error),
                  title: Text('清理内置终端环境', style: TextStyle(color: cs.error)),
                  subtitle: const Text('删除 rootfs 与已装软件，/sdcard 不受影响'),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: widget.onClean,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: highlight ? cs.primary : cs.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== 软件源 tab =====

/// 一键换源的厂商：system / pip 用同 id，npm 映射到对应的镜像 id。
const List<(String, String, String)> _kVendors = [
  ('tuna', '清华', 'npmmirror'),
  ('aliyun', '阿里云', 'npmmirror'),
  ('ustc', '中科大', 'npmmirror'),
  ('official', '官方', 'official'),
];

/// 镜像测速：对 baseUrl 发 HEAD，返回毫秒；失败返回 -1。
Future<int> _pingMirror(String url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  final sw = Stopwatch()..start();
  try {
    final request = await client
        .headUrl(Uri.parse(url))
        .timeout(const Duration(seconds: 5));
    request.followRedirects = false;
    final response = await request.close().timeout(const Duration(seconds: 5));
    await response.drain<void>();
    return sw.elapsedMilliseconds;
  } catch (_) {
    return -1;
  } finally {
    client.close(force: true);
  }
}

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
  /// key = baseUrl，值为毫秒（-1 失败，null 测速中）。
  final Map<String, int?> _latency = {};
  bool _loaded = false;
  bool _applying = false;
  bool _pinging = false;

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
    if (!mounted) return;
    setState(() => _loaded = true);
    unawaited(_pingAll());
  }

  List<TerminalMirror> _builtIn(TerminalMirrorKind kind) => switch (kind) {
    TerminalMirrorKind.system => kTerminalMirrors,
    TerminalMirrorKind.pip => kPipMirrors,
    TerminalMirrorKind.npm => kNpmMirrors,
  };

  List<TerminalMirror> _all(TerminalMirrorKind kind) => [
    ..._builtIn(kind),
    ...?_custom[kind],
  ];

  Future<void> _pingAll() async {
    if (_pinging) return;
    final urls = {
      for (final kind in TerminalMirrorKind.values)
        for (final m in _all(kind)) m.baseUrl,
    };
    setState(() {
      _pinging = true;
      for (final url in urls) {
        _latency[url] = null;
      }
    });
    await Future.wait(
      urls.map((url) async {
        final ms = await _pingMirror(url);
        if (mounted) setState(() => _latency[url] = ms);
      }),
    );
    if (mounted) setState(() => _pinging = false);
  }

  /// 某一类里测速最快的镜像 id。
  String? _fastest(TerminalMirrorKind kind) {
    String? best;
    var bestMs = 1 << 30;
    for (final m in _all(kind)) {
      final ms = _latency[m.baseUrl];
      if (ms != null && ms >= 0 && ms < bestMs) {
        bestMs = ms;
        best = m.id;
      }
    }
    return best;
  }

  String _mirrorCommand(TerminalMirrorKind kind, TerminalMirror mirror) =>
      switch (kind) {
        TerminalMirrorKind.system => refreshIndexCommandFor(widget.distro),
        TerminalMirrorKind.pip => pipMirrorCommand(mirror),
        TerminalMirrorKind.npm =>
          'command -v npm >/dev/null 2>&1 && ${npmMirrorCommand(mirror)}',
      };

  /// 应用若干类的镜像，合成一条命令只回放一次。
  Future<void> _applyAll(Map<TerminalMirrorKind, TerminalMirror> picks) async {
    if (_applying || picks.isEmpty) return;
    setState(() => _applying = true);
    try {
      final commands = <String>[];
      for (final MapEntry(key: kind, value: mirror) in picks.entries) {
        await _store.setSelectedId(kind, mirror.id);
        if (kind == TerminalMirrorKind.system) {
          await TerminalEngineManager.instance.setPackageMirror(mirror);
        }
        commands.add(_mirrorCommand(kind, mirror));
      }
      if (!mounted) return;
      widget.runInTerminal(commands.join('; '));
    } catch (e) {
      if (!mounted) return;
      setState(() => _applying = false);
      AppToast.error(context, '切换失败：$e');
    }
  }

  void _applyVendor(String systemId, String npmId) {
    TerminalMirror? find(TerminalMirrorKind kind, String id) {
      for (final m in _builtIn(kind)) {
        if (m.id == id) return m;
      }
      return null;
    }

    final picks = <TerminalMirrorKind, TerminalMirror>{
      for (final (kind, id) in [
        (TerminalMirrorKind.system, systemId),
        (TerminalMirrorKind.pip, systemId),
        (TerminalMirrorKind.npm, npmId),
      ])
        if (find(kind, id) case final m?) kind: m,
    };
    _applyAll(picks);
  }

  /// 当前三类都选了同一厂商时返回该厂商 id。
  String? get _currentVendor {
    for (final (id, _, npmId) in _kVendors) {
      if ((_selected[TerminalMirrorKind.system] ?? 'official') == id &&
          (_selected[TerminalMirrorKind.pip] ?? 'official') == id &&
          (_selected[TerminalMirrorKind.npm] ?? 'official') == npmId) {
        return id;
      }
    }
    return null;
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
    if (!mounted) return;
    setState(() {});
    final ms = await _pingMirror(url);
    if (mounted) setState(() => _latency[url] = ms);
  }

  Future<void> _removeCustom(TerminalMirrorKind kind, String id) async {
    await _store.removeCustomMirror(kind, id);
    _custom[kind] = await _store.customMirrors(kind);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final systemTitle = widget.distro == TerminalDistro.ubuntu
        ? 'apt 系统源'
        : 'apk 系统源';
    final current = _currentVendor;
    final systemFastest = _fastest(TerminalMirrorKind.system);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        _EnvCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '一键换源',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '同时切换系统源、pip 和 npm',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (id, name, npmId) in _kVendors)
                      ChoiceChip(
                        label: Text(
                          id == systemFastest ? '$name · 推荐' : name,
                        ),
                        selected: current == id,
                        showCheckmark: false,
                        onSelected: _applying
                            ? null
                            : (_) => _applyVendor(id, npmId),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        for (final (kind, title, subtitle) in [
          (
            TerminalMirrorKind.system,
            systemTitle,
            '写入 rootfs 并刷新索引',
          ),
          (TerminalMirrorKind.pip, 'pip 源', '写入 ~/.config/pip/pip.conf'),
          (TerminalMirrorKind.npm, 'npm 源', 'npm config set registry'),
        ]) ...[
          _SectionHeader(
            '$title · $subtitle',
            trailing: kind == TerminalMirrorKind.system
                ? InkWell(
                    onTap: _pinging ? null : _pingAll,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.zap, size: 13, color: cs.primary),
                        const SizedBox(width: 3),
                        Text(
                          _pinging ? '测速中…' : '重新测速',
                          style: TextStyle(fontSize: 12, color: cs.primary),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
          _mirrorCard(kind),
        ],
      ],
    );
  }

  Widget _mirrorCard(TerminalMirrorKind kind) {
    final theme = Theme.of(context);
    final selectedId = _selected[kind] ?? 'official';
    final mirrors = _all(kind);
    final fastest = _fastest(kind);
    final rows = <Widget>[];
    for (var i = 0; i < mirrors.length; i++) {
      final mirror = mirrors[i];
      if (i > 0) rows.add(_divider(context));
      rows.add(
        RadioListTile<String>(
          dense: true,
          value: mirror.id,
          enabled: !_applying,
          title: Row(
            children: [
              Flexible(child: Text(mirror.name)),
              if (mirror.id == fastest) ...[
                const SizedBox(width: 6),
                _Chip('最快', color: theme.colorScheme.primary),
              ],
            ],
          ),
          subtitle: Text(
            mirror.baseUrl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
          secondary: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LatencyLabel(
                ms: _latency[mirror.baseUrl],
                pending: _latency.containsKey(mirror.baseUrl),
              ),
              if (mirror.id.startsWith('custom_'))
                IconButton(
                  tooltip: '删除',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(LucideIcons.trash2, size: 16),
                  onPressed: () => _removeCustom(kind, mirror.id),
                ),
            ],
          ),
        ),
      );
    }
    rows
      ..add(_divider(context))
      ..add(
        ListTile(
          dense: true,
          leading: Icon(
            LucideIcons.plus,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          title: Text(
            '添加自定义源',
            style: TextStyle(color: theme.colorScheme.primary),
          ),
          onTap: () => _addCustom(kind),
        ),
      );
    return _EnvCard(
      child: RadioGroup<String>(
        groupValue: selectedId,
        onChanged: (id) {
          if (_applying || id == null || id == selectedId) return;
          final mirror = mirrors.firstWhere((m) => m.id == id);
          _applyAll({kind: mirror});
        },
        child: Column(children: rows),
      ),
    );
  }
}

class _LatencyLabel extends StatelessWidget {
  const _LatencyLabel({required this.ms, required this.pending});

  final int? ms;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final value = ms;
    if (value == null) {
      if (!pending) return const SizedBox.shrink();
      return const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      );
    }
    final (text, color) = switch (value) {
      < 0 => ('超时', cs.error),
      < 150 => ('${value}ms', const Color(0xFF16A34A)),
      < 500 => ('${value}ms', const Color(0xFFCA8A04)),
      _ => (
        value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}s' : '${value}ms',
        cs.error,
      ),
    };
    return Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
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
    TerminalMirrorKind.system =>
      widget.distro == TerminalDistro.ubuntu
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


// ===== 软件包 tab =====

enum _PkgStatus { checking, installed, notInstalled }

enum _PkgFilter { all, installed, notInstalled }

class _PackagesTab extends StatefulWidget {
  const _PackagesTab({required this.distro, required this.runInTerminal});

  final TerminalDistro distro;
  final void Function(String command) runInTerminal;

  @override
  State<_PackagesTab> createState() => _PackagesTabState();
}

class _PackagesTabState extends State<_PackagesTab> {
  final TextEditingController _search = TextEditingController();
  List<TerminalEnvCategory> _categories = const [];
  final Map<String, _PkgStatus> _status = {};
  final Set<String> _selected = {};
  _PkgFilter _filter = _PkgFilter.all;
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

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<TerminalEnvPackage> get _allPackages => [
    for (final c in _categories) ...c.packages,
  ];

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
      final result = await const TerminalSilentExec().run(
        batchCheckCommandFor(packages),
      );
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

  bool _matches(TerminalEnvPackage p) {
    final status = _status[p.id];
    switch (_filter) {
      case _PkgFilter.installed:
        if (status != _PkgStatus.installed) return false;
      case _PkgFilter.notInstalled:
        if (status != _PkgStatus.notInstalled) return false;
      case _PkgFilter.all:
        break;
    }
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return p.name.toLowerCase().contains(q) ||
        p.packageName.toLowerCase().contains(q) ||
        p.description.toLowerCase().contains(q);
  }

  List<String> _names(Iterable<TerminalEnvPackage> packages) => [
    for (final p in packages) ...p.packageName.split(' ').where((s) => s.isNotEmpty),
  ];

  Iterable<TerminalEnvPackage> get _selectedInstalled => _allPackages.where(
    (p) => _selected.contains(p.id) && _status[p.id] == _PkgStatus.installed,
  );

  Iterable<TerminalEnvPackage> get _selectedNew => _allPackages.where(
    (p) => _selected.contains(p.id) && _status[p.id] != _PkgStatus.installed,
  );

  void _installOrUpgrade() {
    final news = _names(_selectedNew);
    final upgrades = _names(_selectedInstalled);
    if (news.isEmpty && upgrades.isEmpty) return;
    widget.runInTerminal(
      installOrUpgradeCommandFor(
        widget.distro,
        newNames: news,
        upgradeNames: upgrades,
      ),
    );
  }

  Future<void> _uninstall() async {
    final packages = _selectedInstalled.toList();
    if (packages.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('卸载软件包'),
        content: Text('将卸载：${packages.map((p) => p.name).join('、')}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('卸载'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    widget.runInTerminal(uninstallCommandFor(widget.distro, _names(packages)));
  }

  void _installCustom(List<String> names) {
    widget.runInTerminal(
      installOrUpgradeCommandFor(widget.distro, newNames: names),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final installedCount = _status.values
        .where((s) => s == _PkgStatus.installed)
        .length;
    final notInstalledCount = _status.values
        .where((s) => s == _PkgStatus.notInstalled)
        .length;

    final query = _search.text.trim();
    final customNames = query.isEmpty ? null : parseCustomPackageNames(query);
    final exactPreset = _allPackages.any(
      (p) => p.packageName.split(' ').contains(query),
    );

    final visible = [
      for (final c in _categories)
        (c, c.packages.where(_matches).toList()),
    ].where((e) => e.$2.isNotEmpty).toList();

    final newCount = _selectedNew.length;
    final upCount = _selectedInstalled.length;
    final primaryLabel = switch ((newCount, upCount)) {
      (0, 0) => '勾选要操作的包',
      (final n, 0) => '安装（$n）',
      (0, final u) => '升级（$u）',
      (final n, final u) => '安装 $n · 升级 $u',
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            autocorrect: false,
            decoration: InputDecoration(
              isDense: true,
              hintText: '搜索，或输入任意包名安装',
              prefixIcon: const Icon(LucideIcons.search, size: 16),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(LucideIcons.x, size: 16),
                      onPressed: () => setState(_search.clear),
                    ),
              filled: true,
              fillColor: cs.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              for (final (f, label) in [
                (_PkgFilter.all, '全部'),
                (_PkgFilter.installed, '已装 $installedCount'),
                (_PkgFilter.notInstalled, '未装 $notInstalledCount'),
              ]) ...[
                ChoiceChip(
                  label: Text(label),
                  selected: _filter == f,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _filter = f),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        if (_checkFailed)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              '已装状态检测失败（终端未安装或探测超时），可直接勾选安装。',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              children: [
                if (customNames != null && !exactPreset)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _EnvCard(
                      child: ListTile(
                        leading: Icon(LucideIcons.download, size: 18, color: cs.primary),
                        title: Text('安装「${customNames.join(' ')}」'),
                        subtitle: Text(
                          installOrUpgradeCommandFor(
                            widget.distro,
                            newNames: customNames,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                        ),
                        onTap: () => _installCustom(customNames),
                      ),
                    ),
                  ),
                if (visible.isEmpty && customNames == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text(
                        '没有匹配的软件包',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ),
                for (final (category, packages) in visible) ...[
                  _SectionHeader('${category.name} · ${category.description}'),
                  _EnvCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < packages.length; i++) ...[
                          if (i > 0) _divider(context),
                          _packageTile(packages[i]),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                if (upCount > 0) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                    ),
                    onPressed: _uninstall,
                    icon: const Icon(LucideIcons.trash2, size: 16),
                    label: Text('卸载 $upCount'),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton.icon(
                    onPressed: newCount + upCount == 0 ? null : _installOrUpgrade,
                    icon: const Icon(LucideIcons.download, size: 18),
                    label: Text(primaryLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _packageTile(TerminalEnvPackage pkg) {
    final cs = Theme.of(context).colorScheme;
    final status = _status[pkg.id];
    return CheckboxListTile(
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      value: _selected.contains(pkg.id),
      onChanged: status == _PkgStatus.checking
          ? null
          : (checked) => setState(() {
              if (checked == true) {
                _selected.add(pkg.id);
              } else {
                _selected.remove(pkg.id);
              }
            }),
      title: Text(pkg.name),
      subtitle: Text(
        '${pkg.description} · ${pkg.packageName}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      secondary: switch (status) {
        _PkgStatus.checking => const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        _PkgStatus.installed => const _Chip('已装', color: Color(0xFF16A34A)),
        _ => _Chip('未装', color: cs.onSurfaceVariant),
      },
    );
  }
}
