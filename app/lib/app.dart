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
  final foreground = brightness == Brightness.light
      ? Colors.black
      : Colors.white;
  final background = brightness == Brightness.light
      ? Colors.white
      : Colors.black;
  final colors =
      ColorScheme.fromSeed(
        seedColor: brandColor,
        brightness: brightness,
      ).copyWith(
        primary: foreground,
        onPrimary: background,
        secondary: foreground,
        onSecondary: background,
        secondaryContainer: background,
        onSecondaryContainer: foreground,
        surface: background,
        onSurface: foreground,
        onSurfaceVariant: foreground,
        outline: foreground,
        outlineVariant: foreground,
        surfaceContainerLowest: background,
        surfaceContainerLow: background,
        surfaceContainer: background,
        surfaceContainerHigh: background,
        surfaceContainerHighest: background,
        surfaceTint: Colors.transparent,
      );
  return ThemeData(
    colorScheme: colors,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    expansionTileTheme: const ExpansionTileThemeData(
      expansionAnimationStyle: AnimationStyle.noAnimation,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        animationDuration: Duration.zero,
        foregroundColor: foreground,
        side: BorderSide(color: foreground),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(animationDuration: Duration.zero),
    ),
    // Filled selection stays visible on monochrome displays.
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        animationDuration: Duration.zero,
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
      themeAnimationDuration: Duration.zero,
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
                  OutlinedButton(
                    onPressed: () =>
                        setState(() => _dictionary = openDictionary()),
                    child: Text(l10n.retry),
                  ),
                ] else
                  Text(l10n.loading),
              ],
            ),
          ),
        ),
      );
    },
  );
}
