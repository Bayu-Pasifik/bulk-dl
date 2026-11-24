part of 'settings_screen.dart';

Future<void> _proxyDialog(BuildContext context) async {
  final app = AppScope.read(context);
  final s = AppLocalizations.of(context);
  final cur = app.queue.proxy;
  var enabled = cur.enabled;
  var type = cur.type;
  final host = TextEditingController(text: cur.host);
  final port = TextEditingController(text: cur.port > 0 ? '${cur.port}' : '');
  final user = TextEditingController(text: cur.user);
  final pass = TextEditingController(text: cur.pass);
  final link = TextEditingController();
  String? note;
  var testing = false;

  ProxyConfig build() => ProxyConfig(
    enabled: enabled,
    type: type,
    host: host.text.trim(),
    port: int.tryParse(port.text.trim()) ?? 0,
    user: user.text,
    pass: pass.text,
  );

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text(s.settingsProxy),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.proxyHelp, style: Theme.of(ctx).textTheme.bodySmall),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.proxyUse),
                value: enabled,
                onChanged: (v) => setS(() => enabled = v),
              ),
              SegmentedButton<ProxyType>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ProxyType.http, label: Text('HTTP')),
                  ButtonSegment(value: ProxyType.socks5, label: Text('SOCKS5')),
                ],
                selected: {type},
                onSelectionChanged: (v) => setS(() => type = v.first),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: link,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(hintText: s.proxyPaste),
                onChanged: (v) {
                  final c = ProxyConfig.parse(v);
                  setS(() {
                    if (c == null) {
                      note = v.trim().isEmpty ? null : s.proxyBadLink;
                      return;
                    }
                    note = null;
                    type = c.type;
                    host.text = c.host;
                    port.text = '${c.port}';
                    user.text = c.user;
                    pass.text = c.pass;
                  });
                },
              ),
              TextField(
                controller: host,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(labelText: s.proxyHost),
              ),
              TextField(
                controller: port,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: s.proxyPort),
              ),
              TextField(
                controller: user,
                decoration: InputDecoration(labelText: s.proxyUser),
              ),
              TextField(
                controller: pass,
                obscureText: true,
                decoration: InputDecoration(labelText: s.proxyPass),
              ),
              if (note != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(note!),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: testing
                ? null
                : () async {
                    final c = build().copyWith(enabled: true);
                    if (!c.usable) {
                      setS(() => note = s.proxyTestFail('host/port'));
                      return;
                    }
                    setS(() {
                      testing = true;
                      note = s.proxyTesting;
                    });
                    final prev = ProxySettings.instance.config;
                    ProxySettings.instance.config = c;
                    try {
                      final r = await createDio().get<String>(
                        'https://www.cloudflare.com/cdn-cgi/trace',
                        options: Options(responseType: ResponseType.plain),
                      );
                      final ip = RegExp(r'ip=(\S+)').firstMatch(r.data ?? '');
                      note = s.proxyTestOk(ip?.group(1) ?? '?');
                    } catch (e) {
                      note = s.proxyTestFail(friendlyError(e));
                    } finally {
                      ProxySettings.instance.config = prev;
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
    await app.queue.setProxy(build());
    app.refresh();
  }
}

Future<void> _vpnDialog(BuildContext context) async {
  final app = AppScope.read(context);
  final s = AppLocalizations.of(context);
  final q = app.queue;
  final ctl = TextEditingController(text: q.wgConfig);
  var auto = q.wgAutoConnect;
  String? note;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final up = q.vpnUp;
        final err = q.vpnError;
        return AlertDialog(
          title: Text(s.settingsVpn),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.vpnHelp, style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(up ? Icons.vpn_lock : Icons.vpn_key_outlined),
                    const SizedBox(width: 8),
                    Text(up ? s.vpnConnected : s.vpnDisconnected),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ctl,
                  minLines: 4,
                  maxLines: 8,
                  enabled: !up,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: InputDecoration(
                    labelText: s.vpnConfigLabel,
                    alignLabelWithHint: true,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.content_paste),
                  label: Text(s.vpnImport),
                  onPressed: up
                      ? null
                      : () async {
                          final d = await Clipboard.getData('text/plain');
                          if (d?.text != null) setS(() => ctl.text = d!.text!);
                        },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.vpnAuto),
                  value: auto,
                  onChanged: (v) {
                    setS(() => auto = v);
                    q.setWgConfig(ctl.text, auto: v);
                  },
                ),
                if (note != null || err != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(note ?? s.vpnFailed(err!)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: q.vpnBusy
                  ? null
                  : () async {
                      if (!up) {
                        final c = checkWgConfig(ctl.text);
                        if (!c.ok) {
                          setS(() => note = s.vpnInvalid(c.error!));
                          return;
                        }
                        await q.setWgConfig(ctl.text, auto: auto);
                      }
                      setS(() => note = null);
                      final f = q.setVpn(!up);
                      setS(() {});
                      await f;
                      setS(() {});
                      app.refresh();
                    },
              child: Text(up ? s.vpnDisconnect : s.vpnConnect),
            ),
          ],
        );
      },
    ),
  );
  app.refresh();
}
