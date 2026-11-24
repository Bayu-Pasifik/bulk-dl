import 'package:material_ui/material_ui.dart';

import '../app_scope.dart';
import '../app_state.dart';
import '../l10n/app_localizations.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _go(BuildContext context) async {
    final app = AppScope.read(context);
    FocusScope.of(context).unfocus();
    final r = await app.fetch();
    if (r == FetchResult.picker) app.openPicker();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final s = AppLocalizations.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(title: Text(s.appTitle)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList.list(
              children: [
                Text(
                  s.homeIntro,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: app.urlCtl,
                  minLines: 1,
                  maxLines: 4,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: s.linkLabel,
                    hintText: s.linkHint,
                    prefixIcon: const Icon(Icons.link),
                    suffixIcon: IconButton(
                      tooltip: s.paste,
                      icon: const Icon(Icons.content_paste),
                      onPressed: app.paste,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<FetchMode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: FetchMode.auto,
                      label: Text(s.modeAuto),
                      icon: Icon(Icons.auto_awesome),
                    ),
                    ButtonSegment(
                      value: FetchMode.single,
                      label: Text(s.modeSingle),
                      icon: Icon(Icons.insert_drive_file_outlined),
                    ),
                    ButtonSegment(
                      value: FetchMode.playlist,
                      label: Text(s.modePlaylist),
                      icon: Icon(Icons.video_library_outlined),
                    ),
                  ],
                  selected: {app.mode},
                  onSelectionChanged: (s) => app.setMode(s.first),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: app.loading ? null : () => _go(context),
                  icon: app.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(
                    app.loading ? s.processing : s.analyzeAndDownload,
                  ),
                ),
                if (app.message != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: app.messageIsError
                        ? cs.errorContainer
                        : cs.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(
                            app.messageIsError
                                ? Icons.error_outline
                                : Icons.info_outline,
                            color: app.messageIsError
                                ? cs.onErrorContainer
                                : cs.onSecondaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              app.message!,
                              style: tt.bodyMedium?.copyWith(
                                color: app.messageIsError
                                    ? cs.onErrorContainer
                                    : cs.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (app.videos.isNotEmpty && !app.loading) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: app.openPicker,
                    icon: const Icon(Icons.checklist),
                    label: Text(s.viewVideos(app.videos.length)),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: Text(s.maxQuality, style: tt.titleMedium)),
                    DropdownMenu<int>(
                      initialSelection: app.queue.maxQuality,
                      width: 140,
                      requestFocusOnTap: false,
                      dropdownMenuEntries: [
                        for (final q in const [
                          240,
                          360,
                          480,
                          720,
                          1080,
                          1440,
                          2160,
                        ])
                          DropdownMenuEntry(value: q, label: '${q}p'),
                      ],
                      onSelected: (q) {
                        if (q != null) {
                          app.queue.maxQuality = q;
                          app.refresh();
                        }
                      },
                    ),
                  ],
                ),
                if (app.recent.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(s.recentTitle, style: tt.titleMedium),
                      ),
                      TextButton(
                        onPressed: app.clearRecent,
                        child: Text(s.delete),
                      ),
                    ],
                  ),
                  for (final u in app.recent)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history),
                      title: Text(
                        u,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        app.urlCtl.text = u;
                        app.refresh();
                      },
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
