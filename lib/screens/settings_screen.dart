import 'package:dio/dio.dart' show Options, ResponseType;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../net/dns.dart';
import '../net/errors.dart';
import '../net/http_factory.dart';
import '../net/proxy.dart';
import '../net/vpn.dart';
import '../update.dart';
import 'sites_screen.dart';

part 'network_dialogs.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final q = app.queue;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final s = AppLocalizations.of(context);
    Widget section(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(t, style: tt.titleSmall?.copyWith(color: cs.primary)),
    );
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(title: Text(s.settingsTitle)),
          SliverList.list(
            children: [
              section(s.settingsDownloads),
              ListTile(
                title: Text(s.maxQuality),
                trailing: DropdownMenu<int>(
                  initialSelection: q.maxQuality,
                  width: 130,
                  requestFocusOnTap: false,
                  dropdownMenuEntries: [
                    for (final v in const [
                      240,
                      360,
                      480,
                      720,
                      1080,
                      1440,
                      2160,
                    ])
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
                title: Text(s.settingsParallel),
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
              ListTile(
                title: Text(s.settingsConnections),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.settingsConnectionsSub),
                    Slider(
                      value: q.connections.toDouble(),
                      min: 1,
                      max: 64,
                      divisions: 63,
                      label: '${q.connections}',
                      onChanged: (v) {
                        q.connections = v.round();
                        app.refresh();
                      },
                    ),
                  ],
                ),
                trailing: Text('${q.connections}', style: tt.titleMedium),
              ),
              ListTile(
                title: Text(s.settingsMaxPages),
                subtitle: Text(s.settingsMaxPagesSub),
                trailing: DropdownMenu<int>(
                  initialSelection: q.maxPages,
                  width: 110,
                  requestFocusOnTap: false,
                  dropdownMenuEntries: [
                    for (final v in const [1, 3, 5, 10, 20, 50, 100])
                      DropdownMenuEntry(value: v, label: '$v'),
                  ],
                  onSelected: (v) {
                    if (v != null) {
                      q.maxPages = v;
                      app.refresh();
                    }
                  },
                ),
              ),
              SwitchListTile(
                title: Text(s.settingsWifiOnly),
                subtitle: Text(s.settingsWifiOnlySub),
                value: q.wifiOnly,
                onChanged: (v) {
                  q.wifiOnly = v;
                  app.refresh();
                },
              ),
              SwitchListTile(
                title: Text(s.settingsSchedule),
                subtitle: Text(s.settingsScheduleSub),
                value: q.scheduleOn,
                onChanged: (v) {
                  q.setSchedule(on: v);
                  app.refresh();
                },
              ),
              if (q.scheduleOn)
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: Text(s.settingsScheduleFrom),
                        subtitle: Text(_hm(q.scheduleStart)),
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: _tod(q.scheduleStart),
                          );
                          if (t != null) {
                            q.setSchedule(start: t.hour * 60 + t.minute);
                            app.refresh();
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        title: Text(s.settingsScheduleTo),
                        subtitle: Text(_hm(q.scheduleEnd)),
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: _tod(q.scheduleEnd),
                          );
                          if (t != null) {
                            q.setSchedule(end: t.hour * 60 + t.minute);
                            app.refresh();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(s.settingsSaveLocation),
                subtitle: Text(s.settingsSaveLocationSub),
              ),
              section(s.settingsNetwork),
              ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: Text(s.settingsDns),
                subtitle: Text(q.dnsMode.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _dnsDialog(context),
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text(s.settingsProxy),
                subtitle: Text(
                  q.proxy.usable
                      ? '${q.proxy.type == ProxyType.socks5 ? "SOCKS5" : "HTTP"} '
                            '${q.proxy.host}:${q.proxy.port}'
                      : s.proxyOff,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _proxyDialog(context),
              ),
              ListTile(
                leading: Icon(
                  q.vpnUp ? Icons.vpn_lock : Icons.vpn_key_outlined,
                ),
                title: Text(s.settingsVpn),
                subtitle: Text(
                  q.vpnUp
                      ? s.vpnConnected
                      : (q.wgConfig.isEmpty
                            ? s.vpnNoConfig
                            : s.vpnDisconnected),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _vpnDialog(context),
              ),
              ListTile(
                leading: const Icon(Icons.cookie_outlined),
                title: Text(s.settingsCookies),
                subtitle: Text(
                  q.scraper.cookies.isEmpty
                      ? s.settingsCookiesNone
                      : q.scraper.cookies.keys.join(', '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _cookieDialog(context),
              ),
              section(s.settingsAppearance),
              ListTile(
                title: Text(s.settingsTheme),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(s.themeSystem),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(s.themeLight),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(s.themeDark),
                      ),
                    ],
                    selected: {app.themeMode},
                    onSelectionChanged: (s) => app.setThemeMode(s.first),
                  ),
                ),
              ),
              SwitchListTile(
                title: Text(s.settingsDynamic),
                subtitle: Text(s.settingsDynamicSub),
                value: app.dynamicColor,
                onChanged: app.setDynamicColor,
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(s.settingsLanguage),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: '', label: Text(s.langSystem)),
                      ButtonSegment(value: 'en', label: Text(s.langEnglish)),
                      ButtonSegment(value: 'id', label: Text(s.langIndonesian)),
                    ],
                    selected: {app.locale?.languageCode ?? ''},
                    onSelectionChanged: (v) =>
                        app.setLocale(v.first.isEmpty ? null : Locale(v.first)),
                  ),
                ),
              ),
              section(s.settingsAbout),
              ListTile(
                leading: const Icon(Icons.public),
                title: Text(s.sitesTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SitesScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.system_update_alt),
                title: Text(s.updateCheck),
                subtitle: FutureBuilder<String>(
                  future: Updater.currentVersion(),
                  builder: (_, v) => Text(s.updateVersion(v.data ?? '')),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _checkUpdate(context),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(s.appTitle),
                subtitle: Text(s.aboutText),
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
  final s = AppLocalizations.of(context);
  var mode = app.queue.dnsMode;
  final ctl = TextEditingController(text: app.queue.dnsCustom);
  String? result;
  var testing = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text(s.settingsDns),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.dnsHelp, style: Theme.of(ctx).textTheme.bodySmall),
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
                      result = s.dnsTesting;
                    });
                    final r = DnsResolver()
                      ..mode = mode
                      ..custom = ctl.text.trim();
                    try {
                      final ips = await r.resolve('example.com');
                      result = s.dnsOk(
                        r.lastProvider ?? '',
                        ips.first.toString(),
                      );
                    } catch (e) {
                      result = s.dnsFailed(friendlyError(e));
                    }
                    setS(() => testing = false);
                  },
            child: Text(s.test),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.save),
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
  final s = AppLocalizations.of(context);
  final q = app.queue;
  final first = Uri.tryParse(app.urlCtl.text.trim())?.host ?? '';
  final host = TextEditingController(text: first);
  final cookie = TextEditingController(text: q.scraper.cookies[first] ?? '');
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text(s.cookieTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.cookieHelp, style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 12),
              TextField(
                controller: host,
                decoration: InputDecoration(labelText: s.cookieHost),
                onChanged: (v) => setS(() {
                  cookie.text = q.scraper.cookies[v.trim()] ?? '';
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cookie,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: s.cookieLabel,
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
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () {
              cookie.clear();
              Navigator.pop(ctx, true);
            },
            child: Text(s.delete),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.save),
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

Future<void> _checkUpdate(BuildContext context) async {
  final app = AppScope.read(context);
  final s = AppLocalizations.of(context);
  final msg = ScaffoldMessenger.of(context);
  msg.showSnackBar(
    SnackBar(
      content: Text(s.updateChecking),
      duration: const Duration(minutes: 1),
    ),
  );
  try {
    final u = await Updater.check(app.scraper.dio);
    msg.hideCurrentSnackBar();
    if (u == null) {
      msg.showSnackBar(SnackBar(content: Text(s.updateUpToDate)));
      return;
    }
    if (!context.mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.updateAvailable(u.version)),
        content: u.notes.isEmpty && u.sha256 == null
            ? null
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (u.notes.isNotEmpty) Text(u.notes),
                    if (u.sha256 != null) ...[
                      Text(s.updateSha256),
                      const SizedBox(height: 4),
                      SelectableText(
                        u.sha256!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.updateLater),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.updateDownload),
          ),
        ],
      ),
    );
    if (go == true) await Updater.openUrl(u.url);
  } catch (e) {
    msg.hideCurrentSnackBar();
    msg.showSnackBar(SnackBar(content: Text(s.updateFailed(friendlyError(e)))));
  }
}

String _hm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

TimeOfDay _tod(int minutes) =>
    TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
