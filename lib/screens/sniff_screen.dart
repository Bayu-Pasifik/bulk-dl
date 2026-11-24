import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_ui/material_ui.dart';

/// Shows a video player page; the user presses play and the first media
/// stream (`.m3u8` / `.mp4`) it requests is returned via `Navigator.pop`.
class SniffScreen extends StatefulWidget {
  const SniffScreen({super.key, required this.url, required this.title});
  final String url;
  final String title;

  @override
  State<SniffScreen> createState() => _SniffScreenState();
}

class _SniffScreenState extends State<SniffScreen> {
  static final _media = RegExp(r'\.(m3u8|mp4)(\?|$)', caseSensitive: false);
  bool _done = false;

  void _hit(String url) {
    if (_done || !_media.hasMatch(url)) return;
    final l = url.toLowerCase();
    if (l.contains('/ads/') || l.contains('preview') || l.contains('sprite')) {
      return;
    }
    _done = true;
    if (mounted) Navigator.of(context).pop(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Tekan play pada video. Unduhan mulai otomatis setelah stream '
              'terdeteksi. / Press play; the download starts once the stream '
              'is detected.',
            ),
          ),
          Expanded(
            child: InAppWebView(
              initialData: InAppWebViewInitialData(
                data:
                    '<html><body style="margin:0;background:#000"><iframe '
                    'src="${widget.url}" allow="autoplay; fullscreen" '
                    'allowfullscreen style="width:100%;height:100vh;border:0">'
                    '</iframe></body></html>',
                baseUrl: WebUri('https://mitaku.net/'),
              ),
              initialSettings: InAppWebViewSettings(
                useShouldInterceptRequest: true,
                mediaPlaybackRequiresUserGesture: true,
                javaScriptCanOpenWindowsAutomatically: false,
              ),
              shouldInterceptRequest: (c, req) async {
                _hit(req.url.toString());
                return null;
              },
              onLoadResource: (c, r) => _hit(r.url.toString()),
            ),
          ),
        ],
      ),
    );
  }
}
