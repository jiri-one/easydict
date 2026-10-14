import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/dictionary.dart';
import 'data/open_dictionary.dart';
import 'l10n/app_localizations.dart';
import 'settings.dart';
import 'ui/home_page.dart';

/// The EasyDict blue of the logo.
const brandColor = Color(0xFF387FF2);

class EasyDictApp extends StatelessWidget {
  const EasyDictApp({
    super.key,
    required this.settings,
    this.initialQuery = '',
    this.pageTheme,
  });

  final Settings settings;
  final String initialQuery;

  /// On the web, the colour switch of the page instead of the setting.
  final ValueListenable<ThemeMode>? pageTheme;

  ThemeData _theme(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: brandColor,
      brightness: brightness,
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([settings, ?pageTheme]),
    builder: (context, _) => MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: pageTheme?.value ?? settings.themeMode,
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
                Image.asset('assets/images/logo.png', width: 96, height: 96),
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
