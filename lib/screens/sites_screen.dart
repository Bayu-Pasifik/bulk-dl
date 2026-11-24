import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../sites.dart';

class SitesScreen extends StatelessWidget {
  const SitesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(s.sitesTitle)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(s.sitesHint, style: tt.bodySmall),
          ),
          for (final site in supportedSites)
            ListTile(
              leading: _SiteLogo(site),
              title: Text(site.name),
              subtitle: SelectableText(site.url),
              trailing: const Icon(Icons.copy_outlined, size: 20),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: site.url));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(s.sitesCopied)));
              },
            ),
        ],
      ),
    );
  }
}

/// Site favicon, falling back to a letter avatar when it can't be loaded.
class _SiteLogo extends StatelessWidget {
  const _SiteLogo(this.site);
  final SupportedSite site;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fallback = Center(
      child: Text(
        site.name[0],
        style: TextStyle(
          color: cs.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return Container(
      width: 40,
      height: 40,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Image.network(
        'https://www.${site.host}/favicon.ico',
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (_, child, p) => p == null ? child : fallback,
      ),
    );
  }
}
