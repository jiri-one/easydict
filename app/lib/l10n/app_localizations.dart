import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_cs.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('cs'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'EasyDict'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Completely open translator'**
  String get appSubtitle;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Type a word…'**
  String get searchHint;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @czech.
  ///
  /// In en, this message translates to:
  /// **'Czech'**
  String get czech;

  /// No description provided for @searchingEnglish.
  ///
  /// In en, this message translates to:
  /// **'Searching English words, tap to switch to Czech'**
  String get searchingEnglish;

  /// No description provided for @searchingCzech.
  ///
  /// In en, this message translates to:
  /// **'Searching Czech words, tap to switch to English'**
  String get searchingCzech;

  /// No description provided for @modeStartsWith.
  ///
  /// In en, this message translates to:
  /// **'Starts with'**
  String get modeStartsWith;

  /// No description provided for @modeWholeWord.
  ///
  /// In en, this message translates to:
  /// **'Whole word'**
  String get modeWholeWord;

  /// No description provided for @modeFulltext.
  ///
  /// In en, this message translates to:
  /// **'Anywhere'**
  String get modeFulltext;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to EasyDict'**
  String get welcomeTitle;

  /// No description provided for @welcomeHint.
  ///
  /// In en, this message translates to:
  /// **'Just start typing to see results.'**
  String get welcomeHint;

  /// No description provided for @slogan.
  ///
  /// In en, this message translates to:
  /// **'The first translator which is completely open with dictionary data too.'**
  String get slogan;

  /// No description provided for @entryCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 translation} other{{count} translations}} in the dictionary'**
  String entryCount(int count);

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing found for “{query}”.'**
  String noResults(String query);

  /// No description provided for @searchAnywhere.
  ///
  /// In en, this message translates to:
  /// **'Search anywhere in the text'**
  String get searchAnywhere;

  /// No description provided for @searchInEnglish.
  ///
  /// In en, this message translates to:
  /// **'Search in English'**
  String get searchInEnglish;

  /// No description provided for @searchInCzech.
  ///
  /// In en, this message translates to:
  /// **'Search in Czech'**
  String get searchInCzech;

  /// No description provided for @baseForms.
  ///
  /// In en, this message translates to:
  /// **'Base form: {forms}'**
  String baseForms(String forms);

  /// No description provided for @truncated.
  ///
  /// In en, this message translates to:
  /// **'Only the best matches are shown. Type more to narrow the search.'**
  String get truncated;

  /// No description provided for @showMore.
  ///
  /// In en, this message translates to:
  /// **'Show {count} more'**
  String showMore(int count);

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get notes;

  /// No description provided for @special.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get special;

  /// No description provided for @author.
  ///
  /// In en, this message translates to:
  /// **'Translated by'**
  String get author;

  /// No description provided for @lookUp.
  ///
  /// In en, this message translates to:
  /// **'Look up “{word}”'**
  String lookUp(String word);

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied to the clipboard'**
  String get copied;

  /// No description provided for @settingsSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get settingsSearch;

  /// No description provided for @defaultLanguage.
  ///
  /// In en, this message translates to:
  /// **'Search in'**
  String get defaultLanguage;

  /// No description provided for @defaultMode.
  ///
  /// In en, this message translates to:
  /// **'Search mode'**
  String get defaultMode;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get appLanguage;

  /// No description provided for @systemLanguage.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemLanguage;

  /// No description provided for @clipboardLookup.
  ///
  /// In en, this message translates to:
  /// **'Look up the clipboard'**
  String get clipboardLookup;

  /// No description provided for @clipboardLookupHint.
  ///
  /// In en, this message translates to:
  /// **'When the window is activated, search the word copied to the clipboard.'**
  String get clipboardLookupHint;

  /// No description provided for @helpModesTitle.
  ///
  /// In en, this message translates to:
  /// **'Search modes'**
  String get helpModesTitle;

  /// No description provided for @helpModes.
  ///
  /// In en, this message translates to:
  /// **'Starts with – headwords beginning with the typed text.\nWhole word – headwords containing the typed word.\nAnywhere – the typed text anywhere in the headword.'**
  String get helpModes;

  /// No description provided for @helpFormsTitle.
  ///
  /// In en, this message translates to:
  /// **'Word forms'**
  String get helpFormsTitle;

  /// No description provided for @helpForms.
  ///
  /// In en, this message translates to:
  /// **'Czech words can be typed in any form: “psa” finds “pes”, “šel” finds “jít”. Diacritics and capital letters do not matter.'**
  String get helpForms;

  /// No description provided for @helpTipsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get helpTipsTitle;

  /// No description provided for @helpTips.
  ///
  /// In en, this message translates to:
  /// **'Tap a translation to look it up in the other language or to copy it. The flag next to the search field switches the language. EasyDict works offline.'**
  String get helpTips;

  /// No description provided for @helpLabelsTitle.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get helpLabelsTitle;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(String version);

  /// No description provided for @website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// No description provided for @sourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get sourceCode;

  /// No description provided for @dictionaryData.
  ///
  /// In en, this message translates to:
  /// **'Dictionary data'**
  String get dictionaryData;

  /// No description provided for @dataCredits.
  ///
  /// In en, this message translates to:
  /// **'The English–Czech dictionary is the free dictionary of the Svobodné slovníky project (GNU FDL 1.1 or later), formerly the GNU/FDL English-Czech Dictionary. Czech word forms come from the Czech Hunspell dictionary (GNU GPL 2) and from Wiktionary (CC BY-SA 4.0). Word frequencies, which put the common translations first, come from wordfreq by Robyn Speer (CC BY-SA 4.0).'**
  String get dataCredits;

  /// No description provided for @translators.
  ///
  /// In en, this message translates to:
  /// **'Translators'**
  String get translators;

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get licenses;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Preparing the dictionary…'**
  String get loading;

  /// No description provided for @openError.
  ///
  /// In en, this message translates to:
  /// **'The dictionary could not be opened.'**
  String get openError;

  /// No description provided for @searchError.
  ///
  /// In en, this message translates to:
  /// **'Searching failed.'**
  String get searchError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['cs', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'cs':
      return AppLocalizationsCs();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
