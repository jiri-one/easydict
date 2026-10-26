import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/dictionary.dart';
import '../l10n/app_localizations.dart';
import '../version.dart';
import 'logo.dart';

const websiteUrl = 'https://easydict.jiri.one';
const sourceUrl = 'https://github.com/jiri-one/easydict';

/// The notices the GNU FDL licence of the dictionary asks to keep.
const dictionaryNotices = '''
Založeno na svobodném anglicko-českém slovníku, https://www.svobodneslovniky.cz/
Copyright © 2016–2021 xHire
Založeno na projektu GNU/FDL Anglicko-Český slovník, http://slovnik.zcu.cz
Copyright © 2001–2003 Milan Svoboda''';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key, required this.dictionary});

  final Dictionary dictionary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final authors =
        (jsonDecode(dictionary.meta['authors'] ?? '[]') as List<Object?>)
            .map((item) => (item! as List<Object?>).first! as String)
            .toList();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.about)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          const Center(child: Logo(size: 96)),
          const SizedBox(height: 16),
          Text(
            l10n.appTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          Text(
            l10n.version(appVersion),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.slogan, textAlign: TextAlign.center),
          ),
          ListTile(
            leading: const Icon(Icons.public),
            title: Text(l10n.website),
            subtitle: const Text(websiteUrl),
            onTap: () => launchUrl(Uri.parse(websiteUrl)),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(l10n.sourceCode),
            subtitle: const Text(sourceUrl),
            onTap: () => launchUrl(Uri.parse(sourceUrl)),
          ),
          ListTile(
            leading: const Icon(Icons.gavel),
            title: Text(l10n.licenses),
            subtitle: const Text(
              'GNU GPL 3, GNU FDL 1.1, GNU GPL 2, CC BY-SA 4.0',
            ),
            onTap: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
              applicationVersion: appVersion,
              applicationIcon: const Padding(
                padding: EdgeInsets.all(8),
                child: Logo(size: 48),
              ),
              applicationLegalese: '© 2020–2026 Jiří Němec\nGNU GPL 3',
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.dictionaryData,
              style: theme.textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l10n.dataCredits),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              dictionaryNotices,
              style: theme.textTheme.bodySmall,
            ),
          ),
          ExpansionTile(
            title: Text('${l10n.translators} (${authors.length})'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [SelectableText(authors.join(', '))],
          ),
        ],
      ),
    );
  }
}
