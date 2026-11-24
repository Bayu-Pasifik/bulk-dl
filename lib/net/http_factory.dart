import 'package:dio/dio.dart';

const userAgent =
    'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/120.0 Mobile Safari/537.36';

/// Single place that builds every [Dio] in the app (DNS/proxy hooks go here).
Dio createDio() => Dio(
  BaseOptions(
    headers: {'User-Agent': userAgent},
    followRedirects: true,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
  ),
);
