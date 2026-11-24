import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

enum ProxyType { http, socks5 }

/// User-chosen HTTP / SOCKS5 proxy used for every request.
class ProxyConfig {
  const ProxyConfig({
    this.enabled = false,
    this.type = ProxyType.http,
    this.host = '',
    this.port = 0,
    this.user = '',
    this.pass = '',
  });

  final bool enabled;
  final ProxyType type;
  final String host;
  final int port;
  final String user;
  final String pass;

  bool get usable =>
      enabled && host.trim().isNotEmpty && port > 0 && port < 65536;
  bool get hasAuth => user.isNotEmpty;

  ProxyConfig copyWith({
    bool? enabled,
    ProxyType? type,
    String? host,
    int? port,
    String? user,
    String? pass,
  }) => ProxyConfig(
    enabled: enabled ?? this.enabled,
    type: type ?? this.type,
    host: host ?? this.host,
    port: port ?? this.port,
    user: user ?? this.user,
    pass: pass ?? this.pass,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'type': type.name,
    'host': host,
    'port': port,
    'user': user,
    'pass': pass,
  };

  factory ProxyConfig.fromJson(Map<String, dynamic> j) => ProxyConfig(
    enabled: j['enabled'] == true,
    type: ProxyType.values.firstWhere(
      (t) => t.name == j['type'],
      orElse: () => ProxyType.http,
    ),
    host: (j['host'] as String?) ?? '',
    port: (j['port'] as num?)?.toInt() ?? 0,
    user: (j['user'] as String?) ?? '',
    pass: (j['pass'] as String?) ?? '',
  );

  /// Parses `[scheme://][user:pass@]host:port` (scheme http/https/socks5/socks5h).
  static ProxyConfig? parse(String input) {
    var s = input.trim();
    if (s.isEmpty) return null;
    var type = ProxyType.http;
    final m = RegExp(r'^([a-zA-Z0-9]+)://').firstMatch(s);
    if (m != null) {
      final scheme = m.group(1)!.toLowerCase();
      if (scheme.startsWith('socks')) {
        type = ProxyType.socks5;
      } else if (scheme != 'http' && scheme != 'https') {
        return null;
      }
      s = s.substring(m.end);
    }
    final u = Uri.tryParse('x://$s');
    if (u == null || u.host.isEmpty || !u.hasPort) return null;
    final ui = u.userInfo.split(':');
    return ProxyConfig(
      enabled: true,
      type: type,
      host: u.host,
      port: u.port,
      user: Uri.decodeComponent(ui.first),
      pass: ui.length > 1 ? Uri.decodeComponent(ui.sublist(1).join(':')) : '',
    );
  }
}

/// Process-wide proxy state read by every connection (so changes apply live).
class ProxySettings {
  ProxySettings._();
  static final ProxySettings instance = ProxySettings._();

  ProxyConfig config = const ProxyConfig();

  /// `findProxy` result for [HttpClient]: only HTTP proxies use the native
  /// mechanism; SOCKS5 is handled inside the connection factory.
  String findProxy(Uri uri) {
    final c = config;
    if (c.usable && c.type == ProxyType.http) {
      return 'PROXY ${c.host}:${c.port}';
    }
    return 'DIRECT';
  }
}

class SocksException implements Exception {
  SocksException(this.message);
  final String message;
  @override
  String toString() => 'SOCKS5: $message';
}

/// Buffered reader over a socket used during the SOCKS5 handshake. It owns the
/// single subscription to the socket; [relay] hands the rest of the stream on.
class _Reader {
  _Reader(Socket s) {
    _sub = s.listen(
      (d) {
        if (_sink != null) {
          _sink!.add(d);
        } else {
          _buf.addAll(d);
          _wake();
        }
      },
      onError: (Object e) {
        _error = e;
        _wake();
      },
      onDone: () {
        _done = true;
        _sinkDone?.call();
        _wake();
      },
    );
  }

  late final StreamSubscription<Uint8List> _sub;
  final List<int> _buf = [];
  Completer<void>? _waiter;
  Object? _error;
  bool _done = false;
  Socket? _sink;
  void Function()? _sinkDone;

  void _wake() {
    final w = _waiter;
    _waiter = null;
    if (w != null && !w.isCompleted) w.complete();
  }

  Future<Uint8List> read(int n) async {
    while (_buf.length < n) {
      if (_error != null) throw _error!;
      if (_done) throw SocksException('connection closed during handshake');
      _waiter = Completer<void>();
      await _waiter!.future.timeout(const Duration(seconds: 10));
    }
    final out = Uint8List.fromList(_buf.sublist(0, n));
    _buf.removeRange(0, n);
    return out;
  }

  /// Forwards everything still arriving (and any buffered bytes) to [sink].
  void relay(Socket sink, void Function() onDone) {
    _sink = sink;
    _sinkDone = onDone;
    if (_buf.isNotEmpty) {
      sink.add(List<int>.of(_buf));
      _buf.clear();
    }
    if (_done) onDone();
  }

  Future<void> cancel() => _sub.cancel();
}

/// Opens a tunnel to [host]:[port] through the SOCKS5 proxy [c] and returns a
/// plain loopback [Socket] wired to it. The target name is sent to the proxy
/// (remote DNS), so local DNS blocks do not apply. The loopback hop keeps the
/// result a real dart:io socket, which `SecureSocket.secure` requires.
Future<Socket> socks5Connect(
  ProxyConfig c,
  String proxyIp,
  String host,
  int port,
) async {
  final sock = await Socket.connect(
    proxyIp,
    c.port,
    timeout: const Duration(seconds: 10),
  );
  final r = _Reader(sock);
  try {
    final methods = c.hasAuth ? [0x00, 0x02] : [0x00];
    sock.add([0x05, methods.length, ...methods]);
    final choice = await r.read(2);
    if (choice[0] != 0x05) throw SocksException('bad proxy reply');
    if (choice[1] == 0x02) {
      if (!c.hasAuth) throw SocksException('proxy requires credentials');
      final u = utf8.encode(c.user), p = utf8.encode(c.pass);
      sock.add([0x01, u.length, ...u, p.length, ...p]);
      final a = await r.read(2);
      if (a[1] != 0x00) throw SocksException('authentication failed');
    } else if (choice[1] != 0x00) {
      throw SocksException('no acceptable auth method');
    }
    final name = utf8.encode(host);
    if (name.length > 255) throw SocksException('host name too long');
    sock.add([
      0x05,
      0x01,
      0x00,
      0x03,
      name.length,
      ...name,
      (port >> 8) & 0xff,
      port & 0xff,
    ]);
    final h = await r.read(4);
    if (h[1] != 0x00) throw SocksException(_replyText(h[1]));
    final skip = switch (h[3]) {
      0x01 => 6,
      0x04 => 18,
      0x03 => (await r.read(1))[0] + 2,
      _ => throw SocksException('bad address type'),
    };
    await r.read(skip);

    // Loopback relay: app <-> 127.0.0.1 <-> SOCKS tunnel.
    final srv = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final clientFuture = Socket.connect(InternetAddress.loopbackIPv4, srv.port);
    final inbound = await srv.first;
    await srv.close();
    final client = await clientFuture;
    r.relay(inbound, () => inbound.close());
    inbound.listen(
      sock.add,
      onDone: () => sock.close(),
      onError: (_) => sock.destroy(),
      cancelOnError: true,
    );
    unawaited(sock.done.catchError((_) {}).whenComplete(inbound.destroy));
    return client;
  } catch (_) {
    unawaited(r.cancel());
    sock.destroy();
    rethrow;
  }
}

String _replyText(int code) => switch (code) {
  1 => 'general failure',
  2 => 'not allowed by ruleset',
  3 => 'network unreachable',
  4 => 'host unreachable',
  5 => 'connection refused',
  6 => 'TTL expired',
  7 => 'command not supported',
  8 => 'address type not supported',
  _ => 'error $code',
};
