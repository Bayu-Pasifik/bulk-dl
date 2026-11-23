import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LibEntry {
  LibEntry(this.id, this.uri, this.quality);
  final String id;
  final String uri;
  final int quality;
}

/// Finished downloads, saved to public Movies/BulkDL via MediaStore and
/// remembered across launches (so they are never downloaded twice).
class Library {
  static const _ch = MethodChannel('bulk_dl/files');
  static const _key = 'library_v1';
  final Map<String, LibEntry> items = {};

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw == null) return;
      (jsonDecode(raw) as Map<String, dynamic>).forEach((id, v) {
        items[id] = LibEntry(id, v['uri'] as String, v['quality'] as int);
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _key,
      jsonEncode({
        for (final e in items.values)
          e.id: {'uri': e.uri, 'quality': e.quality},
      }),
    );
  }

  /// Entry whose file is still present, else null (and forgets it).
  Future<LibEntry?> find(String id) async {
    final e = items[id];
    if (e == null) return null;
    if (await exists(e.uri)) return e;
    items.remove(id);
    await _save();
    return null;
  }

  Future<void> add(String id, String uri, int quality) async {
    items[id] = LibEntry(id, uri, quality);
    await _save();
  }

  /// Returns the content:// uri, or null when export is unsupported/failed.
  Future<String?> export(String path, String name) async {
    try {
      return await _ch.invokeMethod<String>('export', {
        'path': path,
        'name': name,
      });
    } catch (_) {
      return null;
    }
  }

  Future<bool> exists(String uri) async {
    try {
      return await _ch.invokeMethod<bool>('exists', {'uri': uri}) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Text shared into the app that launched it (or null).
  Future<String?> initialShare() async {
    try {
      return await _ch.invokeMethod<String>('initialShare');
    } catch (_) {
      return null;
    }
  }

  /// Called when text is shared while the app is already running.
  void onShared(void Function(String text) cb) {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'shared') cb(call.arguments as String);
    });
  }

  Future<bool> open(String uri) async =>
      await _ch.invokeMethod<bool>('open', {'uri': uri}) ?? false;

  Future<bool> share(String uri) async =>
      await _ch.invokeMethod<bool>('share', {'uri': uri}) ?? false;
}
