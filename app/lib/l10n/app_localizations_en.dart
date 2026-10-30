// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'EasyDict';

  @override
  String get appSubtitle => 'Completely open translator';

  @override
  String get searchHint => 'Type a word…';

  @override
  String get clear => 'Clear';

  @override
  String get english => 'English';

  @override
  String get czech => 'Czech';

  @override
  String get searchingEnglish =>
      'Searching English words, tap to switch to Czech';

  @override
  String get searchingCzech =>
      'Searching Czech words, tap to switch to English';

  @override
  String get modeStartsWith => 'Starts with';

  @override
  String get modeWholeWord => 'Whole word';

  @override
  String get modeFulltext => 'Anywhere';

  @override
  String get welcomeTitle => 'Welcome to EasyDict';

  @override
  String get welcomeHint => 'Just start typing to see results.';

  @override
  String get slogan =>
      'The first open-source translator that is completely open, dictionary data included.';

  @override
  String entryCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString translations',
      one: '1 translation',
    );
    return '$_temp0 in the dictionary';
  }

  @override
  String noResults(String query) {
    return 'Nothing found for “$query”.';
  }

  @override
  String get searchAnywhere => 'Search anywhere in the text';

  @override
  String get searchInEnglish => 'Search in English';

  @override
  String get searchInCzech => 'Search in Czech';

  @override
  String baseForms(int count, String forms) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Base forms: $forms',
      one: 'Base form: $forms',
    );
    return '$_temp0';
  }

  @override
  String get truncated =>
      'Only the best matches are shown. Type more to narrow the search.';

  @override
  String get settings => 'Settings';

  @override
  String get help => 'Help';

  @override
  String get about => 'About';

  @override
  String get author => 'Translated by';

  @override
  String lookUp(String word) {
    return 'Look up “$word”';
  }

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied to the clipboard';

  @override
  String get copyError =>
      'Copying failed. You can select the translation and copy it manually.';

  @override
  String get settingsSearch => 'Search';

  @override
  String get defaultLanguage => 'Search in';

  @override
  String get defaultMode => 'Search mode';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get appLanguage => 'App language';

  @override
  String get systemLanguage => 'System';

  @override
  String get clipboardLookup => 'Look up clipboard text';

  @override
  String get clipboardLookupHint =>
      'When the window is activated, look up new single-line text copied to the clipboard (up to 60 characters).';

  @override
  String get helpModesTitle => 'Search modes';

  @override
  String get helpModes =>
      'Starts with – headwords beginning with the typed text.\nWhole word – headwords containing the typed word.\nAnywhere – the typed text anywhere in the headword.';

  @override
  String get helpFormsTitle => 'Word forms';

  @override
  String get helpForms =>
      'You can also type Czech words in other forms: “psa” finds “pes”, “očima” finds “oko”. Diacritics and capital letters do not matter.';

  @override
  String get helpTipsTitle => 'Tips';

  @override
  String get helpTips =>
      'Tap a translation to look it up in the other language or to copy it. The flag next to the search field switches the language.';

  @override
  String get helpTipsOffline => 'EasyDict works offline.';

  @override
  String get helpTipsAndroid =>
      'Select a word in any app and choose “Look up in EasyDict” from the menu.';

  @override
  String get helpTipsWeb =>
      'The address easydict.jiri.one/app?q=WORD looks WORD up right away. EasyDict is also an app for Linux, Windows, macOS and Android, which works offline.';

  @override
  String get helpTipsDesktop =>
      'Start EasyDict as “easydict WORD” to look WORD up right away, e.g. from a keyboard shortcut. In the settings, EasyDict can also look up new single-line text (up to 60 characters) copied to the clipboard when its window is activated.';

  @override
  String get helpLabelsTitle => 'Labels';

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String get website => 'Website';

  @override
  String get sourceCode => 'Source code';

  @override
  String get dictionaryData => 'Dictionary data';

  @override
  String get dataCredits =>
      'The English–Czech dictionary is the free dictionary of the Svobodné slovníky project (GNU FDL 1.1 or later), formerly the GNU/FDL English-Czech Dictionary. Czech word forms come from the Czech Hunspell dictionary (GNU GPL 2) and from Wiktionary (CC BY-SA 4.0). Word frequencies, which put the common translations first, come from wordfreq by Robyn Speer (CC BY-SA 4.0).';

  @override
  String get translators => 'Translators';

  @override
  String get licenses => 'Licenses';

  @override
  String get loading => 'Preparing the dictionary…';

  @override
  String get openError => 'The dictionary could not be opened.';

  @override
  String get retry => 'Try again';

  @override
  String get searchError => 'Searching failed.';

  @override
  String get speak => 'Speak pronunciation';

  @override
  String get speechError => 'Could not play pronunciation.';

  @override
  String get helpSpeech =>
      'Tap the speaker to hear a word. Pronunciation works offline in the installed app; the web app uses the server.';
}
