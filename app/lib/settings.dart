import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/dictionary.dart';
import 'page_theme.dart';

class Settings extends ChangeNotifier {
  Settings._(this._prefs, this._pageTheme) {
    _pageTheme?.addListener(notifyListeners);
  }

  static Future<Settings> load() async =>
      Settings._(await SharedPreferences.getInstance(), pageTheme());

  final SharedPreferences _prefs;

  /// On the web the theme is the colour choice of the whole website.
  final ValueNotifier<ThemeMode>? _pageTheme;

  static T _byName<T extends Enum>(List<T> values, String? name, T fallback) =>
      values.where((value) => value.name == name).firstOrNull ?? fallback;

  Language get language =>
      _byName(Language.values, _prefs.getString('language'), Language.eng);
  set language(Language value) => _set('language', value.name);

  SearchMode get mode => _byName(
    SearchMode.values,
    _prefs.getString('mode'),
    SearchMode.startsWith,
  );
  set mode(SearchMode value) => _set('mode', value.name);

  ThemeMode get themeMode =>
      _pageTheme?.value ??
      _byName(ThemeMode.values, _prefs.getString('theme'), ThemeMode.system);
  set themeMode(ThemeMode value) {
    if (_pageTheme case final page?) {
      page.value = value;
    } else {
      _set('theme', value.name);
    }
  }

  /// null follows the system language.
  Locale? get locale => switch (_prefs.getString('locale')) {
    final String code? => Locale(code),
    null => null,
  };
  set locale(Locale? value) => _set('locale', value?.languageCode);

  bool get clipboardLookup => _prefs.getBool('clipboard_lookup') ?? false;
  set clipboardLookup(bool value) {
    _prefs.setBool('clipboard_lookup', value);
    notifyListeners();
  }

  void _set(String key, String? value) {
    if (value == null) {
      _prefs.remove(key);
    } else {
      _prefs.setString(key, value);
    }
    notifyListeners();
  }
}
