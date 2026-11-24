import 'package:bulk_dl/net/http.dart';

class FakeHttp implements Http {
  FakeHttp({this.pages = const {}, this.heads = const {}});
  final Map<String, String> pages;
  final Map<String, HeadInfo> heads;
  final List<String> calls = [];

  @override
  Future<String> getText(String url) async {
    calls.add('GET $url');
    final b = pages[url];
    if (b == null) throw 'GET 404 $url';
    return b;
  }

  @override
  Future<HeadInfo> head(String url) async {
    calls.add('HEAD $url');
    final h = heads[url];
    if (h == null) throw 'HEAD failed $url';
    return h;
  }
}
