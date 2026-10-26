import 'package:easydict/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// MaterialApp picks the app language like this when it has no callback.
void main() {
  Locale resolve(List<Locale> system) =>
      basicLocaleListResolution(system, AppLocalizations.supportedLocales);

  test('the system language where the app has it', () {
    expect(resolve(const [Locale('cs', 'CZ')]), const Locale('cs'));
    expect(resolve(const [Locale('en', 'GB')]), const Locale('en'));
    expect(resolve(const [Locale('sk'), Locale('cs')]), const Locale('cs'));
  });

  test('English otherwise', () {
    expect(resolve(const [Locale('de', 'DE')]), const Locale('en'));
    expect(resolve(const []), const Locale('en'));
  });
}
