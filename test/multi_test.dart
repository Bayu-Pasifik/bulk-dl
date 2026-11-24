import 'dart:io';
import 'dart:typed_data';

import 'package:bulk_dl/net/multi.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ranged download reassembles file', () async {
    final data = Uint8List.fromList(
      List.generate(5 * 1048576 + 123, (i) => (i * 7) & 255),
    );
    final srv = await HttpServer.bind('127.0.0.1', 0);
    srv.listen((req) async {
      final m = RegExp(r'bytes=(\d+)-(\d+)')
          .firstMatch(req.headers.value('range') ?? '')!;
      final a = int.parse(m[1]!), b = int.parse(m[2]!);
      req.response.statusCode = 206;
      req.response.add(data.sublist(a, b + 1));
      await req.response.close();
    });
    final f = File('${Directory.systemTemp.path}/multi_test.bin');
    await downloadRanged(
      Dio(),
      'http://127.0.0.1:${srv.port}/x',
      f,
      data.length,
    );
    expect(await f.readAsBytes(), data);
    await srv.close(force: true);
    await f.delete();
  });
}
