import 'package:material_ui/material_ui.dart';

import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../queue.dart';
import '../widgets/task_tile.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

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
                      PopupMenuItem(value: 'clear', child: Text(s.queueClearFinished)),
                    ],
                  ),
                ],
              ),
              if (busy)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  sliver: SliverToBoxAdapter(child: _Summary(st, q.blocked)),
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
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  sliver: SliverList.separated(
                    itemCount: q.tasks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => TaskTile(q.tasks[i], q),
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
  const _Summary(this.st, this.paused);
  final QueueStats st;
  final bool paused;

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
            if (paused)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  s.queuePausedWifi,
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
