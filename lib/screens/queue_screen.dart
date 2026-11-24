import 'package:material_ui/material_ui.dart';

import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../queue.dart';
import '../queue_filter.dart';
import '../widgets/task_tile.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});
  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  String _query = '';
  QueueFilter _filter = QueueFilter.all;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final q = app.queue;
    return ListenableBuilder(
      listenable: q,
      builder: (context, _) {
        final s = AppLocalizations.of(context);
        final cs = Theme.of(context).colorScheme;
        final st = q.stats();
        final busy = st.active + st.waiting > 0;
        final shown = filterTasks(q.tasks, _query, _filter);
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: Text(s.queueTitle),
                actions: [
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'clear') q.clearFinished();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'clear',
                        child: Text(s.queueClearFinished),
                      ),
                    ],
                  ),
                ],
              ),
              if (busy)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  sliver: SliverToBoxAdapter(
                    child: _Summary(
                      st,
                      q.blocked
                          ? (q.blockedByWifi
                                ? s.queuePausedWifi
                                : s.queuePausedSchedule)
                          : null,
                    ),
                  ),
                ),
              if (q.tasks.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          onChanged: (v) => setState(() => _query = v),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: s.queueSearch,
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(28),
                              ),
                            ),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final f in QueueFilter.values)
                              ChoiceChip(
                                label: Text(switch (f) {
                                  QueueFilter.all => s.filterAll,
                                  QueueFilter.active => s.filterActive,
                                  QueueFilter.done => s.filterDone,
                                  QueueFilter.failed => s.filterFailed,
                                }),
                                selected: _filter == f,
                                onSelected: (_) => setState(() => _filter = f),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (q.tasks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: cs.outline),
                        const SizedBox(height: 12),
                        Text(
                          s.queueEmpty,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                )
              else if (shown.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text(s.queueNoMatch)),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  sliver: SliverList.separated(
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => TaskTile(shown[i], q),
                  ),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => app.tab.value = 0,
            icon: const Icon(Icons.add_link),
            label: Text(s.queueAdd),
          ),
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary(this.st, this.pausedMsg);
  final QueueStats st;
  final String? pausedMsg;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final s = AppLocalizations.of(context);
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${(st.fraction * 100).toStringAsFixed(0)}%',
                  style: tt.headlineMedium?.copyWith(
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      st.speed > 0 ? formatSpeed(st.speed) : '--',
                      style: tt.titleMedium?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'ETA ${st.eta == null ? '--:--' : formatEta(st.eta!)}',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              s.queueCounts(st.active, st.waiting),
              style: tt.bodyMedium?.copyWith(color: cs.onPrimaryContainer),
            ),
            if (pausedMsg != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  pausedMsg!,
                  style: tt.labelLarge?.copyWith(color: cs.error),
                ),
              ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: st.fraction),
          ],
        ),
      ),
    );
  }
}
