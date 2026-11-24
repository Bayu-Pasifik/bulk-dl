import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'proxy.dart';

enum DnsMode { system, cloudflare, google, dnssb, custom }

extension DnsModeInfo on DnsMode {
  String get label => switch (this) {
    DnsMode.system => 'System',
    DnsMode.cloudflare => 'Cloudflare (1.1.1.1)',
    DnsMode.google => 'Google (8.8.8.8)',
    DnsMode.dnssb => 'DNS.SB (185.222.222.222)',
    DnsMode.custom => 'Custom DoH URL',
  };

  /// JSON DoH endpoint reached by IP, so it never needs system DNS.
  String? get endpoint => switch (this) {
    DnsMode.cloudflare => 'https://1.1.1.1/dns-query',
    DnsMode.google => 'https://8.8.8.8/resolve',
    DnsMode.dnssb => 'https://185.222.222.222/dns-query',
    _ => null,
  };
}

/// Addresses ISPs return for blocked sites (sinkholes / block pages).
/// [allowPrivate]: LAN addresses are fine (user-run custom DoH, local tests).
bool isBlockedIp(String ip, {bool allowPrivate = false}) {
  const known = {
    '36.86.63.185',
    '36.86.63.182',
    '180.131.144.144',
    '180.131.145.145',
  };
  if (known.contains(ip)) return true;
  final a = InternetAddress.tryParse(ip);
  if (a == null) return true;
  if (a.type == InternetAddressType.IPv6) {
    return a.isLoopback || a.isLinkLocal || ip == '::';
  }
  final p = ip.split('.').map(int.parse).toList();
  if (p[0] == 0 || p[0] == 127) return true; // unspecified / loopback
  if (allowPrivate) return false;
  if (p[0] == 10) return true;
  if (p[0] == 172 && p[1] >= 16 && p[1] <= 31) return true;
  if (p[0] == 192 && p[1] == 168) return true;
  if (p[0] == 169 && p[1] == 254) return true;
  return false;
}

/// Parses a DoH JSON answer ([Type] 1 = A, 28 = AAAA). Returns (ips, ttl).
(List<String>, int) parseDohAnswer(Map<String, dynamic> json) {
  final ans = json['Answer'];
  final ips = <String>[];
  var ttl = 300;
  if (ans is List) {
    for (final a in ans) {
      if (a is Map && (a['type'] == 1 || a['type'] == 28)) {
        final d = a['data'];
        if (d is String && InternetAddress.tryParse(d) != null) {
          ips.add(d);
          final t = a['TTL'];
          if (t is int && t < ttl) ttl = t;
        }
      }
    }
  }
  return (ips, ttl);
}

typedef SystemLookup = Future<List<String>> Function(String host);

Future<List<String>> _systemLookup(String host) async => [
  for (final a in await InternetAddress.lookup(host)) a.address,
];

/// Resolves host names with the chosen DNS strategy and caches the result.
///
/// Order: the selected DoH provider, then the other providers, then the
/// system resolver (or system first when [mode] is [DnsMode.system]).
/// Answers that look like ISP block pages are skipped.
class DnsResolver {
  DnsResolver({Dio? doh, SystemLookup? system, DateTime Function()? now})
    : _doh = doh ?? _defaultDoh(),
      _system = system ?? _systemLookup,
      _now = now ?? DateTime.now;

  static final DnsResolver instance = DnsResolver();

  static Dio _defaultDoh() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {'accept': 'application/dns-json'},
    ),
  );

  final Dio _doh;
  final SystemLookup _system;
  final DateTime Function() _now;

  DnsMode mode = DnsMode.cloudflare;
  String custom = '';

  /// Provider that answered the last lookup (for the "test" button).
  String? lastProvider;

  final Map<String, (DateTime, List<String>)> _cache = {};
  void clearCache() => _cache.clear();

  String? _endpointFor(DnsMode m) {
    if (m == DnsMode.custom) {
      final c = custom.trim();
      return c.startsWith('http') ? c : null;
    }
    return m.endpoint;
  }

  Future<(List<String>, int)?> _viaDoh(
    String endpoint,
    String host, {
    bool allowPrivate = false,
  }) async {
    for (final type in const ['A', 'AAAA']) {
      try {
        final r = await _doh.get<String>(
          endpoint,
          queryParameters: {'name': host, 'type': type},
          options: Options(
            // application/dns-json is not decoded by Dio: parse it here.
            responseType: ResponseType.plain,
            headers: {'accept': 'application/dns-json'},
          ),
        );
        final (ips, ttl) = parseDohAnswer(
          jsonDecode(r.data ?? '{}') as Map<String, dynamic>,
        );
        final ok = ips
            .where((i) => !isBlockedIp(i, allowPrivate: allowPrivate))
            .toList();
        if (ok.isNotEmpty) return (ok, ttl);
      } catch (_) {}
    }
    return null;
  }

  Future<List<String>> resolve(String host) async {
    if (InternetAddress.tryParse(host) != null) return [host];
    final hit = _cache[host];
    if (hit != null && _now().isBefore(hit.$1)) return hit.$2;

    final steps = <(String, Future<(List<String>, int)?> Function())>[];
    void addDoh(DnsMode m) {
      final e = _endpointFor(m);
      if (e != null) {
        steps.add((
          m.label,
          () => _viaDoh(e, host, allowPrivate: m == DnsMode.custom),
        ));
      }
    }

    void addSystem() => steps.add((
      DnsMode.system.label,
      () async {
        try {
          final ok = (await _system(host))
              .where((i) => !isBlockedIp(i))
              .toList();
          return ok.isEmpty ? null : (ok, 60);
        } catch (_) {
          return null;
        }
      },
    ));

    if (mode == DnsMode.system) addSystem();
    if (mode != DnsMode.system) addDoh(mode);
    for (final m in const [DnsMode.cloudflare, DnsMode.google, DnsMode.dnssb]) {
      if (m != mode) addDoh(m);
    }
    if (mode != DnsMode.system) addSystem();

    for (final (name, run) in steps) {
      final r = await run();
      if (r != null) {
        lastProvider = name;
        _cache[host] = (
          _now().add(Duration(seconds: r.$2.clamp(30, 600))),
          r.$1,
        );
        return r.$1;
      }
    }
    throw SocketException('Failed host lookup: \'$host\'');
  }

  /// Connection factory for [HttpClient]: resolves via [resolve], keeps the
  /// original host name for TLS (SNI and certificate validation).
  Future<ConnectionTask<Socket>> connect(
    Uri uri,
    String? proxyHost,
    int? proxyPort,
  ) {
    final px = ProxySettings.instance.config;
    if (proxyHost == null && px.usable && px.type == ProxyType.socks5) {
      return _connectSocks(uri, px);
    }
    final viaProxy = proxyHost != null;
    final host = viaProxy ? proxyHost : uri.host;
    final port = viaProxy ? (proxyPort ?? 80) : uri.port;
    final tls = !viaProxy && uri.scheme == 'https';

    Future<Socket> open() async {
      final ips = await resolve(host);
      Object? last;
      for (final ip in ips) {
        try {
          final raw = await Socket.connect(
            ip,
            port,
            timeout: const Duration(seconds: 10),
          );
          if (!tls) return raw;
          return await SecureSocket.secure(raw, host: host);
        } catch (e) {
          last = e;
        }
      }
      throw last ?? SocketException('Failed host lookup: \'$host\'');
    }

    return Future.value(ConnectionTask.fromSocket(open(), () {}));
  }

  Future<ConnectionTask<Socket>> _connectSocks(Uri uri, ProxyConfig px) {
    Future<Socket> open() async {
      final ips = await resolve(px.host);
      Object? last;
      for (final ip in ips) {
        try {
          final raw = await socks5Connect(px, ip, uri.host, uri.port);
          if (uri.scheme != 'https') return raw;
          return await SecureSocket.secure(raw, host: uri.host);
        } catch (e) {
          last = e;
        }
      }
      throw last ?? SocketException("Failed host lookup: '${px.host}'");
    }

    return Future.value(ConnectionTask.fromSocket(open(), () {}));
  }

  /// Plugs this resolver into [dio].
  void attach(Dio dio) {
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final c = HttpClient()
          ..connectionFactory = connect
          ..findProxy = ProxySettings.instance.findProxy;
        c.authenticateProxy = (host, port, scheme, realm) async {
          final p = ProxySettings.instance.config;
          if (!p.hasAuth) return false;
          c.addProxyCredentials(
            host,
            port,
            realm ?? '',
            HttpClientBasicCredentials(p.user, p.pass),
          );
          return true;
        };
        return c;
      },
    );
  }
}
