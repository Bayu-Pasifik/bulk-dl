import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

const _blockHint =
    'Connection blocked or reset — your ISP may block this site by IP/SNI. '
    'Try a VPN or Private DNS';

bool _looksBlocked(Object? e) {
  if (e is HandshakeException || e is TlsException) return true;
  if (e is SocketException) {
    final m = '${e.message} ${e.osError?.message ?? ''}'.toLowerCase();
    return m.contains('reset') || m.contains('refused');
  }
  return false;
}

/// Short, human-readable message for network failures.
String friendlyError(Object e) {
  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Connection timed out';
      case DioExceptionType.connectionError:
        final inner = e.error;
        if (inner is SocketException &&
            inner.message.contains('Failed host lookup')) {
          return 'Cannot resolve host (DNS failed or blocked)';
        }
        return _looksBlocked(inner) ? _blockHint : 'No connection';
      case DioExceptionType.badResponse:
        return 'Server error ${e.response?.statusCode ?? ''}'.trim();
      case DioExceptionType.cancel:
        return 'Canceled';
      default:
        return _looksBlocked(e.error) ? _blockHint : (e.message ?? e.type.name);
    }
  }
  if (e is TimeoutException) return 'Connection timed out';
  if (e is SocketException &&
      e.message.contains('Failed host lookup')) {
    return 'Cannot resolve host (DNS failed or blocked)';
  }
  if (_looksBlocked(e)) return _blockHint;
  return '$e';
}
