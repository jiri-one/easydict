// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class AppLocalizationsCs extends AppLocalizations {
  AppLocalizationsCs([String locale = 'cs']) : super(locale);

  @override
  String get appTitle => 'EasyDict';

  @override
  String get appSubtitle => 'Zcela otevřený překladač';

  @override
  String get searchHint => 'Napište slovo…';

  @override
  String get clear => 'Smazat';

  @override
  String get english => 'Angličtina';

  @override
  String get czech => 'Čeština';

  @override
  String get searchingEnglish =>
      'Hledáte anglická slova, klepnutím přepnete na češtinu';

  @override
  String get searchingCzech =>
      'Hledáte česká slova, klepnutím přepnete na angličtinu';

  @override
  String get modeStartsWith => 'Začátek';

  @override
  String get modeWholeWord => 'Celé slovo';

  @override
  String get modeFulltext => 'Kdekoli';

  @override
  String get welcomeTitle => 'Vítejte v EasyDictu';

  @override
  String get welcomeHint => 'Stačí začít psát.';

  @override
  String get slogan =>
      'První překladač, který je otevřený včetně slovníkových dat.';

  @override
  String entryCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString překladů',
      few: '$countString překlady',
      one: '1 překlad',
    );
    return 'Ve slovníku je $_temp0';
  }

  @override
  String noResults(String query) {
    return 'Pro „$query“ jsme nic nenašli.';
  }

  @override
  String get searchAnywhere => 'Hledat kdekoli v textu';

  @override
  String get searchInEnglish => 'Hledat v angličtině';

  @override
  String get searchInCzech => 'Hledat v češtině';

  @override
  String baseForms(String forms) {
    return 'Základní tvar: $forms';
  }

  @override
  String get truncated =>
      'Zobrazeny jsou jen nejlepší shody. Upřesněte hledání.';

  @override
  String showMore(int count) {
    return 'Zobrazit další ($count)';
  }

  @override
  String get settings => 'Nastavení';

  @override
  String get help => 'Nápověda';

  @override
  String get about => 'O aplikaci';

  @override
  String get notes => 'Značky';

  @override
  String get special => 'Poznámka';

  @override
  String get author => 'Autor překladu';

  @override
  String lookUp(String word) {
    return 'Vyhledat „$word“';
  }

  @override
  String get copy => 'Kopírovat';

  @override
  String get copied => 'Zkopírováno do schránky';

  @override
  String get settingsSearch => 'Hledání';

  @override
  String get defaultLanguage => 'Hledat v jazyce';

  @override
  String get defaultMode => 'Režim hledání';

  @override
  String get settingsAppearance => 'Vzhled';

  @override
  String get theme => 'Motiv';

  @override
  String get themeSystem => 'Podle systému';

  @override
  String get themeLight => 'Světlý';

  @override
  String get themeDark => 'Tmavý';

  @override
  String get appLanguage => 'Jazyk aplikace';

  @override
  String get systemLanguage => 'Podle systému';

  @override
  String get clipboardLookup => 'Vyhledávat ze schránky';

  @override
  String get clipboardLookupHint =>
      'Po aktivaci okna vyhledá slovo zkopírované do schránky.';

  @override
  String get helpModesTitle => 'Režimy hledání';

  @override
  String get helpModes =>
      'Začátek – hesla začínající napsaným textem.\nCelé slovo – hesla obsahující napsané slovo.\nKdekoli – napsaný text kdekoli v hesle.';

  @override
  String get helpFormsTitle => 'Tvary slov';

  @override
  String get helpForms =>
      'Česká slova můžete psát v jakémkoli tvaru: „psa“ najde „pes“, „šel“ najde „jít“. Na diakritice a velkých písmenech nezáleží.';

  @override
  String get helpTipsTitle => 'Tipy';

  @override
  String get helpTips =>
      'Klepnutím na překlad ho vyhledáte v druhém jazyce nebo zkopírujete. Vlajka vedle vyhledávacího pole přepíná jazyk. EasyDict funguje i bez internetu.';

  @override
  String get helpTipsAndroid =>
      'Označte slovo v libovolné aplikaci a v nabídce zvolte „Vyhledat v EasyDictu“.';

  @override
  String get helpTipsDesktop =>
      'Spuštěním „easydict SLOVO“ rovnou vyhledáte SLOVO, třeba z klávesové zkratky. V nastavení můžete zapnout i vyhledávání slova ze schránky, kdykoli se okno EasyDictu aktivuje.';

  @override
  String get helpLabelsTitle => 'Značky';

  @override
  String version(String version) {
    return 'Verze $version';
  }

  @override
  String get website => 'Web';

  @override
  String get sourceCode => 'Zdrojový kód';

  @override
  String get dictionaryData => 'Slovníková data';

  @override
  String get dataCredits =>
      'Anglicko-český slovník je svobodný slovník projektu Svobodné slovníky (GNU FDL 1.1 nebo pozdější), dříve GNU/FDL Anglicko-Český slovník. Tvary českých slov pocházejí z českého slovníku Hunspell (GNU GPL 2) a z Wikislovníku (CC BY-SA 4.0). Četnosti slov, podle kterých jsou běžné překlady první, pocházejí z wordfreq od Robyn Speer (CC BY-SA 4.0).';

  @override
  String get translators => 'Autoři překladů';

  @override
  String get licenses => 'Licence';

  @override
  String get loading => 'Připravuji slovník…';

  @override
  String get openError => 'Slovník se nepodařilo otevřít.';

  @override
  String get searchError => 'Hledání selhalo.';
}
