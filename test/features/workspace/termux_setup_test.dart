// Tests the pure Termux setup-script assembly (设计文档 §10.5 / Termux-A): the
// script wires up openssh + the app's public key, and the one-liner is a
// self-contained, offline base64 of that very script.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/domain/termux_setup.dart';

void main() {
  const key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5fakekeydata aetherlink@termux';

  group('TermuxSetup.buildScript', () {
    test('installs openssh, authorizes the key and starts sshd on the port', () {
      final script = TermuxSetup.buildScript(authorizedKey: key);

      expect(script, contains('pkg install -y openssh'));
      expect(script, contains(key));
      expect(script, contains('~/.ssh/authorized_keys'));
      expect(script, contains('termux-wake-lock'));
      expect(script, contains('sshd'));
      // Default Termux port.
      expect(script, contains('PORT=8022'));
    });

    test('requests shared-storage access via termux-setup-storage', () {
      final script = TermuxSetup.buildScript(authorizedKey: key);
      expect(script, contains('termux-setup-storage'));
    });

    test('honours a custom port', () {
      final script = TermuxSetup.buildScript(authorizedKey: key, port: 9000);
      expect(script, contains('PORT=9000'));
    });
  });

  group('TermuxSetup.buildOneLiner', () {
    test('is a base64 pipe-to-bash that decodes back to the full script', () {
      final oneLiner = TermuxSetup.buildOneLiner(authorizedKey: key);

      expect(oneLiner, startsWith('echo '));
      expect(oneLiner, endsWith('| base64 -d | bash'));

      // Extract the base64 payload and confirm it is exactly buildScript.
      final encoded = oneLiner
          .substring('echo '.length, oneLiner.indexOf(' | base64 -d | bash'));
      final decoded = utf8.decode(base64.decode(encoded));
      expect(decoded, TermuxSetup.buildScript(authorizedKey: key));
    });
  });
}
