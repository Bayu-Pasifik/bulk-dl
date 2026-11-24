import 'package:material_ui/material_ui.dart';

import '../app_scope.dart';
import '../app_state.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../widgets/thumb.dart';

/// Result of a playlist: choose videos, then send them to the queue.
class PickerScreen extends StatelessWidget {
  const PickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final s = AppLocalizations.of(context);
    final items = app.visible;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(s.msgVideoCount(app.videos.length)),
            actions: [
              IconButton(
                tooltip: s.pickerCalcSizes,
                icon: const Icon(Icons.calculate_outlined),
                onPressed: app.calcSizes,
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverList.list(
              children: [
                TextField(
                  controller: app.searchCtl,
                  onChanged: app.setFilter,
                  decoration: InputDecoration(
                    hintText: s.pickerSearch,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: app.filter.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              app.searchCtl.clear();
                              app.setFilter('');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.tonal(
                      onPressed: app.selectAll,
                      child: Text(s.pickerAll),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: app.selectNone,
                      child: Text(s.pickerNone),
                    ),
                    const Spacer(),
                    Text(
                      s.pickerSelected(app.selected.length),
                      style: tt.labelLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListenableBuilder(
                  listenable: app.scraper,
                  builder: (_, _) => _SizeInfo(app),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _Row(items[i]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: app.selected.isEmpty ? null : app.downloadSelected,
            icon: const Icon(Icons.download),
            label: Text(app.totalLabel()),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.v);
  final VideoItem v;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    app.scraper.ensure(v);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final on = app.selected.contains(v.id);
    final have = app.isDownloaded(v);
    return Card(
      color: on ? cs.secondaryContainer : cs.surfaceContainerHigh,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => app.toggle(v),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              VideoThumb(v.thumb),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    ListenableBuilder(
                      listenable: app.scraper,
                      builder: (_, _) => Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Chip(
                            label: Text(app.sizeLabel(v)),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          if (have)
                            Chip(
                              avatar: Icon(
                                Icons.check_circle,
                                size: 16,
                                color: cs.onPrimaryContainer,
                              ),
                              label: Text(
                                AppLocalizations.of(context).alreadyDownloaded,
                              ),
                              backgroundColor: cs.primaryContainer,
                              labelStyle: TextStyle(
                                color: cs.onPrimaryContainer,
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Checkbox(value: on, onChanged: (_) => app.toggle(v)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Size status for the selection: progress while loading, an estimate of the
/// total for sizes not loaded yet, and a button to load them all.
class _SizeInfo extends StatelessWidget {
  const _SizeInfo(this.app);
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final (known, all) = app.sizeProgress;
    final est = app.estimatedTotal;
    if (all == 0 || (known == all && !app.sizesLoading)) {
      return const SizedBox.shrink();
    }
    final text = s.pickerSizeProgress(known, all);
    return Card(
      color: cs.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    est == null
                        ? text
                        : '$text\n${s.pickerEstimate(formatSize(est))}',
                  ),
                ),
                if (!app.sizesLoading)
                  FilledButton.tonal(
                    onPressed: app.calcSizes,
                    child: Text(s.pickerCalcAll),
                  ),
              ],
            ),
            if (app.sizesLoading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: all == 0 ? null : known / all),
            ],
          ],
        ),
      ),
    );
  }
}
