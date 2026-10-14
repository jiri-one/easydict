import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'page_theme.dart';
import 'settings.dart';

/// Desktop: `easydict WORD` starts with WORD looked up; the web app does the
/// same for the address /app?q=WORD.
Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(_licenses);
  final query = kIsWeb
      ? Uri.base.queryParameters['q'] ?? ''
      : arguments.join(' ');
  runApp(
    EasyDictApp(
      settings: await Settings.load(),
      initialQuery: query.trim(),
      pageTheme: pageTheme(),
    ),
  );
}

Stream<LicenseEntry> _licenses() async* {
  Future<String> text(String name) =>
      rootBundle.loadString('assets/licenses/$name');
  yield LicenseEntryWithLineBreaks(['EasyDict'], await text('GPL-3.0.txt'));
  // the complete notice with the cover texts and authors, as the GNU FDL asks
  final notice = await rootBundle.loadString(
    'assets/dictionary/easydict.sqlite.NOTICE.txt',
  );
  yield LicenseEntryWithLineBreaks([
    'Svobodný anglicko-český slovník',
  ], '$notice\n\n${await text('GFDL-1.1.txt')}');
  yield LicenseEntryWithLineBreaks(
    ['Czech Hunspell dictionary'],
    'Czech word forms from the Czech Hunspell dictionary of LibreOffice.\n\n'
    '${await text('GPL-2.0.txt')}',
  );
  yield const LicenseEntryWithLineBreaks(
    ['Wiktionary'],
    '''
Czech word forms from Wiktionary (https://en.wiktionary.org), extracted by
wiktextract (https://kaikki.org). Licensed under the Creative Commons
Attribution-ShareAlike 4.0 International licence,
https://creativecommons.org/licenses/by-sa/4.0/''',
  );
  yield const LicenseEntryWithLineBreaks(
    ['wordfreq'],
    '''
Word frequencies from wordfreq by Robyn Speer (https://github.com/rspeer/wordfreq),
licensed under the Creative Commons Attribution-ShareAlike 4.0 International
licence, https://creativecommons.org/licenses/by-sa/4.0/

wordfreq contains data from Wikipedia, from OPUS OpenSubtitles 2018 (data
originating from the OpenSubtitles project, http://www.opensubtitles.org/),
from the SUBTLEX word lists by Marc Brysbaert et al. (SUBTLEX is freely
available data, http://crr.ugent.be/programs-data/subtitle-frequencies), from
Google Books Ngrams (http://books.google.com/ngrams), the Leeds Internet
Corpus and ParaCrawl, and statistics of words used on Twitter.''',
  );
}
