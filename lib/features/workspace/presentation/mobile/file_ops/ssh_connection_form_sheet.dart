// 「新建 SSH 工作区」 form. Collects connection details, runs a one-shot probe
// (测试连接) that captures the host key for TOFU, then on confirmation persists
// the SshConnection profile + its secret (separate plaintext KV, excluded from
// backup — 设计文档 §5.2), creates a workspace pointing at it and switches in.
//
// dartssh2 is never imported here: the probe goes through the application-layer
// pool, which returns the neutral domain [SshProbeResult].

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/workspace/application/ssh_connection_pool.dart';
import 'package:aetherlink_flutter/features/workspace/application/ssh_connection_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/ssh_credential_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/domain/ssh_connection.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';

/// Opens the 「新建 SSH 工作区」 form sheet. [parentRef] is the page's ref so the
/// provider writes (open workspace / switch) outlive the dismissed sheet.
Future<void> showSshConnectionFormSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _SshConnectionFormSheet(parentRef: ref),
  );
}

class _SshConnectionFormSheet extends ConsumerStatefulWidget {
  const _SshConnectionFormSheet({required this.parentRef});

  final WidgetRef parentRef;

  @override
  ConsumerState<_SshConnectionFormSheet> createState() =>
      _SshConnectionFormSheetState();
}

class _SshConnectionFormSheetState
    extends ConsumerState<_SshConnectionFormSheet> {
  final _label = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController(text: '22');
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _privateKey = TextEditingController();
  final _passphrase = TextEditingController();
  final _root = TextEditingController(text: '.');

  SshAuthType _authType = SshAuthType.password;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _label,
      _host,
      _port,
      _username,
      _password,
      _privateKey,
      _passphrase,
      _root,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validate() {
    if (_host.text.trim().isEmpty) return '请填写主机';
    if (_username.text.trim().isEmpty) return '请填写用户名';
    if (_root.text.trim().isEmpty) return '请填写远端起始路径';
    if (_authType == SshAuthType.password && _password.text.isEmpty) {
      return '请填写密码';
    }
    if (_authType == SshAuthType.privateKey && _privateKey.text.trim().isEmpty) {
      return '请粘贴私钥 (PEM)';
    }
    return null;
  }

  SshConnectParams _params({String? expectedFingerprint}) => SshConnectParams(
        host: _host.text.trim(),
        port: int.tryParse(_port.text.trim()) ?? 22,
        username: _username.text.trim(),
        authType: _authType,
        password: _authType == SshAuthType.password ? _password.text : null,
        privateKeyPem:
            _authType == SshAuthType.privateKey ? _privateKey.text : null,
        passphrase: _authType == SshAuthType.privateKey &&
                _passphrase.text.isNotEmpty
            ? _passphrase.text
            : null,
        expectedFingerprint: expectedFingerprint,
      );

  Future<void> _testAndConnect() async {
    final error = _validate();
    if (error != null) {
      _snack(error);
      return;
    }
    setState(() => _busy = true);
    final root = _root.text.trim();
    try {
      final result = await ref
          .read(sshBackendPoolProvider)
          .probe(_params(), rootToStat: root);
      if (!mounted) return;
      if (!result.ok) {
        _snack('连接失败 · ${result.error ?? '未知错误'}');
        return;
      }
      // TOFU: show the host key fingerprint for the user to trust on first use.
      final fingerprint = result.fingerprint;
      if (fingerprint != null) {
        final trusted = await _confirmHostKey(fingerprint);
        if (!trusted || !mounted) return;
      }
      await _persistAndOpen(root: root, fingerprint: fingerprint);
    } catch (e) {
      _snack('连接失败 · $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmHostKey(String fingerprint) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认主机指纹'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('首次连接该主机，请核对其密钥指纹后再信任：'),
            const SizedBox(height: 8),
            SelectableText(
              fingerprint,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('信任并保存'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _persistAndOpen({
    required String root,
    required String? fingerprint,
  }) async {
    final ref = widget.parentRef;
    final label = _label.text.trim().isEmpty
        ? '${_username.text.trim()}@${_host.text.trim()}'
        : _label.text.trim();

    final connection =
        await ref.read(sshConnectionStoreProvider.notifier).add(
              label: label,
              host: _host.text.trim(),
              port: int.tryParse(_port.text.trim()) ?? 22,
              username: _username.text.trim(),
              authType: _authType,
              hostKeyFingerprint: fingerprint,
            );
    await ref.read(sshCredentialStoreProvider.notifier).save(
          connection.credentialKeyId,
          SshCredential(
            password: _authType == SshAuthType.password ? _password.text : null,
            privateKeyPem:
                _authType == SshAuthType.privateKey ? _privateKey.text : null,
            passphrase: _authType == SshAuthType.privateKey &&
                    _passphrase.text.isNotEmpty
                ? _passphrase.text
                : null,
          ),
        );

    final workspace = await ref.read(workspaceStoreProvider.notifier).open(
          name: label,
          backendType: WorkspaceBackendType.ssh,
          root: root,
          displayPath: '${connection.username}@${connection.host}:$root',
          connectionId: connection.id,
        );
    ref.read(currentWorkspaceProvider.notifier).open(workspace);
    ref.read(openWorkspaceFilesProvider.notifier).reset();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPassword = _authType == SshAuthType.password;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 4),
                child: Text(
                  '新建 SSH 工作区',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextField(
                controller: _label,
                decoration: const InputDecoration(
                  labelText: '名称 (可选)',
                  hintText: '如 我的 VPS',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _host,
                      decoration: const InputDecoration(
                        labelText: '主机',
                        hintText: 'example.com',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _port,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '端口'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _username,
                decoration: const InputDecoration(labelText: '用户名'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _root,
                decoration: const InputDecoration(
                  labelText: '远端起始路径',
                  hintText: '如 /home/alice/project 或 .',
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<SshAuthType>(
                segments: const [
                  ButtonSegment(
                    value: SshAuthType.password,
                    label: Text('密码'),
                  ),
                  ButtonSegment(
                    value: SshAuthType.privateKey,
                    label: Text('私钥'),
                  ),
                ],
                selected: {_authType},
                onSelectionChanged: (s) =>
                    setState(() => _authType = s.first),
              ),
              const SizedBox(height: 8),
              if (isPassword)
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '密码'),
                )
              else ...[
                TextField(
                  controller: _privateKey,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: '私钥 (PEM)',
                    hintText: '-----BEGIN OPENSSH PRIVATE KEY-----',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passphrase,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '私钥口令 (可选)',
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _testAndConnect,
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('测试并连接'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
