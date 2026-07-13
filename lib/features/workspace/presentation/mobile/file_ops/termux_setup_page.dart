// 「Termux 一键接入」 page (设计文档 §10.5 方式 A / Termux-A).
//
// Flow: detect Termux install → generate an Ed25519 key pair (private key kept
// local; public key baked into a one-shot setup script) → user pastes the
// generated one-liner (or shares the script file) into Termux, which installs
// openssh, authorizes the key, and starts sshd on 127.0.0.1:8022 → user taps
// 「完成 / 测试连接」 → the app probes, persists a privateKey SshConnection and a
// Termux workspace, and switches into it. Termux is just a local SSH target
// (§1 白嫖), so this reuses RemoteSshBackend with zero new backend code.
//
// dartssh2 is never imported here: keygen is pure Dart (domain/ssh_keygen.dart),
// and the probe goes through the application-layer pool returning the neutral
// SshProbeResult.
//
// Termux-B (full automation via RUN_COMMAND, 设计文档 §10.5 方式 B): once the
// user has enabled allow-external-apps in Termux, the page can send the same
// setup script through the RUN_COMMAND intent so no pasting is needed.
//
// This is a full-screen route (was a bottom sheet): the flow is long, involves
// keyboard-free but multi-step guidance and app-switching to Termux, so it owns
// its own navigation entry and uses its own ref (no parent-ref hand-off).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:aetherlink_flutter/core/platform/platform_providers.dart';
import 'package:aetherlink_flutter/core/platform/termux_api.dart';
import 'package:aetherlink_flutter/features/workspace/application/ssh_connection_pool.dart';
import 'package:aetherlink_flutter/features/workspace/application/ssh_connection_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/ssh_credential_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/ssh_workspace_setup.dart';
import 'package:aetherlink_flutter/features/workspace/domain/ssh_connection.dart';
import 'package:aetherlink_flutter/features/workspace/domain/ssh_keygen.dart';
import 'package:aetherlink_flutter/features/workspace/domain/termux_setup.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/file_ops/proot_folder_picker_sheet.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// F-Droid page for the supported Termux build (Play build is deprecated).
const String _kTermuxFdroidUrl = 'https://f-droid.org/packages/com.termux/';

/// The Termux one-tap setup page.
class TermuxSetupPage extends ConsumerStatefulWidget {
  const TermuxSetupPage({super.key});

  @override
  ConsumerState<TermuxSetupPage> createState() => _TermuxSetupPageState();
}

class _TermuxSetupPageState extends ConsumerState<TermuxSetupPage> {
  // Generated once and held for the page's lifetime: the displayed command and
  // the stored private key must come from the same pair.
  late final SshGeneratedKeyPair _keys;
  late final String _oneLiner;

  TermuxInstallStatus? _status;
  bool _detecting = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _keys = SshKeygen.generateEd25519();
    _oneLiner = TermuxSetup.buildOneLiner(authorizedKey: _keys.authorizedKeyLine);
    _detect();
  }

  Future<void> _detect() async {
    setState(() => _detecting = true);
    final status = await ref.read(termuxApiProvider).detect();
    if (!mounted) return;
    setState(() {
      _status = status;
      _detecting = false;
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    AppToast.info(context, message);
  }

  Future<void> _copyCommand() async {
    await Clipboard.setData(ClipboardData(text: _oneLiner));
    _snack('已复制命令，去 Termux 粘贴执行');
  }

  Future<void> _copyAllowExternalApps() async {
    await Clipboard.setData(
      const ClipboardData(text: TermuxSetup.allowExternalAppsCommand),
    );
    _snack('已复制，去 Termux 粘贴执行一次即可开启');
  }

  // Termux-B：通过 RUN_COMMAND intent 让 Termux 代跑同一份脚本，免粘贴。
  // 首次会先弹系统权限申请（RUN_COMMAND 是运行时权限）。
  Future<void> _autoRun() async {
    setState(() => _busy = true);
    try {
      await ref.read(termuxApiProvider).runCommand(
            TermuxSetup.buildScript(authorizedKey: _keys.authorizedKeyLine),
          );
      _snack('已发送到 Termux。切过去看执行过程，看到「完成」后回来点'
          '「完成 / 测试连接」。');
    } on TermuxRunCommandException catch (e) {
      if (e.permissionDenied) {
        _snack('本机的「运行 Termux 命令」权限被拒绝。请重试并在弹窗里允许，'
            '若不再弹窗，去系统设置→应用→权限里手动开启。');
      } else if (e.externalAppsDisabled) {
        _snack('Termux 未开启 allow-external-apps。请先用下方「复制开启命令」'
            '在 Termux 里跑一次，再重试。');
      } else {
        _snack('发送失败 · $e');
      }
    } catch (e) {
      _snack('发送失败 · $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openTermux() async {
    try {
      await ref.read(termuxApiProvider).openApp();
    } catch (e) {
      _snack('打不开 Termux · $e');
    }
  }

  Future<void> _shareScript() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${TermuxSetup.scriptFileName}');
      await file.writeAsString(
        TermuxSetup.buildScript(authorizedKey: _keys.authorizedKeyLine),
      );
      await ref.read(shareApiProvider).shareFiles(
        [file.path],
        subject: TermuxSetup.scriptFileName,
      );
    } catch (e) {
      _snack('分享失败 · $e');
    }
  }

  // Probes the freshly configured sshd (stat'ing [rootToStat]) and persists
  // the SshConnection profile. Returns null (after surfacing the error) when
  // the probe fails. Shared by the three 完成 entries below.
  Future<SshConnection?> _probeAndPersist({
    required String rootToStat,
    required String label,
    required String failureHint,
  }) async {
    final params = SshConnectParams(
      host: '127.0.0.1',
      port: TermuxSetup.defaultPort,
      username: 'termux', // Termux sshd ignores the username; key auth decides.
      authType: SshAuthType.privateKey,
      privateKeyPem: _keys.privateKeyPem,
    );
    final result = await ref
        .read(sshBackendPoolProvider)
        .probe(params, rootToStat: rootToStat);
    if (!mounted) return null;
    if (!result.ok) {
      _snack('${result.error ?? '未知错误'}\n$failureHint');
      return null;
    }
    final connection = await persistSshConnection(
      connections: ref.read(sshConnectionStoreProvider.notifier),
      credentials: ref.read(sshCredentialStoreProvider.notifier),
      label: label,
      params: params,
      fingerprint: result.fingerprint, // localhost: auto-trust on first use.
    );
    // 同 endpoint 复用时私钥已换新（每次打开都重新生成密钥对），
    // 丢掉连接池里的旧通道让下次访问用新钥重连。
    await ref.read(sshBackendPoolProvider).invalidate(connection.id);
    return connection;
  }

  // Probe the freshly configured sshd, then persist a Termux workspace rooted
  // at [root] and switch into it. Reuses the shared SSH persist/open helpers.
  // [root] is '.' (Termux home) for the default entry, or the shared-storage
  // path when the user picks 「浏览手机存储」 — that path is only reachable after
  // `termux-setup-storage` granted the permission, so a failed stat there hints
  // at a denied/missing grant.
  Future<void> _finish({String root = '.'}) async {
    setState(() => _busy = true);
    final isSharedStorage = root == TermuxSetup.sharedStorageRoot;
    try {
      final connection = await _probeAndPersist(
        rootToStat: root,
        label: isSharedStorage ? 'Termux · 手机存储' : 'Termux',
        failureHint: isSharedStorage
            ? '请在 Termux 里执行 termux-setup-storage 并同意授权后重试。'
            : '请确认已在 Termux 里跑完命令并看到「完成」提示。',
      );
      if (connection == null) return;
      await openAndSwitchSshWorkspace(
        ref,
        connection,
        root: root,
        backendType: WorkspaceBackendType.termux,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _snack('连接失败 · $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // 项目模式入口（对齐内置终端的「打开项目文件夹」）：探活 sshd 后用
  // IDE 式文件夹浏览器在 Termux $HOME 下选一个目录，工作区锚定到它
  //（双作用域设计稿 §2.2）。
  Future<void> _finishProject() async {
    setState(() => _busy = true);
    try {
      final connection = await _probeAndPersist(
        rootToStat: '.',
        label: 'Termux',
        failureHint: '请确认已在 Termux 里跑完命令并看到「完成」提示。',
      );
      if (connection == null) return;
      final backend =
          ref.read(sshBackendPoolProvider).backendFor(connection.id);
      // 浏览器需要绝对路径才能逐级进出，先把 '.' 解析成 $HOME。
      final home =
          (await backend.exec(r'printf %s "$HOME"')).stdout.trim();
      if (home.isEmpty || !home.startsWith('/')) {
        _snack('取不到 Termux 主目录，请重试');
        return;
      }
      if (!mounted) return;
      final pick = await showProotFolderPickerSheet(
        context,
        backend: backend,
        initialPath: home,
      );
      if (pick == null) return;
      final root = pick.path;
      final name =
          root == '/' ? '/' : root.substring(root.lastIndexOf('/') + 1);
      await openAndSwitchSshWorkspace(
        ref,
        connection,
        root: root,
        backendType: WorkspaceBackendType.termux,
        scope: WorkspaceScope.project,
        isolatedHome: pick.isolatedHome,
        name: name,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _snack('连接失败 · $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Termux 一键接入')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4),
              child: Text(
                '在同机 Termux 里跑一条命令，App 即可像 SSH 一样浏览其文件并执行命令。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            _buildDetectionBanner(theme),
            const SizedBox(height: 12),
            _buildSteps(theme),
            const SizedBox(height: 12),
            _buildCommandBox(theme),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _copyCommand,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('复制命令'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _shareScript,
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: const Text('分享脚本'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildAutoRun(theme),
            const SizedBox(height: 12),
            _buildTips(theme),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : () => _finish(),
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('完成 / 测试连接'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _finishProject,
              icon: const Icon(Icons.folder_open_outlined, size: 18),
              label: const Text('选择项目文件夹（IDE 式）'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _finish(root: TermuxSetup.sharedStorageRoot),
              icon: const Icon(Icons.sd_storage_outlined, size: 18),
              label: const Text('浏览手机存储 (/sdcard)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionBanner(ThemeData theme) {
    if (_detecting) {
      return _banner(
        theme,
        color: theme.colorScheme.surfaceContainerHighest,
        icon: Icons.hourglass_empty,
        text: '正在检测 Termux ...',
      );
    }
    final status = _status;
    if (status == null || !status.installed) {
      return _banner(
        theme,
        color: theme.colorScheme.errorContainer,
        icon: Icons.error_outline,
        text: '未检测到 Termux。请安装 F-Droid 或 GitHub 版（不要用已废弃的 Play 版）。',
        action: TextButton(
          onPressed: () => launchUrl(
            Uri.parse(_kTermuxFdroidUrl),
            mode: LaunchMode.externalApplication,
          ),
          child: const Text('去安装'),
        ),
        secondaryAction: TextButton(
          onPressed: _detect,
          child: const Text('重新检测'),
        ),
      );
    }
    if (status.isUnsupportedPlayBuild) {
      return _banner(
        theme,
        color: theme.colorScheme.errorContainer,
        icon: Icons.warning_amber_outlined,
        text: '检测到 Play 商店版 Termux（已废弃），pkg/sshd 可能跑不通，'
            '强烈建议改装 F-Droid/GitHub 版。',
        action: TextButton(onPressed: _detect, child: const Text('重新检测')),
      );
    }
    final label = status.variant == TermuxVariant.fdroid
        ? '已检测到 Termux（F-Droid）'
        : '已检测到 Termux';
    return _banner(
      theme,
      color: theme.colorScheme.primary.withValues(alpha: 0.12),
      icon: Icons.check_circle_outline,
      text: label,
      action: TextButton.icon(
        onPressed: _openTermux,
        icon: const Icon(Icons.open_in_new, size: 16),
        label: const Text('打开 Termux'),
      ),
    );
  }

  Widget _banner(
    ThemeData theme, {
    required Color color,
    required IconData icon,
    required String text,
    Widget? action,
    Widget? secondaryAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text, style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
          if (action != null || secondaryAction != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (secondaryAction != null) secondaryAction,
                if (action != null) action,
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSteps(ThemeData theme) {
    const steps = [
      '1. 打开 Termux',
      '2. 复制下面的命令并粘贴执行（首次需联网装 openssh）',
      '3. 看到「完成」提示后，回到这里点「完成 / 测试连接」',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in steps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            child: Text(s, style: theme.textTheme.bodyMedium),
          ),
      ],
    );
  }

  Widget _buildCommandBox(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SelectableText(
        _oneLiner,
        maxLines: 6,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }

  // Termux-B（方式 B）区块：免粘贴，前提是 Termux 已开 allow-external-apps。
  Widget _buildAutoRun(ThemeData theme) {
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('全自动接入（免粘贴）', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            '若 Termux 已开启 allow-external-apps，可直接让 App 代跑上面的脚本，'
            '无需手动复制粘贴。首次需先在 Termux 里跑一次开启命令，'
            '并在代跑时允许本机的「运行 Termux 命令」权限弹窗。',
            style: muted,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _busy ? null : _autoRun,
                  icon: const Icon(Icons.play_arrow_outlined, size: 18),
                  label: const Text('代跑脚本'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _copyAllowExternalApps,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('复制开启命令'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTips(ThemeData theme) {
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('小贴士', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text('· 必须用 F-Droid / GitHub 版 Termux，Play 版已废弃跑不通。', style: muted),
        Text('· 请关闭 Termux 的电池优化，并装 Termux:Boot 以便开机自启保活。', style: muted),
        Text('· 首次 pkg install 需联网；国内慢可先执行 termux-change-repo 换源。', style: muted),
        Text('· 命令里已内置一次性公钥，私钥仅留在本机（不会导出/备份）。', style: muted),
        Text('· 脚本会执行 termux-setup-storage 申请存储权限，同意后才能用'
            '「浏览手机存储」查看相册/下载等；拒绝只影响 /sdcard，不影响连接。', style: muted),
      ],
    );
  }
}
