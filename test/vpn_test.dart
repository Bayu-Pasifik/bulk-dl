import 'package:bulk_dl/net/vpn.dart';
import 'package:flutter_test/flutter_test.dart';

const _key = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';

String conf({String? priv, String? pub, String? ep, String? addr}) =>
    '''
[Interface]
PrivateKey = ${priv ?? _key}
${addr ?? 'Address = 10.0.0.2/32'}
DNS = 1.1.1.1 # comment

[Peer]
PublicKey = ${pub ?? _key}
AllowedIPs = 0.0.0.0/0
${ep ?? 'Endpoint = vpn.example:51820'}
''';

void main() {
  test('accepts a complete config', () {
    final c = checkWgConfig(conf());
    expect(c.ok, isTrue);
    expect(c.endpoint, 'vpn.example:51820');
    expect(c.address, '10.0.0.2/32');
  });

  test('reports missing or bad parts', () {
    expect(checkWgConfig('').error, 'empty');
    expect(checkWgConfig(conf(priv: 'short')).error, 'invalid PrivateKey');
    expect(checkWgConfig(conf(pub: 'short')).error, 'invalid peer PublicKey');
    expect(checkWgConfig(conf(ep: '')).error, 'missing peer Endpoint');
    expect(checkWgConfig(conf(addr: '')).error, 'missing Address');
    expect(
      checkWgConfig('[Interface]\nPrivateKey = $_key').error,
      'missing [Peer]',
    );
    expect(checkWgConfig('garbage').error, startsWith('bad line'));
  });
}
