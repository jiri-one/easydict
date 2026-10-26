import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/dictionary.dart';
import 'data/open_dictionary.dart';
import 'l10n/app_localizations.dart';
import 'settings.dart';
import 'ui/home_page.dart';
import 'ui/logo.dart';

/// The EasyDict blue of the logo.
const brandColor = Color(0xFF387FF2);

ThemeData appTheme(Brightness brightness) {
  final colors = ColorScheme.fromSeed(
    seedColor: brandColor,
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: colors,
    // The pale default fill of the selected segment vanishes on black-and-white
    // e-ink. The unselected colour must be set too, or it falls back to blue.
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        foregroundColor: colors.onSurface,
        selectedForegroundColor: colors.onSecondary,
        selectedBackgroundColor: colors.secondary,
      ),
    ),
  );
}

class EasyDictApp extends StatelessWidget {
  const EasyDictApp({
    super.key,
    required this.settings,
    this.initialQuery = '',
  });

  final Settings settings;
  final String initialQuery;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      themeMode: settings.themeMode,
      locale: settings.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: _DictionaryLoader(settings: settings, initialQuery: initialQuery),
    ),
  );
}

class _DictionaryLoader extends StatefulWidget {
  const _DictionaryLoader({required this.settings, required this.initialQuery});

  final Settings settings;
  final String initialQuery;

  @override
  State<_DictionaryLoader> createState() => _DictionaryLoaderState();
}

class _DictionaryLoaderState extends State<_DictionaryLoader> {
  // the web app may not reach the server
  late Future<Dictionary> _dictionary = openDictionary();

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _dictionary,
    builder: (context, snapshot) {
      final l10n = AppLocalizations.of(context);
      if (snapshot.hasData) {
        return HomePage(
          dictionary: snapshot.data!,
          settings: widget.settings,
          initialQuery: widget.initialQuery,
        );
      }
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Logo(size: 96),
                const SizedBox(height: 24),
                if (snapshot.hasError) ...[
                  Text(l10n.openError),
                  const SizedBox(height: 8),
                  SelectableText(
                    '${snapshot.error}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () =>
                        setState(() => _dictionary = openDictionary()),
                    child: Text(l10n.retry),
                  ),
                ] else ...[
                  Text(l10n.loading),
                  const SizedBox(height: 16),
                  const SizedBox(width: 160, child: LinearProgressIndicator()),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
