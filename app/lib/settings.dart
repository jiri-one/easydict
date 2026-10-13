import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/dictionary.dart';

/// User preferences, stored with shared_preferences.
class Settings extends ChangeNotifier {
  Settings._(this._prefs);

  static Future<Settings> load() async =>
      Settings._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

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
      _byName(ThemeMode.values, _prefs.getString('theme'), ThemeMode.system);
  set themeMode(ThemeMode value) => _set('theme', value.name);

  /// null follows the system language.
  Locale? get locale => switch (_prefs.getString('locale')) {
    final String code? => Locale(code),
    null => null,
  };
  set locale(Locale? value) => _set('locale', value?.languageCode);

  /// Desktop: look the clipboard text up when the window gets focus.
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
