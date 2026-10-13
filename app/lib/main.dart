import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'settings.dart';
import 'ui/about_page.dart';

/// Desktop: `easydict WORD` starts with WORD looked up.
Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(_licenses);
  runApp(
    EasyDictApp(
      settings: await Settings.load(),
      initialQuery: arguments.join(' ').trim(),
    ),
  );
}

/// Licences of the app and its data, shown on the licence page next to the
/// licences of the Flutter packages.
Stream<LicenseEntry> _licenses() async* {
  Future<String> text(String name) =>
      rootBundle.loadString('assets/licenses/$name');
  yield LicenseEntryWithLineBreaks(['EasyDict'], await text('GPL-3.0.txt'));
  yield LicenseEntryWithLineBreaks([
    'Svobodný anglicko-český slovník',
  ], '$dictionaryNotices\n\n${await text('GFDL-1.1.txt')}');
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
}
