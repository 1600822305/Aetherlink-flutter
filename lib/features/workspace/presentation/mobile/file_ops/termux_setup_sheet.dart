// 「Termux 一键接入」 sheet (设计文档 §10.5 方式 A / Termux-A).
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
// Termux-B (full automation via RUN_COMMAND, 设计文档 §10.5 方式 B) is a later
// follow-up: it needs allow-external-apps + a manifest RUN_COMMAND permission
// and is intentionally out of scope here.

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
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// F-Droid page for the supported Termux build (Play build is deprecated).
const String _kTermuxFdroidUrl = 'https://f-droid.org/packages/com.termux/';

/// Opens the Termux one-tap setup sheet. [parentRef] is the page's ref so the
/// open/switch writes outlive the dismissed sheet.
Future<void> showTermuxSetupSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _TermuxSetupSheet(parentRef: ref),
  );
}

class _TermuxSetupSheet extends ConsumerStatefulWidget {
  const _TermuxSetupSheet({required this.parentRef});

  final WidgetRef parentRef;

  @override
  ConsumerState<_TermuxSetupSheet> createState() => _TermuxSetupSheetState();
}

class _TermuxSetupSheetState extends ConsumerState<_TermuxSetupSheet> {
  // Generated once and held for the sheet's lifetime: the displayed command and
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

  // Probe the freshly configured sshd, then persist a Termux workspace and
  // switch into it. Reuses the shared SSH persist/open helpers.
  Future<void> _finish() async {
    setState(() => _busy = true);
    final params = SshConnectParams(
      host: '127.0.0.1',
      port: TermuxSetup.defaultPort,
      username: 'termux', // Termux sshd ignores the username; key auth decides.
      authType: SshAuthType.privateKey,
      privateKeyPem: _keys.privateKeyPem,
    );
    try {
      final result = await ref
          .read(sshBackendPoolProvider)
          .probe(params, rootToStat: '.');
      if (!mounted) return;
      if (!result.ok) {
        _snack('连接失败 · ${result.error ?? '未知错误'}\n'
            '请确认已在 Termux 里跑完命令并看到「完成」提示。');
        return;
      }
      final connection = await persistSshConnection(
        connections: ref.read(sshConnectionStoreProvider.notifier),
        credentials: ref.read(sshCredentialStoreProvider.notifier),
        label: 'Termux',
        params: params,
        fingerprint: result.fingerprint, // localhost: auto-trust on first use.
      );
      await openAndSwitchSshWorkspace(
        widget.parentRef,
        connection,
        root: '.',
        backendType: WorkspaceBackendType.termux,
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
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Text(
                  'Termux 一键接入',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
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
              _buildTips(theme),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _finish,
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('完成 / 测试连接'),
              ),
            ],
          ),
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
      ],
    );
  }
}
