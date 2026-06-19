import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:socks5_proxy/socks_client.dart' as socks;

import 'network_proxy_config.dart';

/// Builds the shared [Dio] used by every LLM protocol adapter.
///
/// Mechanical plumbing only (connect / receive timeouts; a swappable
/// [Dio.httpClientAdapter] so tests can feed recorded bytes without a network).
/// Provider-specific auth headers, request bodies and endpoints live in the
/// adapters, never here — this layer carries no protocol semantics
/// (ADR-0004 / ADR-0006).
Dio buildLlmDio({NetworkProxyConfig? proxy}) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      // Streamed completions can run for minutes; keep the socket open.
      receiveTimeout: const Duration(minutes: 5),
      headers: const {Headers.contentTypeHeader: Headers.jsonContentType},
    ),
  );
  configureDioProxy(dio, proxy);
  return dio;
}

/// Applies [proxy] to a Dio instance that uses Dart IO's [HttpClient].
///
/// This function carries only transport concerns: HTTP proxy auth, SOCKS5
/// socket creation and bypass rules. Higher layers decide which proxy value to
/// pass in.
void configureDioProxy(Dio dio, NetworkProxyConfig? proxy) {
  if (proxy?.isValid != true) return;
  final config = proxy!;

  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      if (config.type == NetworkProxyType.socks5) {
        _configureSocks5Proxy(client, config);
      } else {
        client.findProxy = (uri) => config.shouldBypass(uri.host)
            ? 'DIRECT'
            : 'PROXY ${config.host}:${config.port}';
        final username = config.username?.trim();
        if (username != null && username.isNotEmpty) {
          client.addProxyCredentials(
            config.host,
            config.port,
            '',
            HttpClientBasicCredentials(username, config.password ?? ''),
          );
        }
      }
      return client;
    },
  );
}

void _configureSocks5Proxy(HttpClient client, NetworkProxyConfig proxy) {
  Future<InternetAddress?>? proxyAddressFuture;

  client.connectionFactory = (uri, proxyHost, proxyPort) async {
    if (proxy.shouldBypass(uri.host)) {
      return _directConnection(uri, null);
    }

    proxyAddressFuture ??= _resolveProxyAddress(proxy.host);
    final proxyAddress = await proxyAddressFuture;
    if (proxyAddress == null) {
      return _directConnection(uri, null);
    }

    final proxies = <socks.ProxySettings>[
      socks.ProxySettings(
        proxyAddress,
        proxy.port,
        username: proxy.username,
        password: proxy.password,
      ),
    ];
    final socket = socks.SocksTCPClient.connect(
      proxies,
      InternetAddress(uri.host, type: InternetAddressType.unix),
      uri.port,
    );
    if (uri.scheme == 'https') {
      final Future<SecureSocket> secureSocket;
      return ConnectionTask.fromSocket(
        secureSocket = (await socket).secure(uri.host),
        () async => (await secureSocket).close(),
      );
    }
    return ConnectionTask.fromSocket(
      socket,
      () async => (await socket).close(),
    );
  };
}

Future<InternetAddress?> _resolveProxyAddress(String host) async {
  final parsed = InternetAddress.tryParse(host);
  if (parsed != null) return parsed;
  try {
    final addresses = await InternetAddress.lookup(host);
    return addresses.isEmpty ? null : addresses.first;
  } on SocketException {
    return null;
  }
}

ConnectionTask<Socket> _directConnection(Uri uri, SecurityContext? context) {
  if (uri.scheme == 'https') {
    final socket = SecureSocket.connect(uri.host, uri.port, context: context);
    return ConnectionTask.fromSocket(
      socket,
      () async => (await socket).close(),
    );
  }
  final socket = Socket.connect(uri.host, uri.port);
  return ConnectionTask.fromSocket(socket, () async => (await socket).close());
}
