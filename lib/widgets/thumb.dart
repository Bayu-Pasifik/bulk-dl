import 'package:material_ui/material_ui.dart';

/// Small rounded video thumbnail with a neutral placeholder.
class VideoThumb extends StatelessWidget {
  const VideoThumb(this.url, {super.key, this.width = 96, this.height = 64});
  final String? url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ph = ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.movie_outlined, color: cs.onSurfaceVariant),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: width,
        height: height,
        child: url == null
            ? ph
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ph,
              ),
      ),
    );
  }
}
