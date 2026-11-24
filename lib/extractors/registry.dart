import '../models.dart';
import '../net/http.dart';
import 'adult.dart';
import 'direct.dart';
import 'eporner.dart';
import 'extractor.dart';
import 'generic.dart';

class Classified {
  Classified(this.extractor, this.kind, this.uri);
  final Extractor extractor;
  final UrlKind kind;
  final Uri uri;
}

/// Ordered list of extractors; the first one that recognises a URL wins.
class Registry {
  Registry([List<Extractor>? list])
    : all =
          list ??
          [
            DirectFileExtractor(),
            XvideosFamilyExtractor(),
            MediaDefExtractor(),
            KvsExtractor(),
            XhamsterExtractor(),
            TnaflixExtractor(),
            EpornerExtractor(),
            GenericHtmlExtractor(),
          ];
  final List<Extractor> all;

  Extractor byId(String id) =>
      all.firstWhere((e) => e.id == id, orElse: () => all.first);

  Future<Classified> classify(String url, Http http) async {
    final u = Uri.tryParse(url.trim());
    if (u == null ||
        !(u.scheme == 'http' || u.scheme == 'https') ||
        u.host.isEmpty) {
      throw 'Not a valid http(s) link';
    }
    Object? firstError;
    for (final e in all) {
      try {
        final k = await e.classify(u, http);
        if (k != null) return Classified(e, k, u);
      } catch (err) {
        firstError ??= err;
      }
    }
    // Surface a network/HTTP failure rather than a vague "nothing found".
    if (firstError != null) throw firstError;
    throw 'No downloadable media found at this link';
  }
}
