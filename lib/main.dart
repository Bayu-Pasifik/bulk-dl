import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'queue.dart';
import 'scraper.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Bulk DL',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        darkTheme: ThemeData(
            colorSchemeSeed: Colors.indigo,
            brightness: Brightness.dark,
            useMaterial3: true),
        home: const Home(),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final scraper = Scraper();
  late final queue = DownloadQueue(scraper);
  final urlCtl = TextEditingController();
  List<VideoItem> videos = [];
  final selected = <String>{};
  bool loading = false;
  String status = '';
  String? savePath;

  @override
  void initState() {
    super.initState();
    queue.outDir().then((d) => setState(() => savePath = d.path));
  }

  double? _sizeOf(VideoItem v) {
    final l = scraper.done[v.id];
    if (l == null) return null;
    return Scraper.pick(l, queue.maxQuality)?.mb;
  }

  String _sizeLabel(VideoItem v) {
    final l = scraper.done[v.id];
    if (l == null) return scraper.failed.contains(v.id) ? 'size unknown' : '...';
    final p = Scraper.pick(l, queue.maxQuality);
    if (p == null) return 'no download link';
    return p.mb == null ? '${p.quality}p' : '${p.quality}p · ${formatSize(p.mb!)}';
  }

  String _totalLabel() {
    var total = 0.0;
    var unknown = 0;
    for (final v in videos.where((v) => selected.contains(v.id))) {
      final s = _sizeOf(v);
      s == null ? unknown++ : total += s;
    }
    final size = total > 0 ? ' · ${formatSize(total)}' : '';
    final unk = unknown > 0 ? ' (+$unknown unknown)' : '';
    return 'Download ${selected.length}$size$unk';
  }

  Future<void> _fetch() async {
    final url = urlCtl.text.trim();
    if (!url.startsWith('http')) return;
    setState(() {
      loading = true;
      status = 'Loading...';
      videos = [];
      selected.clear();
    });
    try {
      final v = await scraper.fetchPlaylist(url,
          onProgress: (n) => setState(() => status = '$n videos found...'));
      setState(() {
        videos = v;
        selected.addAll(v.map((e) => e.id));
        status = '${v.length} videos';
      });
    } catch (e) {
      setState(() => status = 'Error: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bulk Downloader'),
          bottom: const TabBar(tabs: [Tab(text: 'Playlist'), Tab(text: 'Queue')]),
        ),
        body: TabBarView(children: [_playlistTab(), _queueTab()]),
      ),
    );
  }

  Widget _playlistTab() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: urlCtl,
              decoration: InputDecoration(
                labelText: 'Playlist URL',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste),
                  onPressed: () async {
                    final d = await Clipboard.getData(Clipboard.kTextPlain);
                    if (d?.text != null) urlCtl.text = d!.text!.trim();
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
              onPressed: loading ? null : _fetch, child: const Text('Fetch')),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          Expanded(child: Text(status)),
          const Text('Max '),
          DropdownButton<int>(
            value: queue.maxQuality,
            items: [240, 360, 480, 720, 1080, 1440, 2160]
                .map((q) => DropdownMenuItem(value: q, child: Text('${q}p')))
                .toList(),
            onChanged: (q) => setState(() => queue.maxQuality = q!),
          ),
        ]),
      ),
      if (videos.isNotEmpty)
        Row(children: [
          TextButton(
              onPressed: () =>
                  setState(() => selected.addAll(videos.map((e) => e.id))),
              child: const Text('All')),
          TextButton(
              onPressed: () => setState(selected.clear),
              child: const Text('None')),
          const Spacer(),
          TextButton.icon(
              icon: const Icon(Icons.calculate_outlined),
              onPressed: () {
                for (final v in videos.where((v) => selected.contains(v.id))) {
                  scraper.ensure(v);
                }
              },
              label: const Text('Calc size')),
        ]),
      if (loading) const LinearProgressIndicator(),
      Expanded(
        child: ListView.builder(
          itemCount: videos.length,
          itemBuilder: (_, i) {
            final v = videos[i];
            scraper.ensure(v);
            return CheckboxListTile(
              value: selected.contains(v.id),
              onChanged: (c) =>
                  setState(() => c! ? selected.add(v.id) : selected.remove(v.id)),
              title: Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: ListenableBuilder(
                listenable: scraper,
                builder: (_, _) => Text(_sizeLabel(v)),
              ),
              secondary: v.thumb == null
                  ? const SizedBox(width: 80)
                  : Image.network(v.thumb!,
                      width: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(width: 80)),
            );
          },
        ),
      ),
      if (videos.isNotEmpty)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Builder(
            builder: (ctx) => SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.download),
                label: ListenableBuilder(
                  listenable: scraper,
                  builder: (_, _) => Text(_totalLabel()),
                ),
                onPressed: selected.isEmpty
                    ? null
                    : () {
                        queue.add(videos.where((v) => selected.contains(v.id)));
                        DefaultTabController.of(ctx).animateTo(1);
                      },
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _queueTab() {
    return ListenableBuilder(
      listenable: queue,
      builder: (_, __) => Column(children: [
        if (savePath != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Saved to: $savePath',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        Row(children: [
          TextButton(
              onPressed: queue.clearFinished, child: const Text('Clear finished')),
          const Spacer(),
          const Text('Parallel '),
          DropdownButton<int>(
            value: queue.concurrency,
            items: [1, 2, 3, 4]
                .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                .toList(),
            onChanged: (n) => setState(() => queue.concurrency = n!),
          ),
          const SizedBox(width: 12),
        ]),
        Expanded(
          child: ListView.builder(
            itemCount: queue.tasks.length,
            itemBuilder: (_, i) => _TaskTile(queue.tasks[i], queue),
          ),
        ),
      ]),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile(this.t, this.q);
  final Task t;
  final DownloadQueue q;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: t,
      builder: (_, __) {
        final active =
            t.status == Status.downloading || t.status == Status.resolving;
        return ListTile(
          title: Text(t.video.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.status == Status.failed
                    ? 'failed: ${t.error}'
                    : t.status.name),
                if (active)
                  LinearProgressIndicator(
                      value: t.status == Status.downloading ? t.progress : null),
              ]),
          trailing: active || t.status == Status.waiting
              ? IconButton(icon: const Icon(Icons.close), onPressed: () => q.cancel(t))
              : (t.status == Status.failed || t.status == Status.canceled)
                  ? IconButton(
                      icon: const Icon(Icons.refresh), onPressed: () => q.retry(t))
                  : const Icon(Icons.check, color: Colors.green),
        );
      },
    );
  }
}
