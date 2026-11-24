import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Upper bound for the user setting. Each download starts at that setting and halves on
/// HTTP 429/503 (rate limit) so hosts that throttle do not fail the download.
const kMaxConnections = 64;

/// The server did not honour HTTP Range; caller falls back to one stream.
class RangeUnsupported implements Exception {
  @override
  String toString() => 'Server ignores Range';
}

/// Downloads [url] (known [total] bytes) into [out] using up to [connections]
/// parallel Range requests. Chunks are pulled from a shared queue so fast
/// connections pick up more work. Throws [RangeUnsupported] if the server
/// answers anything but 206.
Future<void> downloadRanged(
  Dio dio,
  String url,
  File out,
  int total, {
  CancelToken? token,
  int connections = kMaxConnections,
  void Function(int received)? onProgress,
}) async {
  final chunk = (total / (connections * 2)).ceil().clamp(512 * 1024, 8 << 20);
  final starts = <int>[for (var s = 0; s < total; s += chunk) s];
  var next = 0;
  var received = 0;
  Object? failure;
  var limit = connections; // workers with id >= limit retire

  final raf = await out.open(mode: FileMode.write);
  try {
    await raf.truncate(total);
    // RandomAccessFile allows one pending op: serialise writes.
    var tail = Future<void>.value();
    Future<void> write(int pos, List<int> data) {
      final f = tail.then((_) async {
        await raf.setPosition(pos);
        await raf.writeFrom(data);
      });
      tail = f.catchError((_) {});
      return f;
    }

    Future<void> fetch(int start) async {
      final end = math.min(start + chunk, total) - 1;
      var pos = start;
      for (var attempt = 0;; attempt++) {
        try {
          final r = await dio.get<ResponseBody>(
            url,
            cancelToken: token,
            options: Options(
              responseType: ResponseType.stream,
              headers: {'Range': 'bytes=$pos-$end'},
              validateStatus: (s) => s != null && s < 400 && s != 429 && s != 503,
            ),
          );
          if (r.statusCode != 206) {
            await r.data!.stream.listen((_) {}).cancel();
            throw RangeUnsupported();
          }
          await for (final d in r.data!.stream) {
            await write(pos, d);
            pos += d.length;
            received += d.length;
            onProgress?.call(received);
          }
          if (pos != end + 1) throw const HttpException('Short range');
          return;
        } on RangeUnsupported {
          rethrow;
        } on DioException catch (e) {
          if (CancelToken.isCancel(e)) rethrow;
          final code = e.response?.statusCode;
          if (code == 429 || code == 503) {
            limit = math.max(1, limit ~/ 2); // back off: fewer connections
            debugPrint('MULTI $code -> limit $limit (attempt $attempt)');
            if (attempt >= 8) rethrow;
            await Future<void>.delayed(Duration(seconds: 1 + attempt));
            continue;
          }
          if (attempt >= 3) rethrow;
        } on Object {
          if (attempt >= 3) rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }

    Future<void> worker(int id) async {
      while (failure == null && next < starts.length && id < limit) {
        final s = starts[next++];
        try {
          await fetch(s);
        } on Object catch (e) {
          failure ??= e;
        }
      }
    }

    debugPrint('MULTI start total=$total chunk=$chunk conns=$connections');
    await Future.wait([
      for (var i = 0; i < math.min(connections, starts.length); i++) worker(i),
    ]);
    await tail;
    if (failure != null) throw failure!;
  } finally {
    await raf.close();
  }
}
