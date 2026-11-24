import 'package:flutter/services.dart';

/// Result of checking a WireGuard `.conf` before handing it to the tunnel.
class WgCheck {
  const WgCheck(this.error, {this.endpoint, this.address});
  final String? error;
  final String? endpoint;
  final String? address;
  bool get ok => error == null;
}

/// Light validation of a wg-quick style config (the native library does the
/// strict parsing; this gives readable errors before any permission prompt).
WgCheck checkWgConfig(String text) {
  final lines = text
      .split(RegExp(r'\r?\n'))
      .map((l) => l.split('#').first.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.isEmpty) return const WgCheck('empty');
  var section = '';
  var hasIface = false, hasPeer = false;
  String? priv, pub, endpoint, address;
  for (final l in lines) {
    if (l.startsWith('[') && l.endsWith(']')) {
      section = l.substring(1, l.length - 1).toLowerCase();
      if (section == 'interface') hasIface = true;
      if (section == 'peer') hasPeer = true;
      continue;
    }
    final i = l.indexOf('=');
    if (i < 0) return WgCheck('bad line: $l');
    final k = l.substring(0, i).trim().toLowerCase();
    final v = l.substring(i + 1).trim();
    if (section == 'interface') {
      if (k == 'privatekey') priv = v;
      if (k == 'address') address = v;
    } else if (section == 'peer') {
      if (k == 'publickey') pub = v;
      if (k == 'endpoint') endpoint = v;
    }
  }
  final key = RegExp(r'^[A-Za-z0-9+/]{43}=$');
  if (!hasIface) return const WgCheck('missing [Interface]');
  if (!hasPeer) return const WgCheck('missing [Peer]');
  if (priv == null || !key.hasMatch(priv)) {
    return const WgCheck('invalid PrivateKey');
  }
  if (address == null) return const WgCheck('missing Address');
  if (pub == null || !key.hasMatch(pub)) {
    return const WgCheck('invalid peer PublicKey');
  }
  if (endpoint == null || !endpoint.contains(':')) {
    return const WgCheck('missing peer Endpoint');
  }
  return WgCheck(null, endpoint: endpoint, address: address);
}

/// In-app WireGuard tunnel backed by Android's VpnService (see VpnBridge.kt).
class Vpn {
  Vpn._();
  static final Vpn instance = Vpn._();
  static const _ch = MethodChannel('bulk_dl/vpn');

  Future<bool> isUp() async {
    try {
      return await _ch.invokeMethod<bool>('isUp') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Throws a readable message on failure or when permission is refused.
  Future<void> up(String config) async {
    try {
      await _ch.invokeMethod<bool>('up', {'config': config});
    } on PlatformException catch (e) {
      throw e.code == 'denied'
          ? 'VPN permission denied'
          : (e.message ?? e.code);
    } on MissingPluginException {
      throw 'VPN is only available on Android';
    }
  }

  Future<void> down() async {
    try {
      await _ch.invokeMethod<bool>('down');
    } on PlatformException catch (e) {
      throw e.message ?? e.code;
    } on MissingPluginException {
      // nothing to stop
    }
  }
}
