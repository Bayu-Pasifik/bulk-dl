import 'package:dio/dio.dart';

class HeadInfo {
  HeadInfo({
    required this.url,
    this.length,
    this.type,
    this.disposition,
    this.ranges = false,
  });

  /// Final URL after redirects.
  final String url;
  final int? length;
  final String? type; // lower-case media type without parameters
  final String? disposition;
  final bool ranges;
}

/// Minimal HTTP surface the extractors need (fakeable in tests).
abstract class Http {
  Future<String> getText(String url);
  Future<HeadInfo> head(String url);
}

class DioHttp implements Http {
  DioHttp(this.dio);
  final Dio dio;
  final Map<String, (DateTime, String)> _cache = {};

  @override
  Future<String> getText(String url) async {
    final hit = _cache[url];
    if (hit != null &&
        DateTime.now().difference(hit.$1) < const Duration(seconds: 60)) {
      return hit.$2;
    }
    final r = await dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    final body = r.data ?? '';
    // Anti-bot challenge pages are transient: never serve them from cache.
    if (!body.contains('function leastFactor')) {
      _cache[url] = (DateTime.now(), body);
      if (_cache.length > 20) _cache.remove(_cache.keys.first);
    }
    return body;
  }

  @override
  Future<HeadInfo> head(String url) async {
    Response<dynamic> r;
    try {
      r = await dio.head(
        url,
        options: Options(validateStatus: (s) => s != null && s < 400),
      );
    } on DioException {
      // Some servers reject HEAD: ask for the first byte instead.
      r = await dio.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Range': 'bytes=0-0'},
          validateStatus: (s) => s != null && s < 400,
        ),
      );
      (r.data as ResponseBody?)?.stream.listen((_) {}).cancel();
    }
    final h = r.headers;
    int? len = int.tryParse(h.value('content-length') ?? '');
    final cr = h.value('content-range');
    final partial = r.statusCode == 206;
    if (cr != null) {
      final t = int.tryParse(cr.split('/').last);
      if (t != null) len = t;
    } else if (partial) {
      len = null;
    }
    return HeadInfo(
      url: r.realUri.toString(),
      length: len,
      type: h.value('content-type')?.split(';').first.trim().toLowerCase(),
      disposition: h.value('content-disposition'),
      ranges: partial || (h.value('accept-ranges') ?? '').contains('bytes'),
    );
  }
}
