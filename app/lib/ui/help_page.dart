import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/notes.dart';
import '../l10n/app_localizations.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final czech = Localizations.localeOf(context).languageCode == 'cs';
    Widget section(String title, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.help)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          section(l10n.speak, l10n.helpSpeech),
          section(l10n.helpModesTitle, l10n.helpModes),
          section(l10n.helpFormsTitle, l10n.helpForms),
          section(
            l10n.helpTipsTitle,
            [
              if (kIsWeb) ...[
                l10n.helpTips,
                l10n.helpTipsWeb,
              ] else ...[
                '${l10n.helpTips} ${l10n.helpTipsOffline}',
                if (defaultTargetPlatform == TargetPlatform.android)
                  l10n.helpTipsAndroid
                else
                  l10n.helpTipsDesktop,
              ],
            ].join('\n\n'),
          ),
          Text(l10n.helpLabelsTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final (label, (cs, en)) in noteExplanations)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 104,
                    child: Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  ),
                  Expanded(child: Text(czech ? cs : en)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
