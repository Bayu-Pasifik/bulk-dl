import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

/// A newer release published on GitHub.
class UpdateInfo {
  UpdateInfo(this.version, this.notes, this.url, [this.sha256]);
  final String version;
  final String notes;

  /// APK for this device's CPU when the release has one, else the release page.
  final String url;

  /// SHA-256 of the APK from the release `.sha256` asset, when published.
  final String? sha256;
}

/// Checks the GitHub "latest release" of this app against the installed
/// version. Nothing is downloaded here; [openUrl] hands the link to the
/// browser, which downloads the APK and offers to install it.
class Updater {
  static const repo = 'Bayu-Pasifik/bulk-dl';
  static const _ch = MethodChannel('bulk_dl/files');

  static Future<String> currentVersion() async {
    try {
      return await _ch.invokeMethod<String>('version') ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<List<String>> _abis() async {
    try {
      final l = await _ch.invokeListMethod<String>('abis');
      return l ?? const [];
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> openUrl(String url) async {
    try {
      return await _ch.invokeMethod<bool>('openUrl', {'url': url}) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// `1.2.0` / `v1.2.0+3` -> [1, 2, 0]; non-numeric parts count as 0.
  static List<int> parse(String v) {
    final core = v
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split(RegExp('[+-]'))
        .first;
    return core.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  }

  /// True when [latest] is a higher version than [current].
  static bool isNewer(String latest, String current) {
    final a = parse(latest);
    final b = parse(current);
    for (var i = 0; i < (a.length > b.length ? a.length : b.length); i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  /// Release asset name for the first CPU in [abis] that the app ships.
  static String? apkName(List<String> abis) {
    const shipped = {'arm64-v8a', 'armeabi-v7a', 'x86_64'};
    for (final abi in abis) {
      if (shipped.contains(abi)) return 'app-$abi-release.apk';
    }
    return null;
  }

  /// First 64-hex token of a `sha256sum` style file, lower-cased, else null.
  static String? parseSha256(String text) {
    final m = RegExp(r'\b([0-9a-fA-F]{64})\b').firstMatch(text);
    return m?.group(1)!.toLowerCase();
  }

  /// Best effort: null when the release has no checksum file.
  static Future<String?> fetchSha256(Dio dio, String apkUrl) async {
    try {
      final r = await dio.get<String>(
        '$apkUrl.sha256',
        options: Options(
          responseType: ResponseType.plain,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'User-Agent': 'bulk_dl'},
        ),
      );
      return parseSha256(r.data ?? '');
    } catch (_) {
      return null;
    }
  }

  /// Tag of the latest release, read from the `releases/latest` redirect
  /// (the REST API is rate limited to 60 requests/hour per IP).
  static Future<String> latestTag(Dio dio) async {
    final r = await dio.get<void>(
      'https://github.com/$repo/releases/latest',
      options: Options(
        followRedirects: false,
        validateStatus: (s) => s != null && s < 400,
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'User-Agent': 'bulk_dl'},
      ),
    );
    final loc = r.headers.value('location') ?? '';
    final m = RegExp(r'/releases/tag/([^/?#]+)').firstMatch(loc);
    if (m == null) throw 'No release found';
    return Uri.decodeComponent(m.group(1)!);
  }

  /// Null when already up to date; throws on network/parse errors.
  static Future<UpdateInfo?> check(Dio dio, {String? current}) async {
    final cur = current ?? await currentVersion();
    final tag = await latestTag(dio);
    if (!isNewer(tag, cur)) return null;
    final apk = apkName(await _abis());
    final base = 'https://github.com/$repo/releases';
    final url = apk == null ? '$base/tag/$tag' : '$base/download/$tag/$apk';
    final sum = apk == null ? null : await fetchSha256(dio, url);
    return UpdateInfo(tag.replaceFirst(RegExp(r'^[vV]'), ''), '', url, sum);
  }
}
