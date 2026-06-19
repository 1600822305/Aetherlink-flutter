import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/core/network/network_proxy_config.dart';
import 'package:aetherlink_flutter/shared/domain/network_proxy_settings.dart';

void main() {
  group('NetworkProxySettings', () {
    test('round-trips persisted JSON and builds a validated config', () {
      final settings = NetworkProxySettings.fromJson({
        'enabled': true,
        'type': 'socks5',
        'host': '  proxy.example.com  ',
        'port': '1080',
        'username': ' user ',
        'password': 'secret',
        'bypassRules': 'localhost,*.internal',
      });

      expect(settings.type, NetworkProxyType.socks5);
      expect(settings.toJson()['type'], 'socks5');

      final config = settings.toConfig();
      expect(config, isNotNull);
      expect(config!.host, 'proxy.example.com');
      expect(config.port, 1080);
      expect(config.username, 'user');
      expect(config.password, 'secret');
      expect(config.shouldBypass('api.internal'), isTrue);
    });

    test('returns null config when disabled or invalid', () {
      expect(const NetworkProxySettings().toConfig(), isNull);
      expect(
        const NetworkProxySettings(
          enabled: true,
          host: '127.0.0.1',
          port: 'not-a-port',
        ).toConfig(),
        isNull,
      );
    });
  });

  group('shouldBypassNetworkProxy', () {
    test('matches localhost, wildcard suffixes and IPv4 CIDR ranges', () {
      const rules = 'localhost,*.example.test,10.0.0.0/8,192.168.1.10';

      expect(shouldBypassNetworkProxy('localhost', rules), isTrue);
      expect(shouldBypassNetworkProxy('api.example.test', rules), isTrue);
      expect(shouldBypassNetworkProxy('10.20.30.40', rules), isTrue);
      expect(shouldBypassNetworkProxy('192.168.1.10', rules), isTrue);
      expect(shouldBypassNetworkProxy('192.168.1.11', rules), isFalse);
    });
  });
}
