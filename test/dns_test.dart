import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bulk_dl/net/dns.dart';
import 'package:bulk_dl/net/errors.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake DoH servers keyed by endpoint host; null body = connection failure.
class DohAdapter implements HttpClientAdapter {
  DohAdapter(this.answers);
  final Map<String, Map<String, dynamic>?> answers;
  final List<Uri> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    requests.add(o.uri);
    final a = answers[o.uri.host];
    if (a == null) {
      throw DioException.connectionError(requestOptions: o, reason: 'down');
    }
    // Only A queries answer; AAAA gets an empty answer.
    final isA = o.uri.queryParameters['type'] == 'A';
    return ResponseBody.fromString(
      jsonEncode(isA ? a : <String, dynamic>{'Status': 0}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/dns-json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> answer(String ip, {int ttl = 120}) => {
  'Status': 0,
  'Answer': [
    {'name': 'x.test', 'type': 1, 'TTL': ttl, 'data': ip},
  ],
};

void main() {
  test('parseDohAnswer keeps A/AAAA data and min ttl', () {
    final (ips, ttl) = parseDohAnswer({
      'Answer': [
        {'type': 5, 'TTL': 10, 'data': 'cname.test.'},
        {'type': 1, 'TTL': 200, 'data': '93.184.216.34'},
        {'type': 28, 'TTL': 60, 'data': '2606:2800:220:1::1'},
      ],
    });
    expect(ips, ['93.184.216.34', '2606:2800:220:1::1']);
    expect(ttl, 60);
    expect(parseDohAnswer({'Status': 3}).$1, isEmpty);
  });

  test('isBlockedIp flags sinkholes, private and known block pages', () {
    for (final ip in [
      '127.0.0.1',
      '0.0.0.0',
      '10.1.2.3',
      '192.168.1.1',
      '172.20.0.1',
      '36.86.63.185',
      'garbage',
    ]) {
      expect(isBlockedIp(ip), isTrue, reason: ip);
    }
    expect(isBlockedIp('10.0.2.2', allowPrivate: true), isFalse);
    expect(isBlockedIp('127.0.0.1', allowPrivate: true), isTrue);
    for (final ip in ['93.184.216.34', '1.1.1.1', '172.32.0.1']) {
      expect(isBlockedIp(ip), isFalse, reason: ip);
    }
  });

  group('DnsResolver', () {
    late List<String> systemCalls;
    DnsResolver make(
      Map<String, Map<String, dynamic>?> doh, {
      List<String> Function(String)? system,
      DateTime Function()? now,
    }) {
      systemCalls = [];
      final dio = Dio()..httpClientAdapter = DohAdapter(doh);
      return DnsResolver(
        doh: dio,
        now: now,
        system: (h) async {
          systemCalls.add(h);
          if (system == null) throw const SocketException('no dns');
          return system(h);
        },
      );
    }

    test('ip literal is returned untouched', () async {
      final r = make({});
      expect(await r.resolve('10.0.2.2'), ['10.0.2.2']);
      expect(systemCalls, isEmpty);
    });

    test('selected provider answers first, system not used', () async {
      final r = make({'1.1.1.1': answer('93.184.216.34')})
        ..mode = DnsMode.cloudflare;
      expect(await r.resolve('x.test'), ['93.184.216.34']);
      expect(r.lastProvider, DnsMode.cloudflare.label);
      expect(systemCalls, isEmpty);
    });

    test('falls back to the next provider, then system', () async {
      final r = make({'8.8.8.8': answer('1.2.3.4')})..mode = DnsMode.cloudflare;
      expect(await r.resolve('x.test'), ['1.2.3.4']);
      expect(r.lastProvider, DnsMode.google.label);

      final r2 = make({}, system: (_) => ['5.6.7.8'])..mode = DnsMode.dnssb;
      expect(await r2.resolve('x.test'), ['5.6.7.8']);
      expect(r2.lastProvider, DnsMode.system.label);
    });

    test('system mode: blocked answer falls through to DoH', () async {
      final r = make({
        '1.1.1.1': answer('93.184.216.34'),
      }, system: (_) => ['36.86.63.185'])..mode = DnsMode.system;
      expect(await r.resolve('blocked.test'), ['93.184.216.34']);
      expect(systemCalls, ['blocked.test']);
      expect(r.lastProvider, DnsMode.cloudflare.label);
    });

    test('doh answer that is a block-page ip is skipped', () async {
      final r = make({
        '1.1.1.1': answer('127.0.0.1'),
        '8.8.8.8': answer('9.9.9.1'),
      })..mode = DnsMode.cloudflare;
      expect(await r.resolve('x.test'), ['9.9.9.1']);
    });

    test('all sources failing throws a host lookup error', () async {
      final r = make({});
      expect(() => r.resolve('x.test'), throwsA(isA<SocketException>()));
    });

    test('results are cached until ttl expires', () async {
      var t = DateTime(2026);
      final adapter = DohAdapter({'1.1.1.1': answer('93.184.216.34', ttl: 60)});
      final r = DnsResolver(
        doh: Dio()..httpClientAdapter = adapter,
        now: () => t,
        system: (_) async => throw const SocketException('x'),
      );
      await r.resolve('x.test');
      final first = adapter.requests.length;
      await r.resolve('x.test');
      expect(adapter.requests.length, first); // served from cache
      t = t.add(const Duration(seconds: 61));
      await r.resolve('x.test');
      expect(adapter.requests.length, greaterThan(first)); // expired
    });

    test('custom mode uses the given url', () async {
      final r = make({'dns.example': answer('4.4.4.4')})
        ..mode = DnsMode.custom
        ..custom = 'https://dns.example/dns-query';
      expect(await r.resolve('x.test'), ['4.4.4.4']);
    });
  });

  test('friendlyError maps common failures', () {
    final ro = RequestOptions(path: '/');
    expect(
      friendlyError(
        DioException.connectionError(
          requestOptions: ro,
          reason: 'x',
          error: const SocketException("Failed host lookup: 'a.test'"),
        ),
      ),
      contains('DNS'),
    );
    expect(
      friendlyError(
        DioException.connectionError(
          requestOptions: ro,
          reason: 'x',
          error: const HandshakeException('handshake'),
        ),
      ),
      contains('ISP'),
    );
    expect(friendlyError('plain text'), 'plain text');
  });
}
