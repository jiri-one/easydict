import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/dictionary.dart';
import '../l10n/app_localizations.dart';
import '../settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.settings});

  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final desktop =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          children: [
            _Section(l10n.settingsSearch),
            _Choice<Language>(
              title: l10n.defaultLanguage,
              value: settings.language,
              options: {Language.eng: l10n.english, Language.cze: l10n.czech},
              onChanged: (value) => settings.language = value,
            ),
            _Choice<SearchMode>(
              title: l10n.defaultMode,
              value: settings.mode,
              options: {
                SearchMode.startsWith: l10n.modeStartsWith,
                SearchMode.wholeWord: l10n.modeWholeWord,
                SearchMode.fulltext: l10n.modeFulltext,
              },
              onChanged: (value) => settings.mode = value,
            ),
            if (desktop)
              SwitchListTile(
                title: Text(l10n.clipboardLookup),
                subtitle: Text(l10n.clipboardLookupHint),
                value: settings.clipboardLookup,
                onChanged: (value) => settings.clipboardLookup = value,
              ),
            _Section(l10n.settingsAppearance),
            _Choice<ThemeMode>(
              title: l10n.theme,
              value: settings.themeMode,
              options: {
                ThemeMode.system: l10n.themeSystem,
                ThemeMode.light: l10n.themeLight,
                ThemeMode.dark: l10n.themeDark,
              },
              onChanged: (value) => settings.themeMode = value,
            ),
            _Choice<String>(
              title: l10n.appLanguage,
              value: settings.locale?.languageCode ?? '',
              options: {
                '': l10n.systemLanguage,
                'cs': 'Čeština',
                'en': 'English',
              },
              onChanged: (value) =>
                  settings.locale = value.isEmpty ? null : Locale(value),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(title),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SegmentedButton<T>(
        showSelectedIcon: false,
        segments: [
          for (final MapEntry(:key, value: label) in options.entries)
            ButtonSegment(value: key, label: Text(label)),
        ],
        selected: {value},
        onSelectionChanged: (selection) => onChanged(selection.single),
      ),
    ),
  );
}
