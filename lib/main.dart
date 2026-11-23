import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bg.dart';
import 'neo.dart';
import 'queue.dart';
import 'scraper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  BgService.init();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Bulk DL',
    debugShowCheckedModeBanner: false,
    theme: neoTheme(),
    home: const Home(),
  );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {
  final scraper = Scraper();
  late final queue = DownloadQueue(scraper);
  late final tabs = TabController(length: 2, vsync: this);
  final urlCtl = TextEditingController();
  List<VideoItem> videos = [];
  final searchCtl = TextEditingController();
  String filter = '';

  List<VideoItem> get _visible => filter.isEmpty
      ? videos
      : videos.where((v) => v.title.toLowerCase().contains(filter)).toList();

  bool _have(VideoItem v) => queue.lib.items.containsKey(v.id);
  final selected = <String>{};
  bool loading = false;
  String status = 'PASTE A LINK';
  String? savePath;

  @override
  void initState() {
    super.initState();
    queue.outDir().then((d) {
      if (mounted) setState(() => savePath = d.path);
    });
    queue.initNet();
    queue.lib.load().then((_) => queue.restore());
    queue.cleanupPartials();
    BgService.requestPermissions();
    queue.addListener(_syncBg);
    queue.lib.onShared(_onShared);
    queue.lib.initialShare().then((t) {
      if (t != null) _onShared(t);
    });
  }

  /// Text shared from another app: take the first link and fetch it.
  void _onShared(String text) {
    final m = RegExp(r'https?://\S+').firstMatch(text);
    if (m == null || !mounted) return;
    urlCtl.text = m.group(0)!;
    tabs.animateTo(0);
    _fetch();
  }

  void _syncBg() {
    final st = queue.stats();
    final eta = st.eta == null ? '' : ' · ETA ${formatEta(st.eta!)}';
    final spd = st.speed > 0 ? ' · ${formatSpeed(st.speed)}' : '';
    BgService.sync(
      active: queue.tasks.where((t) => t.busy).length + st.waiting,
      text:
          '${st.active} downloading, ${st.waiting} waiting · ${(st.fraction * 100).toStringAsFixed(0)}%$spd$eta',
    );
  }

  double? _sizeOf(VideoItem v) {
    final l = scraper.done[v.id];
    if (l == null) return null;
    return Scraper.pick(l, queue.maxQuality)?.mb;
  }

  String _sizeLabel(VideoItem v) {
    final l = scraper.done[v.id];
    if (l == null) {
      return scraper.failed.contains(v.id) ? 'size unknown' : '...';
    }
    final p = Scraper.pick(l, queue.maxQuality);
    if (p == null) return 'no download link';
    return p.mb == null
        ? '${p.quality}p'
        : '${p.quality}p · ${formatSize(p.mb!)}';
  }

  String _totalLabel() {
    var total = 0.0;
    var unknown = 0;
    for (final v in videos.where((v) => selected.contains(v.id))) {
      final s = _sizeOf(v);
      s == null ? unknown++ : total += s;
    }
    final size = total > 0 ? ' · ${formatSize(total)}' : '';
    final unk = unknown > 0 ? ' (+$unknown ?)' : '';
    return 'Download ${selected.length}$size$unk';
  }

  Future<void> _fetch() async {
    final url = urlCtl.text.trim();
    if (!url.startsWith('http')) return;
    setState(() {
      loading = true;
      status = 'LOADING...';
      videos = [];
      searchCtl.clear();
      filter = '';
      selected.clear();
    });
    try {
      final v = await scraper.fetchPlaylist(
        url,
        onProgress: (n) => setState(() => status = '$n VIDEOS FOUND...'),
      );
      setState(() {
        videos = v;
        selected.addAll(v.where((e) => !_have(e)).map((e) => e.id));
        status = '${v.length} VIDEOS';
      });
    } catch (e) {
      setState(() => status = 'ERROR: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: TabBarView(
                controller: tabs,
                physics: const NeverScrollableScrollPhysics(),
                children: [_playlistTab(), _queueTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: pink,
        border: Border(
          bottom: BorderSide(color: ink, width: borderW),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NeoBox(
                color: yellow,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Text('BULK DL', style: heavy.copyWith(fontSize: 28)),
              ),
              const Spacer(),
              const NeoTag('v1.0', color: Colors.white),
            ],
          ),
          const SizedBox(height: 14),
          ListenableBuilder(
            listenable: Listenable.merge([tabs, queue]),
            builder: (_, _) {
              final active = queue.tasks
                  .where(
                    (t) =>
                        t.status == Status.downloading ||
                        t.status == Status.resolving ||
                        t.status == Status.waiting,
                  )
                  .length;
              return Row(
                children: [
                  Expanded(
                    child: _tabButton(
                      0,
                      'PLAYLIST',
                      videos.isEmpty ? null : '${videos.length}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _tabButton(
                      1,
                      'QUEUE',
                      active > 0 ? '$active' : null,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tabButton(int i, String label, String? badge) {
    final on = tabs.index == i;
    return GestureDetector(
      onTap: () => tabs.animateTo(i),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: on ? ink : Colors.white,
          border: Border.all(color: ink, width: borderW),
          boxShadow: on
              ? null
              : const [BoxShadow(color: ink, offset: Offset(4, 4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: heavy.copyWith(fontSize: 15, color: on ? yellow : ink),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                color: on ? yellow : ink,
                child: Text(
                  badge,
                  style: mono.copyWith(color: on ? ink : yellow),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _playlistTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: NeoBox(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: urlCtl,
                          maxLines: 1,
                          style: mono.copyWith(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'PLAYLIST URL',
                            hintStyle: mono.copyWith(
                              color: const Color(0xFF888888),
                            ),
                            border: InputBorder.none,
                            isCollapsed: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.content_paste, color: ink),
                        onPressed: () async {
                          final d = await Clipboard.getData(
                            Clipboard.kTextPlain,
                          );
                          if (d?.text != null) urlCtl.text = d!.text!.trim();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              NeoButton(
                label: 'Fetch',
                color: blue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                onPressed: loading ? null : _fetch,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: NeoTag(status, color: yellow, maxLines: 2),
                ),
              ),
              const SizedBox(width: 10),
              Text('MAX', style: heavy.copyWith(fontSize: 13)),
              const SizedBox(width: 8),
              NeoDrop<int>(
                value: queue.maxQuality,
                items: const [240, 360, 480, 720, 1080, 1440, 2160],
                label: (q) => '${q}P',
                color: green,
                onChanged: (q) => setState(() => queue.maxQuality = q),
              ),
            ],
          ),
        ),
        if (videos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 20, 0),
            child: NeoBox(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  const Icon(Icons.search, color: ink),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: searchCtl,
                      maxLines: 1,
                      style: mono.copyWith(fontSize: 14),
                      onChanged: (t) =>
                          setState(() => filter = t.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'FILTER TITLE',
                        hintStyle: mono.copyWith(
                          color: const Color(0xFF888888),
                        ),
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  if (filter.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close, color: ink),
                      onPressed: () => setState(() {
                        searchCtl.clear();
                        filter = '';
                      }),
                    ),
                ],
              ),
            ),
          ),
        if (videos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 20, 0),
            child: Row(
              children: [
                NeoButton(
                  label: 'All',
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  onPressed: () => setState(
                    () => selected.addAll(_visible.map((e) => e.id)),
                  ),
                ),
                const SizedBox(width: 12),
                NeoButton(
                  label: 'None',
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  onPressed: () => setState(
                    () => selected.removeAll(_visible.map((e) => e.id)),
                  ),
                ),
                const Spacer(),
                NeoButton(
                  icon: Icons.calculate,
                  label: 'Calc size',
                  color: orange,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  onPressed: () {
                    final sel = videos
                        .where((v) => selected.contains(v.id))
                        .toList();
                    scraper.retryFailed(sel);
                    for (final v in sel) {
                      scraper.ensure(v);
                    }
                  },
                ),
              ],
            ),
          ),
        if (loading)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 20, 0),
            child: NeoProgress(),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 18, 20, 12),
            itemCount: _visible.length,
            itemBuilder: (_, i) {
              final v = _visible[i];
              scraper.ensure(v);
              final on = selected.contains(v.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GestureDetector(
                  onTap: () => setState(
                    () => on ? selected.remove(v.id) : selected.add(v.id),
                  ),
                  child: NeoBox(
                    color: on ? yellow : Colors.white,
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        _thumb(v),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                v.title.toUpperCase(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: heavy.copyWith(fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              ListenableBuilder(
                                listenable: scraper,
                                builder: (_, _) => Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    NeoTag(
                                      _sizeLabel(v),
                                      color: on ? Colors.white : paper,
                                    ),
                                    if (_have(v))
                                      const NeoTag('DOWNLOADED', color: green),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        NeoCheck(on),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (videos.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 20, 16),
            decoration: const BoxDecoration(
              color: paper,
              border: Border(
                top: BorderSide(color: ink, width: borderW),
              ),
            ),
            child: ListenableBuilder(
              listenable: scraper,
              builder: (_, _) => NeoButton(
                expand: true,
                icon: Icons.download,
                color: green,
                label: _totalLabel(),
                onPressed: selected.isEmpty
                    ? null
                    : () {
                        queue.add(videos.where((v) => selected.contains(v.id)));
                        tabs.animateTo(1);
                      },
              ),
            ),
          ),
      ],
    );
  }

  Widget _thumb(VideoItem v) {
    const w = 92.0, h = 64.0;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: ink,
        border: Border.all(color: ink, width: 2),
      ),
      child: v.thumb == null
          ? null
          : Image.network(
              v.thumb!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(),
            ),
    );
  }

  Widget _queueTab() {
    return ListenableBuilder(
      listenable: queue,
      builder: (_, _) => Column(
        children: [
          if (savePath != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 20, 0),
              child: NeoBox(
                color: blue,
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    const Icon(Icons.folder, color: ink),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Movies/BulkDL',
                        style: mono.copyWith(fontSize: 11.5),
                        maxLines: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Builder(
            builder: (_) {
              final st = queue.stats();
              if (st.active + st.waiting == 0) return const SizedBox.shrink();
              final paused = queue.blocked;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 20, 0),
                child: NeoBox(
                  color: yellow,
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${st.active} ACTIVE · ${st.waiting} WAITING · ${(st.fraction * 100).toStringAsFixed(0)}%',
                        style: heavy.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${st.speed > 0 ? formatSpeed(st.speed) : '--'} · ETA ${st.eta == null ? '--:--' : formatEta(st.eta!)}',
                        style: mono.copyWith(fontSize: 12),
                      ),
                      if (paused) ...[
                        const SizedBox(height: 4),
                        Text(
                          'PAUSED: WAITING FOR WI-FI',
                          style: heavy.copyWith(fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 8),
                      NeoProgress(value: st.fraction),
                    ],
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 20, 0),
            child: GestureDetector(
              onTap: () => queue.wifiOnly = !queue.wifiOnly,
              child: Row(
                children: [
                  NeoCheck(queue.wifiOnly),
                  const SizedBox(width: 12),
                  Text('WI-FI ONLY', style: heavy.copyWith(fontSize: 14)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 20, 0),
            child: Row(
              children: [
                NeoButton(
                  label: 'Clear finished',
                  color: pink,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  onPressed: queue.clearFinished,
                ),
                const Spacer(),
                Text('PARALLEL', style: heavy.copyWith(fontSize: 13)),
                const SizedBox(width: 8),
                NeoDrop<int>(
                  value: queue.concurrency,
                  items: const [1, 2, 3, 4],
                  label: (n) => '$n',
                  color: orange,
                  onChanged: (n) => setState(() => queue.concurrency = n),
                ),
              ],
            ),
          ),
          Expanded(
            child: queue.tasks.isEmpty
                ? Center(
                    child: NeoBox(
                      color: Colors.white,
                      child: Text(
                        'QUEUE EMPTY',
                        style: heavy.copyWith(fontSize: 18),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 18, 20, 16),
                    itemCount: queue.tasks.length,
                    itemBuilder: (_, i) => _TaskTile(queue.tasks[i], queue),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile(this.t, this.q);
  final Task t;
  final DownloadQueue q;

  Color get _color => switch (t.status) {
    Status.waiting => grey,
    Status.resolving => blue,
    Status.downloading => yellow,
    Status.done => green,
    Status.failed => pink,
    Status.canceled => orange,
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: t,
      builder: (_, _) {
        final active =
            t.status == Status.downloading || t.status == Status.resolving;
        final label = t.status == Status.failed
            ? 'FAILED: ${t.error}'
            : t.status == Status.downloading
            ? 'DOWNLOADING ${(t.progress * 100).toStringAsFixed(0)}% · ${t.quality}P${t.speed > 0 ? ' · ${formatSpeed(t.speed)}' : ''}'
            : t.status == Status.done
            ? 'DONE · ${t.quality}P'
            : t.status.name.toUpperCase();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: NeoBox(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.video.title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: heavy.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      NeoTag(label, color: _color, maxLines: 2),
                      if (active) ...[
                        const SizedBox(height: 10),
                        NeoProgress(
                          value: t.status == Status.downloading
                              ? t.progress
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (active || t.status == Status.waiting)
                  NeoButton(
                    icon: Icons.close,
                    color: pink,
                    padding: const EdgeInsets.all(8),
                    onPressed: () => q.cancel(t),
                  )
                else if (t.status == Status.failed ||
                    t.status == Status.canceled)
                  NeoButton(
                    icon: Icons.refresh,
                    color: yellow,
                    padding: const EdgeInsets.all(8),
                    onPressed: () => q.retry(t),
                  )
                else if (t.file?.startsWith('content://') ?? false)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NeoButton(
                        icon: Icons.play_arrow,
                        color: green,
                        padding: const EdgeInsets.all(8),
                        onPressed: () => q.lib.open(t.file!),
                      ),
                      const SizedBox(width: 8),
                      NeoButton(
                        icon: Icons.share,
                        color: blue,
                        padding: const EdgeInsets.all(8),
                        onPressed: () => q.lib.share(t.file!),
                      ),
                    ],
                  )
                else
                  const NeoBox(
                    color: green,
                    shadow: 0,
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.check, color: ink),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
