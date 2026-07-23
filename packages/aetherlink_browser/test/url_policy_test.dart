import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_browser/aetherlink_browser.dart';

void main() {
  UrlPolicy policyResolving(Map<String, String> hosts) => UrlPolicy(
    resolver: (host) async {
      final ip = hosts[host];
      if (ip == null) throw const SocketException('no address');
      return [InternetAddress(ip)];
    },
  );

  group('协议白名单', () {
    final policy = policyResolving({'example.com': '93.184.216.34'});

    test('http/https 放行', () async {
      final uri = await policy.validate('https://example.com/page');
      expect(uri.host, 'example.com');
      await policy.validate('http://example.com');
    });

    test('危险协议拒绝', () async {
      for (final url in [
        'file:///etc/passwd',
        'data:text/html,<script>1</script>',
        'ftp://example.com/x',
        'gopher://example.com',
        'content://com.android.providers/x',
        'javascript:alert(1)',
      ]) {
        await expectLater(
          policy.validate(url),
          throwsA(
            isA<BrowserException>().having(
              (e) => e.kind,
              'kind',
              BrowserErrorKind.blockedUrl,
            ),
          ),
          reason: url,
        );
      }
    });

    test('无效/相对 URL 拒绝', () async {
      for (final url in ['', 'not a url', '/relative/path', 'example.com']) {
        await expectLater(
          policy.validate(url),
          throwsA(isA<BrowserException>()),
          reason: url,
        );
      }
    });
  });

  group('IP 段校验（DNS 解析后）', () {
    test('公网 IP 放行', () async {
      final policy = policyResolving({'ok.com': '93.184.216.34'});
      await policy.validate('https://ok.com');
    });

    test('外部域名解析到内网 IP 拒绝（DNS 指内网）', () async {
      for (final ip in [
        '127.0.0.1',
        '10.1.2.3',
        '172.16.0.1',
        '172.31.255.255',
        '192.168.1.1',
        '169.254.169.254',
        '0.0.0.0',
        '100.64.0.1',
        '198.18.0.1',
        '255.255.255.255',
      ]) {
        final policy = policyResolving({'evil.com': ip});
        await expectLater(
          policy.validate('https://evil.com/steal'),
          throwsA(
            isA<BrowserException>().having(
              (e) => e.kind,
              'kind',
              BrowserErrorKind.blockedUrl,
            ),
          ),
          reason: ip,
        );
      }
    });

    test('IP 字面量直接校验（不查 DNS）', () async {
      final policy = UrlPolicy(resolver: (_) async => fail('不应查 DNS'));
      await expectLater(
        policy.validate('http://127.0.0.1:8080/admin'),
        throwsA(isA<BrowserException>()),
      );
      await expectLater(
        policy.validate('http://[::1]/'),
        throwsA(isA<BrowserException>()),
      );
      await expectLater(
        policy.validate('http://[fc00::1]/'),
        throwsA(isA<BrowserException>()),
      );
      // IPv4 映射 IPv6 绕过尝试。
      await expectLater(
        policy.validate('http://[::ffff:127.0.0.1]/'),
        throwsA(isA<BrowserException>()),
      );
      // 公网 IP 字面量放行。
      final uri = await policy.validate('http://93.184.216.34/');
      expect(uri.host, '93.184.216.34');
    });

    test('DNS 失败归类为 network 错误', () async {
      final policy = policyResolving({});
      await expectLater(
        policy.validate('https://nonexistent.example'),
        throwsA(
          isA<BrowserException>().having(
            (e) => e.kind,
            'kind',
            BrowserErrorKind.network,
          ),
        ),
      );
    });

    test('多地址时任一命中禁止段即拒绝', () async {
      final policy = UrlPolicy(
        resolver: (_) async => [
          InternetAddress('93.184.216.34'),
          InternetAddress('192.168.0.10'),
        ],
      );
      await expectLater(
        policy.validate('https://rebind.example'),
        throwsA(isA<BrowserException>()),
      );
    });
  });

  group('DNS 结果短 TTL 缓存（收窄 rebinding 窗口）', () {
    test('TTL 内重复校验同一 host 不重新解析', () async {
      var lookups = 0;
      final policy = UrlPolicy(
        resolver: (_) async {
          lookups++;
          return [InternetAddress('93.184.216.34')];
        },
      );
      await policy.validate('https://a.com/1');
      await policy.validate('https://a.com/2');
      await policy.validate('https://a.com/3');
      expect(lookups, 1);
    });

    test('TTL 过期后重新解析', () async {
      var lookups = 0;
      final policy = UrlPolicy(
        dnsCacheTtl: Duration.zero,
        resolver: (_) async {
          lookups++;
          return [InternetAddress('93.184.216.34')];
        },
      );
      await policy.validate('https://a.com/1');
      await policy.validate('https://a.com/2');
      expect(lookups, 2);
    });

    test('TTL 内 rebinding 到内网的第二次解析不生效（仍用缓存结果放行决策）', () async {
      var lookups = 0;
      final policy = UrlPolicy(
        resolver: (_) async {
          lookups++;
          return [
            InternetAddress(lookups == 1 ? '93.184.216.34' : '192.168.0.10'),
          ];
        },
      );
      await policy.validate('https://rebind.example/');
      // 逐跳复检复用缓存，不给恶意 DNS 第二次机会。
      await policy.validate('https://rebind.example/next');
      expect(lookups, 1);
    });
  });

  group('isForbiddenAddress', () {
    test('IPv6 特殊段', () {
      expect(isForbiddenAddress(InternetAddress('::1')), isTrue);
      expect(isForbiddenAddress(InternetAddress('::')), isTrue);
      expect(isForbiddenAddress(InternetAddress('fe80::1')), isTrue);
      expect(isForbiddenAddress(InternetAddress('fc00::1')), isTrue);
      expect(isForbiddenAddress(InternetAddress('fd12:3456::1')), isTrue);
      expect(
        isForbiddenAddress(InternetAddress('2606:2800:220:1::1')),
        isFalse,
      );
    });
  });
}
