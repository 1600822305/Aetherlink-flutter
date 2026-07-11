// 「新建 SSH 工作区」 / 「编辑 SSH 连接」 form. Collects connection details, runs a
// one-shot probe (测试连接) that captures the host key for TOFU, then on
// confirmation persists the SshConnection profile + its secret (separate
// plaintext KV, excluded from backup — 设计文档 §5.2).
//
// Three flows share this sheet:
//   · 新建 (editConnection == null): create a fresh connection + workspace.
//   · 复用已有连接: tap an existing profile, pick a root → open a workspace that
//     references it (no new connection/credential — 设计文档 §5.1 方案 C 的复用).
//   · 编辑 (editConnection != null): 管理页「重新授权」rebinds an existing profile's
//     host/credential; saves through and invalidates the pooled transport.
//
// dartssh2 is never imported here: the probe goes through the application-layer
// pool, which returns the neutral domain [SshProbeResult].

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/workspace/application/ssh_connection_pool.dart';
import 'package:aetherlink_flutter/features/workspace/application/ssh_connection_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/ssh_credential_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/ssh_workspace_setup.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_store.dart';
import 'package:aetherlink_flutter/features/workspace/domain/ssh_connection.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// Opens the SSH connection form sheet. [parentRef] is the page's ref so the
/// provider writes (open workspace / switch) outlive the dismissed sheet.
///
/// Pass [editConnection] to edit an existing profile (管理页「重新授权」); leave it
/// null to create a new connection / reuse an existing one. Resolves to `true`
/// when an edit was saved (so the caller can refresh its health badges).
Future<bool?> showSshConnectionFormSheet(
  BuildContext context,
  WidgetRef ref, {
  SshConnection? editConnection,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _SshConnectionFormSheet(
      parentRef: ref,
      editConnection: editConnection,
    ),
  );
}

class _SshConnectionFormSheet extends ConsumerStatefulWidget {
  const _SshConnectionFormSheet({
    required this.parentRef,
    this.editConnection,
  });

  final WidgetRef parentRef;

  /// Non-null = edit an existing profile instead of creating a new one.
  final SshConnection? editConnection;

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

  bool get _isEdit => widget.editConnection != null;

  @override
  void initState() {
    super.initState();
    final conn = widget.editConnection;
    if (conn == null) _cleanupDuplicates();
    if (conn != null) {
      _label.text = conn.label;
      _host.text = conn.host;
      _port.text = conn.port.toString();
      _username.text = conn.username;
      _authType = conn.authType;
      _loadCredential(conn.credentialKeyId);
    }
  }

  // 一次性合并存量重复连接（同 endpoint 多条档案），避免「复用已有连接」
  // 列表被历史重复条目污染。
  Future<void> _cleanupDuplicates() async {
    await ref.read(sshConnectionStoreProvider.future);
    await ref.read(workspaceStoreProvider.future);
    await dedupeSshConnections(
      connections: ref.read(sshConnectionStoreProvider.notifier),
      credentials: ref.read(sshCredentialStoreProvider.notifier),
      workspaces: ref.read(workspaceStoreProvider.notifier),
    );
  }

  // Prefill the secret fields from the credential KV so an edit can keep the
  // existing password / key without re-typing it.
  Future<void> _loadCredential(String credentialKeyId) async {
    final cred = await ref
        .read(sshCredentialStoreProvider.notifier)
        .read(credentialKeyId);
    if (!mounted || cred == null) return;
    setState(() {
      if (cred.password != null) _password.text = cred.password!;
      if (cred.privateKeyPem != null) _privateKey.text = cred.privateKeyPem!;
      if (cred.passphrase != null) _passphrase.text = cred.passphrase!;
    });
  }

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
    AppToast.info(context, message);
  }

  String? _validate() {
    if (_host.text.trim().isEmpty) return '请填写主机';
    if (_username.text.trim().isEmpty) return '请填写用户名';
    if (!_isEdit && _root.text.trim().isEmpty) return '请填写远端起始路径';
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

    final connection = await persistSshConnection(
      connections: ref.read(sshConnectionStoreProvider.notifier),
      credentials: ref.read(sshCredentialStoreProvider.notifier),
      label: label,
      params: _params(expectedFingerprint: fingerprint),
      fingerprint: fingerprint,
    );
    // 同 endpoint 复用时凭据可能已更新，丢掉连接池里的旧通道。
    await ref.read(sshBackendPoolProvider).invalidate(connection.id);

    await _openWorkspaceFor(connection, root: root);
  }

  // ── 编辑已有连接（管理页「重新授权」）─────────────────────────────────────
  Future<void> _testAndSave() async {
    final error = _validate();
    if (error != null) {
      _snack(error);
      return;
    }
    final conn = widget.editConnection!;
    setState(() => _busy = true);
    try {
      final result =
          await ref.read(sshBackendPoolProvider).probe(_params());
      if (!mounted) return;
      if (!result.ok) {
        _snack('连接失败 · ${result.error ?? '未知错误'}');
        return;
      }
      // Re-confirm via TOFU only when the host key is new or has changed
      // (changed key on an edited host could be a MITM — make the user look).
      final fingerprint = result.fingerprint;
      if (fingerprint != null && fingerprint != conn.hostKeyFingerprint) {
        final trusted = await _confirmHostKey(fingerprint);
        if (!trusted || !mounted) return;
      }
      await _saveEdit(conn, fingerprint: fingerprint ?? conn.hostKeyFingerprint);
    } catch (e) {
      _snack('连接失败 · $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveEdit(
    SshConnection conn, {
    required String? fingerprint,
  }) async {
    final ref = widget.parentRef;
    final label = _label.text.trim().isEmpty
        ? '${_username.text.trim()}@${_host.text.trim()}'
        : _label.text.trim();
    await ref.read(sshConnectionStoreProvider.notifier).save(
          conn.copyWith(
            label: label,
            host: _host.text.trim(),
            port: int.tryParse(_port.text.trim()) ?? 22,
            username: _username.text.trim(),
            authType: _authType,
            hostKeyFingerprint: fingerprint,
          ),
        );
    await ref.read(sshCredentialStoreProvider.notifier).save(
          conn.credentialKeyId,
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
    // Drop the pooled transport so the next access reconnects with the new
    // host/credential (设计文档 §4.1 connection 复用).
    await ref.read(sshBackendPoolProvider).invalidate(conn.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  // ── 复用已有连接 ─────────────────────────────────────────────────────────
  Future<void> _openWithExisting(SshConnection conn) async {
    final root = await _promptRoot();
    if (root == null || root.trim().isEmpty || !mounted) return;
    await _openWorkspaceFor(conn, root: root.trim());
  }

  Future<String?> _promptRoot() {
    final controller = TextEditingController(text: '.');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('远端起始路径'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '如 /home/alice/project 或 .',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('打开'),
          ),
        ],
      ),
    );
  }

  // Opens (or refreshes) a workspace pointing at [connection] rooted at [root]
  // and switches into it — shared by the create and reuse flows.
  Future<void> _openWorkspaceFor(
    SshConnection connection, {
    required String root,
  }) async {
    await openAndSwitchSshWorkspace(widget.parentRef, connection, root: root);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPassword = _authType == SshAuthType.password;
    // 复用已有连接 (设计文档 §5.1 方案 C): only offered in the create flow.
    final existing = _isEdit
        ? const <SshConnection>[]
        : (ref.watch(sshConnectionStoreProvider).asData?.value ??
            const <SshConnection>[]);
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
                  _isEdit ? '编辑 SSH 连接' : '新建 SSH 工作区',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (existing.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 4),
                  child: Text(
                    '复用已有连接',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                for (final conn in existing)
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    child: ListTile(
                      leading: Icon(
                        Icons.dns_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(
                        conn.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${conn.username}@${conn.host}:${conn.port}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _busy ? null : () => _openWithExisting(conn),
                    ),
                  ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 4),
                  child: Text(
                    '或新建连接',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
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
              if (!_isEdit) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _root,
                  decoration: const InputDecoration(
                    labelText: '远端起始路径',
                    hintText: '如 /home/alice/project 或 .',
                  ),
                ),
              ],
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
                onPressed:
                    _busy ? null : (_isEdit ? _testAndSave : _testAndConnect),
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEdit ? '测试并保存' : '测试并连接'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
