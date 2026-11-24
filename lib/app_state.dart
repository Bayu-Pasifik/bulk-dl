import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bg.dart';
import 'l10n/app_localizations.dart';
import 'net/errors.dart';
import 'queue.dart';
import 'scraper.dart';
import 'screens/picker_screen.dart';
import 'screens/sniff_screen.dart';
import 'extractors/mitaku.dart';

/// How a pasted link is treated.
enum FetchMode { auto, single, playlist }

enum FetchResult { picker, queued, nothing }

/// Everything the screens share: queue, playlist selection and settings.
class AppState extends ChangeNotifier {
  AppState() {
    scraper = Scraper();
    queue = DownloadQueue(scraper);
    queue.addListener(_syncBg);
    MitakuExtractor.sniffer = (url, title) async =>
        navKey.currentState?.push<String>(
          MaterialPageRoute(
            builder: (_) => SniffScreen(url: url, title: title),
          ),
        );
  }

  late final Scraper scraper;
  late final DownloadQueue queue;
  final navKey = GlobalKey<NavigatorState>();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Selected bottom-navigation tab (0 home, 1 queue, 2 settings).
  final tab = ValueNotifier<int>(0);

  // --- input / fetch ---
  final urlCtl = TextEditingController();
  FetchMode mode = FetchMode.auto;
  bool loading = false;
  String? message;
  bool messageIsError = false;
  List<String> recent = [];

  // --- playlist picker ---
  List<VideoItem> videos = [];
  final selected = <String>{};
  final searchCtl = TextEditingController();
  String filter = '';

  // --- appearance / onboarding ---
  ThemeMode themeMode = ThemeMode.system;
  bool dynamicColor = false; // green by default; wallpaper colours are opt-in
  Locale? locale; // null = follow system
  bool disclaimerSeen = true;
  String? savePath;

  Future<void> init() async {
    queue.outDir().then((d) {
      savePath = d.path;
      notifyListeners();
    });
    await queue.loadSettings();
    if (queue.wgAutoConnect && queue.wgConfig.isNotEmpty && !queue.vpnUp) {
      queue.setVpn(true);
    }
    await _loadPrefs();
    urlCtl.text = queue.lastUrl;
    queue.initNet();
    queue.lib.load().then((_) => queue.restore());
    queue.cleanupPartials();
    BgService.requestPermissions();
    queue.lib.onShared(onShared);
    final t = await queue.lib.initialShare();
    if (t != null) onShared(t);
    notifyListeners();
  }

  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == p.getString('s_theme'),
        orElse: () => ThemeMode.system,
      );
      dynamicColor = p.getBool('s_dyn') ?? false;
      final lang = p.getString('s_lang');
      locale = (lang == null || lang.isEmpty) ? null : Locale(lang);
      recent = p.getStringList('s_recent') ?? [];
      disclaimerSeen = p.getBool('s_disclaimer') ?? false;
    } catch (_) {}
  }

  Future<void> _savePref(String k, Object v) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (v is String) await p.setString(k, v);
      if (v is bool) await p.setBool(k, v);
      if (v is List<String>) await p.setStringList(k, v);
    } catch (_) {}
  }

  void setThemeMode(ThemeMode m) {
    themeMode = m;
    _savePref('s_theme', m.name);
    notifyListeners();
  }

  void setDynamicColor(bool v) {
    dynamicColor = v;
    _savePref('s_dyn', v);
    notifyListeners();
  }

  void setLocale(Locale? l) {
    locale = l;
    _savePref('s_lang', l?.languageCode ?? '');
    notifyListeners();
  }

  /// Strings for code that has no BuildContext (status messages, notifications).
  AppLocalizations get str {
    final code = (locale ?? PlatformDispatcher.instance.locale).languageCode;
    return lookupAppLocalizations(Locale(code == 'id' ? 'id' : 'en'));
  }

  void acceptDisclaimer() {
    disclaimerSeen = true;
    _savePref('s_disclaimer', true);
    notifyListeners();
  }

  void refresh() => notifyListeners();

  void setMode(FetchMode m) {
    mode = m;
    notifyListeners();
  }

  Future<void> paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text?.trim();
    if (t != null && t.isNotEmpty) {
      urlCtl.text = t;
      notifyListeners();
    }
  }

  void snack(String text) => messengerKey.currentState
    ?..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// Text shared from another app: take its links and fetch them.
  void onShared(String text) {
    final urls = extractUrls(text);
    if (urls.isEmpty) return;
    urlCtl.text = urls.join('\n');
    tab.value = 0;
    fetch().then(_afterFetch);
  }

  void _afterFetch(FetchResult r) {
    if (r == FetchResult.picker) openPicker();
  }

  void openPicker() {
    navKey.currentState?.push(
      MaterialPageRoute<void>(builder: (_) => const PickerScreen()),
    );
  }

  static List<String> extractUrls(String text) =>
      RegExp(r'https?://[^\s]+')
          .allMatches(text)
          .map((m) => m.group(0)!)
          .toSet()
          .toList();

  /// Classifies every link: files/videos go to the queue (mode permitting),
  /// playlists are collected for the picker.
  Future<FetchResult> fetch() async {
    final urls = extractUrls(urlCtl.text);
    if (urls.isEmpty) {
      message = str.msgPasteLink;
      messageIsError = true;
      notifyListeners();
      return FetchResult.nothing;
    }
    queue.rememberUrl(urls.join(' '));
    loading = true;
    message = str.msgAnalyzing(urls.length);
    messageIsError = false;
    videos = [];
    searchCtl.clear();
    filter = '';
    selected.clear();
    notifyListeners();

    final singles = <VideoItem>[];
    final list = <VideoItem>[];
    final errors = <String>[];
    try {
      for (final url in urls) {
        try {
          final c = await scraper.classify(url);
          final isList = c.kind == UrlKind.playlist;
          if (isList && mode == FetchMode.single) {
            throw str.msgIsPlaylist;
          }
          if (isList) {
            list.addAll(
              await c.extractor.listPlaylist(
                c.uri,
                scraper.http,
                maxPages: queue.maxPages,
                onProgress: (n) {
                  message = str.msgFound(list.length + n);
                  notifyListeners();
                },
              ),
            );
          } else if (mode == FetchMode.playlist) {
            list.add(scraper.itemFor(c));
          } else {
            singles.add(scraper.itemFor(c));
          }
        } catch (e) {
          errors.add(friendlyError(e));
        }
      }
      if (singles.isNotEmpty) queue.add(singles);
      videos = list;
      selected.addAll(list.where((e) => !isDownloaded(e)).map((e) => e.id));
      _remember(urls);
      final parts = <String>[
        if (list.isNotEmpty) str.msgVideoCount(list.length),
        if (singles.isNotEmpty) str.msgQueued(singles.length),
        if (errors.isNotEmpty) errors.first,
      ];
      message = parts.isEmpty ? str.msgNothingFound : parts.join(' · ');
      messageIsError = errors.isNotEmpty && list.isEmpty && singles.isEmpty;
      if (list.isNotEmpty) return FetchResult.picker;
      if (singles.isNotEmpty) {
        tab.value = 1;
        return FetchResult.queued;
      }
      return FetchResult.nothing;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _remember(List<String> urls) {
    for (final u in urls.reversed) {
      recent.remove(u);
      recent.insert(0, u);
    }
    if (recent.length > 8) recent = recent.sublist(0, 8);
    _savePref('s_recent', recent);
  }

  void clearRecent() {
    recent = [];
    _savePref('s_recent', <String>[]);
    notifyListeners();
  }

  // --- picker helpers ---
  bool isDownloaded(VideoItem v) => queue.lib.items.containsKey(v.id);

  List<VideoItem> get visible => filter.isEmpty
      ? videos
      : videos.where((v) => v.title.toLowerCase().contains(filter)).toList();

  void setFilter(String t) {
    filter = t.trim().toLowerCase();
    notifyListeners();
  }

  void toggle(VideoItem v) {
    selected.contains(v.id) ? selected.remove(v.id) : selected.add(v.id);
    notifyListeners();
  }

  void selectAll() {
    selected.addAll(visible.map((e) => e.id));
    notifyListeners();
  }

  void selectNone() {
    selected.removeAll(visible.map((e) => e.id));
    notifyListeners();
  }

  void calcSizes() {
    final sel = videos.where((v) => selected.contains(v.id)).toList();
    scraper.retryFailed(sel);
    for (final v in sel) {
      scraper.ensure(v);
    }
  }

  double? sizeOf(VideoItem v) {
    final l = scraper.done[v.id];
    return l == null ? null : Scraper.pick(l, queue.maxQuality)?.mb;
  }

  String sizeLabel(VideoItem v) {
    final l = scraper.done[v.id];
    if (l == null) {
      return scraper.failed.contains(v.id) ? str.sizeUnknown : '...';
    }
    final p = Scraper.pick(l, queue.maxQuality);
    if (p == null) return str.noLink;
    final q = p.quality > 0 ? '${p.quality}p' : p.ext;
    return p.mb == null ? q : '$q · ${formatSize(p.mb!)}';
  }

  /// (sizes known, selected) for the current selection.
  (int, int) get sizeProgress {
    final sel = videos.where((v) => selected.contains(v.id));
    return (sel.where((v) => sizeOf(v) != null).length, sel.length);
  }

  /// Extrapolates the total from the average of known sizes; null when
  /// nothing is known yet or everything is already known.
  double? get estimatedTotal {
    final (known, all) = sizeProgress;
    if (known == 0 || known == all) return null;
    var sum = 0.0;
    for (final v in videos.where((v) => selected.contains(v.id))) {
      sum += sizeOf(v) ?? 0;
    }
    return sum / known * all;
  }

  /// True while size lookups are still running.
  bool get sizesLoading => scraper.pendingCount > 0;

  String totalLabel() {
    var total = 0.0;
    var unknown = 0;
    for (final v in videos.where((v) => selected.contains(v.id))) {
      final s = sizeOf(v);
      s == null ? unknown++ : total += s;
    }
    final n = selected.length;
    if (total > 0) {
      final size = formatSize(total);
      return unknown > 0
          ? str.downloadNSizeUnknown(n, size, unknown)
          : str.downloadNSize(n, size);
    }
    return unknown > 0 ? str.downloadNUnknown(n, unknown) : str.downloadN(n);
  }

  /// Adds the selection to the queue and shows it.
  void downloadSelected() {
    queue.add(videos.where((v) => selected.contains(v.id)));
    tab.value = 1;
    navKey.currentState?.popUntil((r) => r.isFirst);
  }

  void _syncBg() {
    final st = queue.stats();
    final eta = st.eta == null ? '' : ' · ETA ${formatEta(st.eta!)}';
    final spd = st.speed > 0 ? ' · ${formatSpeed(st.speed)}' : '';
    BgService.sync(
      active: queue.tasks.where((t) => t.busy).length + st.waiting,
      text: str.bgStatus(
        st.active,
        st.waiting,
        (st.fraction * 100).toStringAsFixed(0),
        '$spd$eta',
      ),
    );
  }

  @override
  void dispose() {
    queue.removeListener(_syncBg);
    queue.dispose();
    urlCtl.dispose();
    searchCtl.dispose();
    tab.dispose();
    super.dispose();
  }
}
