import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bulk_dl/net/dns.dart';
import 'package:bulk_dl/net/proxy.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal SOCKS5 server: connects every requested name to 127.0.0.1 and
/// records the name it was asked for.
Future<(ServerSocket, List<String>)> socksServer({
  String? user,
  String? pass,
}) async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final requested = <String>[];
  server.listen((c) {
    final buf = <int>[];
    var upstream = false;
    Socket? remote;
    var step = 0;

    void process() {
      while (true) {
        if (upstream) {
          remote!.add(List<int>.of(buf));
          buf.clear();
          return;
        }
        if (step == 0 && buf.length >= 2 && buf.length >= 2 + buf[1]) {
          final n = buf[1];
          final methods = buf.sublist(2, 2 + n);
          buf.removeRange(0, 2 + n);
          if (user != null && methods.contains(2)) {
            c.add([5, 2]);
            step = 1;
          } else if (user == null && methods.contains(0)) {
            c.add([5, 0]);
            step = 2;
          } else {
            c.add([5, 0xff]);
            c.close();
            return;
          }
        } else if (step == 1 &&
            buf.length >= 2 &&
            buf.length >= 3 + buf[1] + buf[2 + buf[1]]) {
          final ul = buf[1];
          final u = utf8.decode(buf.sublist(2, 2 + ul));
          final pl = buf[2 + ul];
          final p = utf8.decode(buf.sublist(3 + ul, 3 + ul + pl));
          buf.removeRange(0, 3 + ul + pl);
          if (u == user && p == pass) {
            c.add([1, 0]);
            step = 2;
          } else {
            c.add([1, 1]);
            c.close();
            return;
          }
        } else if (step == 2 && buf.length >= 5 && buf.length >= 7 + buf[4]) {
          final n = buf[4];
          final name = utf8.decode(buf.sublist(5, 5 + n));
          final port = (buf[5 + n] << 8) | buf[6 + n];
          buf.removeRange(0, 7 + n);
          requested.add('$name:$port');
          step = 3;
          Socket.connect(InternetAddress.loopbackIPv4, port).then(
            (s) {
              remote = s;
              c.add([5, 0, 0, 1, 0, 0, 0, 0, 0, 0]);
              s.listen(c.add, onDone: c.close);
              upstream = true;
              process();
            },
            onError: (_) {
              c.add([5, 5, 0, 1, 0, 0, 0, 0, 0, 0]);
              c.close();
            },
          );
          return;
        } else {
          return;
        }
      }
    }

    c.listen((d) {
      buf.addAll(d);
      process();
    }, onDone: () => remote?.destroy());
  });
  return (server, requested);
}

Future<HttpServer> origin() async {
  final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  s.listen((r) {
    r.response
      ..write('hello ${r.headers.host}')
      ..close();
  });
  return s;
}

Dio client() {
  final d = Dio(BaseOptions(responseType: ResponseType.plain));
  DnsResolver().attach(d);
  return d;
}

void main() {
  tearDown(() => ProxySettings.instance.config = const ProxyConfig());

  group('ProxyConfig.parse', () {
    test('host:port defaults to http', () {
      final c = ProxyConfig.parse('10.0.0.1:8080')!;
      expect((c.type, c.host, c.port), (ProxyType.http, '10.0.0.1', 8080));
    });
    test('socks5 with credentials', () {
      final c = ProxyConfig.parse('socks5://me:p%40ss@h.example:1080')!;
      expect(c.type, ProxyType.socks5);
      expect((c.user, c.pass, c.port), ('me', 'p@ss', 1080));
    });
    test('rejects junk', () {
      expect(ProxyConfig.parse(''), isNull);
      expect(ProxyConfig.parse('ftp://h:1'), isNull);
      expect(ProxyConfig.parse('nohostport'), isNull);
    });
    test('json round trip', () {
      final c = ProxyConfig.parse('socks5://a:b@h:1')!;
      expect(ProxyConfig.fromJson(c.toJson()).toJson(), c.toJson());
    });
  });

  group('SOCKS5', () {
    test('tunnels and sends the host name to the proxy', () async {
      final (px, seen) = await socksServer();
      final o = await origin();
      ProxySettings.instance.config = ProxyConfig(
        enabled: true,
        type: ProxyType.socks5,
        host: '127.0.0.1',
        port: px.port,
      );
      final r = await client().get<String>(
        'http://blocked.example:${o.port}/x',
      );
      expect(r.data, startsWith('hello blocked.example'));
      expect(seen, ['blocked.example:${o.port}']);
      await px.close();
      await o.close(force: true);
    });

    test('username/password auth', () async {
      final (px, _) = await socksServer(user: 'u', pass: 'p');
      final o = await origin();
      final cfg = ProxyConfig(
        enabled: true,
        type: ProxyType.socks5,
        host: '127.0.0.1',
        port: px.port,
        user: 'u',
        pass: 'p',
      );
      ProxySettings.instance.config = cfg;
      final ok = await client().get<String>('http://127.0.0.1:${o.port}/');
      expect(ok.data, contains('hello'));
      ProxySettings.instance.config = cfg.copyWith(pass: 'wrong');
      await expectLater(
        client().get<String>('http://127.0.0.1:${o.port}/'),
        throwsA(anything),
      );
      await px.close();
      await o.close(force: true);
    });

    test('proxy refusing the target surfaces an error', () async {
      final (px, _) = await socksServer();
      ProxySettings.instance.config = ProxyConfig(
        enabled: true,
        type: ProxyType.socks5,
        host: '127.0.0.1',
        port: px.port,
      );
      await expectLater(
        client().get<String>('http://x.example:1/'),
        throwsA(anything),
      );
      await px.close();
    });
  });

  group('HTTP proxy', () {
    test('requests go to the proxy with credentials', () async {
      final seen = <String>[];
      final px = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      px.listen((r) {
        seen.add('${r.method} ${r.requestedUri}');
        final auth = r.headers.value('proxy-authorization');
        if (auth == null) {
          r.response
            ..statusCode = 407
            ..headers.set('proxy-authenticate', 'Basic realm="t"')
            ..close();
          return;
        }
        seen.add('auth $auth');
        r.response
          ..write('via proxy')
          ..close();
      });
      ProxySettings.instance.config = ProxyConfig(
        enabled: true,
        host: '127.0.0.1',
        port: px.port,
        user: 'u',
        pass: 'p',
      );
      final r = await client().get<String>('http://site.example/page');
      expect(r.data, 'via proxy');
      expect(seen.any((s) => s.contains('site.example/page')), isTrue);
      final want = base64.encode(utf8.encode('u:p'));
      expect(seen, contains('auth Basic $want'));
      await px.close(force: true);
    });
  });

  test('disabled proxy goes direct', () async {
    final o = await origin();
    ProxySettings.instance.config = const ProxyConfig(
      enabled: false,
      host: '127.0.0.1',
      port: 9,
    );
    final r = await client().get<String>('http://127.0.0.1:${o.port}/');
    expect(r.data, contains('hello'));
    await o.close(force: true);
  });
}
