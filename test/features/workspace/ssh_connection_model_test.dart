// Locks the JSON contracts the SSH-0 seam depends on: the new
// [SshConnection] profile round-trips losslessly and never serializes a
// secret, and [Workspace] stays backward-compatible with pre-SSH records that
// have no `connectionId`.

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/domain/ssh_connection.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';

void main() {
  group('SshConnection JSON', () {
    test('round-trips all fields', () {
      const c = SshConnection(
        id: 'ssh-1',
        label: '我的 VPS',
        host: 'example.com',
        port: 2222,
        username: 'alice',
        authType: SshAuthType.privateKey,
        credentialKeyId: 'sshcred-9',
        hostKeyFingerprint: 'SHA256:abc',
      );
      final back = SshConnection.fromJson(c.toJson());
      expect(back.id, c.id);
      expect(back.label, c.label);
      expect(back.host, c.host);
      expect(back.port, c.port);
      expect(back.username, c.username);
      expect(back.authType, SshAuthType.privateKey);
      expect(back.credentialKeyId, c.credentialKeyId);
      expect(back.hostKeyFingerprint, 'SHA256:abc');
    });

    test('carries only the credential pointer, never a secret', () {
      const c = SshConnection(
        id: 'ssh-1',
        label: 'box',
        host: 'h',
        port: 22,
        username: 'u',
        authType: SshAuthType.password,
        credentialKeyId: 'sshcred-1',
      );
      final json = c.toJson();
      expect(json['credentialKeyId'], 'sshcred-1');
      // No secret-bearing keys leak into the (backed-up) profile JSON.
      expect(json.containsKey('password'), isFalse);
      expect(json.containsKey('privateKey'), isFalse);
      expect(json.containsKey('passphrase'), isFalse);
      // Optional fingerprint omitted when null.
      expect(json.containsKey('hostKeyFingerprint'), isFalse);
    });

    test('unknown authType falls back to password', () {
      final back = SshConnection.fromJson(const {
        'id': 'x',
        'label': 'l',
        'host': 'h',
        'port': 22,
        'username': 'u',
        'authType': 'bogus',
        'credentialKeyId': 'k',
      });
      expect(back.authType, SshAuthType.password);
    });
  });

  group('Workspace.connectionId back-compat', () {
    test('a pre-SSH record without connectionId decodes to null', () {
      final w = Workspace.fromJson(const {
        'id': 'ws-1',
        'name': 'old',
        'backendType': 'localSaf',
        'root': 'content://tree/x',
        'lastOpenedAt': '2024-01-01T00:00:00.000',
      });
      expect(w.connectionId, isNull);
      // And it doesn't get serialized back when null.
      expect(w.toJson().containsKey('connectionId'), isFalse);
    });

    test('an SSH record round-trips connectionId', () {
      final w = Workspace(
        id: 'ws-2',
        name: 'remote',
        backendType: WorkspaceBackendType.ssh,
        root: '/home/alice/project',
        connectionId: 'ssh-1',
        lastOpenedAt: DateTime.parse('2024-01-01T00:00:00.000'),
      );
      final back = Workspace.fromJson(w.toJson());
      expect(back.connectionId, 'ssh-1');
      expect(back.backendType, WorkspaceBackendType.ssh);
    });

    test('copyWith preserves connectionId', () {
      final w = Workspace(
        id: 'ws-3',
        name: 'remote',
        backendType: WorkspaceBackendType.ssh,
        root: '/x',
        connectionId: 'ssh-7',
        lastOpenedAt: DateTime.now(),
      );
      expect(w.copyWith(name: 'renamed').connectionId, 'ssh-7');
    });
  });
}
