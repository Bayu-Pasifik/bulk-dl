import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../queue.dart';

String _ql(int? q) => (q == null || q == 0) ? '' : ' · ${q}p';

class TaskTile extends StatelessWidget {
  const TaskTile(this.t, this.q, {super.key});
  final Task t;
  final DownloadQueue q;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final s = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: t,
      builder: (context, _) {
        final active =
            t.status == Status.downloading || t.status == Status.resolving;
        final (label, color, icon) = switch (t.status) {
          Status.waiting => (
            s.taskWaiting,
            cs.onSurfaceVariant,
            Icons.schedule,
          ),
          Status.resolving => (
            s.taskPreparing,
            cs.onSurfaceVariant,
            Icons.hourglass_top,
          ),
          Status.downloading => (
            '${(t.progress * 100).toStringAsFixed(0)}%${_ql(t.quality)}'
                '${t.speed > 0 ? ' · ${formatSpeed(t.speed)}' : ''}',
            cs.primary,
            Icons.downloading,
          ),
          Status.done => (
            '${s.taskDone}${_ql(t.quality)}',
            cs.primary,
            Icons.check_circle,
          ),
          Status.failed => (s.taskFailed(t.error ?? ''), cs.error, Icons.error),
          Status.canceled => (s.taskCanceled, cs.tertiary, Icons.pause_circle),
        };
        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(icon, size: 16, color: color),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodySmall?.copyWith(
                                color: color,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (active) ...[
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: t.status == Status.downloading
                              ? t.progress
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                if (active || t.status == Status.waiting)
                  IconButton(
                    tooltip: s.taskCancel,
                    icon: const Icon(Icons.close),
                    onPressed: () => q.cancel(t),
                  )
                else if (t.status == Status.failed ||
                    t.status == Status.canceled)
                  IconButton.filledTonal(
                    tooltip: s.taskRetry,
                    icon: const Icon(Icons.refresh),
                    onPressed: () => q.retry(t),
                  )
                else if (t.file?.startsWith('content://') ?? false)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filled(
                        tooltip: s.taskOpen,
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () => q.lib.open(t.file!),
                      ),
                      IconButton(
                        tooltip: s.taskShare,
                        icon: const Icon(Icons.share),
                        onPressed: () => q.lib.share(t.file!),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
