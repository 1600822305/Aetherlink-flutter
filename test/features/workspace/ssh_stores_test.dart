// Round-trip tests for the SSH-1 KV stores against a real in-memory Drift DB
// (the same harness widget tests use). Covers: connection profiles
// (add/byId/fingerprint/remove) and secrets (save/read/delete) living under
// their own key — the latter is what backup export must exclude (设计文档 §5.2).

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:aetherlink_flutter/features/workspace/application/ssh_connection_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/ssh_credential_store.dart';
import 'package:aetherlink_flutter/features/workspace/domain/ssh_connection.dart';

void main() {
  ProviderContainer makeContainer() {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(ChatRepositoryImpl(db)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('credential key constant matches the backup-excluded literal', () {
    // backup_service hard-codes this literal in its exclusion set (it can't
    // import workspace's application). Keep them in sync.
    expect(kSshCredentialsKey, 'workspace_ssh_credentials');
  });

  group('SshCredentialStore', () {
    test('saves, reads back and deletes a secret by credentialKeyId', () async {
      final c = makeContainer();
      final store = c.read(sshCredentialStoreProvider.notifier);

      expect(await store.read('cred-1'), isNull);

      await store.save('cred-1', const SshCredential(password: 'hunter2'));
      await store.save(
        'cred-2',
        const SshCredential(privateKeyPem: 'PEM', passphrase: 'pp'),
      );

      expect((await store.read('cred-1'))?.password, 'hunter2');
      final two = await store.read('cred-2');
      expect(two?.privateKeyPem, 'PEM');
      expect(two?.passphrase, 'pp');

      await store.delete('cred-1');
      expect(await store.read('cred-1'), isNull);
      // Deleting one secret leaves the others intact.
      expect((await store.read('cred-2'))?.privateKeyPem, 'PEM');
    });
  });

  group('SshConnectionStore', () {
    test('adds (minting id + credentialKeyId), looks up and removes', () async {
      final c = makeContainer();
      await c.read(sshConnectionStoreProvider.future);
      final store = c.read(sshConnectionStoreProvider.notifier);

      final conn = await store.add(
        label: 'VPS',
        host: 'example.com',
        port: 2222,
        username: 'alice',
        authType: SshAuthType.password,
      );
      expect(conn.id, isNotEmpty);
      expect(conn.credentialKeyId, isNotEmpty);
      expect(store.byId(conn.id)?.host, 'example.com');
      expect(store.byId(conn.id)?.port, 2222);

      await store.setHostKeyFingerprint(conn.id, 'SHA256:abc');
      expect(store.byId(conn.id)?.hostKeyFingerprint, 'SHA256:abc');

      await store.remove(conn.id);
      expect(store.byId(conn.id), isNull);
    });

    test('persists across a fresh store build (same DB)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = ChatRepositoryImpl(db);

      final c1 = ProviderContainer(
        overrides: [chatRepositoryProvider.overrideWithValue(repo)],
      );
      await c1.read(sshConnectionStoreProvider.future);
      final conn =
          await c1.read(sshConnectionStoreProvider.notifier).add(
                label: 'box',
                host: 'h',
                username: 'u',
                authType: SshAuthType.privateKey,
              );
      c1.dispose();

      final c2 = ProviderContainer(
        overrides: [chatRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c2.dispose);
      final loaded = await c2.read(sshConnectionStoreProvider.future);
      expect(loaded.any((x) => x.id == conn.id), isTrue);
    });
  });
}
