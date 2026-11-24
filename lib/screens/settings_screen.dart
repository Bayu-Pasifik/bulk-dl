import 'package:material_ui/material_ui.dart';

import '../app_scope.dart';
import '../net/dns.dart';
import '../net/errors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final q = app.queue;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    Widget section(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(t, style: tt.titleSmall?.copyWith(color: cs.primary)),
    );
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('Pengaturan')),
          SliverList.list(
            children: [
              section('Unduhan'),
              ListTile(
                title: const Text('Kualitas maksimum'),
                trailing: DropdownMenu<int>(
                  initialSelection: q.maxQuality,
                  width: 130,
                  requestFocusOnTap: false,
                  dropdownMenuEntries: [
                    for (final v in const [240, 360, 480, 720, 1080, 1440, 2160])
                      DropdownMenuEntry(value: v, label: '${v}p'),
                  ],
                  onSelected: (v) {
                    if (v != null) {
                      q.maxQuality = v;
                      app.refresh();
                    }
                  },
                ),
              ),
              ListTile(
                title: const Text('Unduhan paralel'),
                subtitle: Slider(
                  value: q.concurrency.toDouble(),
                  min: 1,
                  max: 4,
                  divisions: 3,
                  label: '${q.concurrency}',
                  onChanged: (v) {
                    q.concurrency = v.round();
                    app.refresh();
                  },
                ),
                trailing: Text('${q.concurrency}', style: tt.titleMedium),
              ),
              SwitchListTile(
                title: const Text('Hanya lewat Wi-Fi'),
                subtitle: const Text('Jeda unduhan saat memakai data seluler'),
                value: q.wifiOnly,
                onChanged: (v) {
                  q.wifiOnly = v;
                  app.refresh();
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('Lokasi simpan'),
                subtitle: const Text(
                  'Movies / Music / Pictures / Download → folder BulkDL',
                ),
              ),
              section('Jaringan'),
              ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: const Text('DNS'),
                subtitle: Text(q.dnsMode.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _dnsDialog(context),
              ),
              ListTile(
                leading: const Icon(Icons.cookie_outlined),
                title: const Text('Cookie login per situs'),
                subtitle: Text(
                  q.scraper.cookies.isEmpty
                      ? 'Belum ada'
                      : q.scraper.cookies.keys.join(', '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _cookieDialog(context),
              ),
              section('Tampilan'),
              ListTile(
                title: const Text('Tema'),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('Sistem')),
                      ButtonSegment(value: ThemeMode.light, label: Text('Terang')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Gelap')),
                    ],
                    selected: {app.themeMode},
                    onSelectionChanged: (s) => app.setThemeMode(s.first),
                  ),
                ),
              ),
              SwitchListTile(
                title: const Text('Warna dinamis'),
                subtitle: const Text(
                  'Ikuti warna wallpaper (Android 12+). Mati = hijau bawaan',
                ),
                value: app.dynamicColor,
                onChanged: app.setDynamicColor,
              ),
              section('Tentang'),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Bulk DL'),
                subtitle: Text(
                  'Unduh hanya konten yang kamu berhak simpan. Kamu bertanggung jawab atas penggunaan dan hak cipta.',
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _dnsDialog(BuildContext context) async {
  final app = AppScope.read(context);
  var mode = app.queue.dnsMode;
  final ctl = TextEditingController(text: app.queue.dnsCustom);
  String? result;
  var testing = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('DNS'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DNS-over-HTTPS membantu saat ISP memblokir situs lewat DNS. Tidak bisa menembus blokir IP/SNI.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              RadioGroup<DnsMode>(
                groupValue: mode,
                onChanged: (v) => setS(() => mode = v ?? mode),
                child: Column(
                  children: [
                    for (final m in DnsMode.values)
                      RadioListTile<DnsMode>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: m,
                        title: Text(m.label),
                      ),
                  ],
                ),
              ),
              if (mode == DnsMode.custom)
                TextField(
                  controller: ctl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    hintText: 'https://host/dns-query',
                  ),
                ),
              if (result != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(result!),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: testing
                ? null
                : () async {
                    setS(() {
                      testing = true;
                      result = 'Menguji...';
                    });
                    final r = DnsResolver()
                      ..mode = mode
                      ..custom = ctl.text.trim();
                    try {
                      final ips = await r.resolve('example.com');
                      result = 'OK lewat ${r.lastProvider}: ${ips.first}';
                    } catch (e) {
                      result = 'Gagal: ${friendlyError(e)}';
                    }
                    setS(() => testing = false);
                  },
            child: const Text('Tes'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    ),
  );
  if (ok == true) {
    await app.queue.setDns(mode, ctl.text);
    app.refresh();
  }
}

Future<void> _cookieDialog(BuildContext context) async {
  final app = AppScope.read(context);
  final q = app.queue;
  final first = Uri.tryParse(app.urlCtl.text.trim())?.host ?? '';
  final host = TextEditingController(text: first);
  final cookie = TextEditingController(text: q.scraper.cookies[first] ?? '');
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('Cookie login'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tempel header Cookie dari browser yang sudah login agar link HD terbuka. Disimpan hanya di perangkat ini dan hanya dikirim ke situs itu sendiri.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: host,
                decoration: const InputDecoration(labelText: 'Host (mis. www.situs.com)'),
                onChanged: (v) => setS(() {
                  cookie.text = q.scraper.cookies[v.trim()] ?? '';
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cookie,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Cookie',
                  hintText: 'name=value; name2=value2',
                ),
              ),
              if (q.scraper.cookies.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final h in q.scraper.cookies.keys)
                      InputChip(
                        label: Text(h),
                        onPressed: () => setS(() {
                          host.text = h;
                          cookie.text = q.scraper.cookies[h] ?? '';
                        }),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              cookie.clear();
              Navigator.pop(ctx, true);
            },
            child: const Text('Hapus'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    ),
  );
  if (saved == true && host.text.trim().isNotEmpty) {
    await q.setCookie(host.text.trim(), cookie.text);
    app.refresh();
  }
}
