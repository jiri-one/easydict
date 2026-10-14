import 'dart:async';

import 'package:flutter/foundation.dart';

import 'data/dictionary.dart';

class DictionarySearch extends ChangeNotifier {
  DictionarySearch(
    this._dictionary, {
    required this._language,
    required this._mode,
  });

  static const _debounce = Duration(milliseconds: 120);

  final Dictionary _dictionary;
  Timer? _timer;
  int _generation = 0;

  String _query = '';
  Language _language;
  SearchMode _mode;
  SearchResult _result = SearchResult.empty;
  bool _searching = false;
  Object? _error;

  Language? _fallback;

  /// also the combining marks of decomposed text
  static final _czechLetters = RegExp(
    '[ěščřžýáíéůúňťď\u030C\u0301\u030A]',
    caseSensitive: false,
  );

  String get query => _query;
  Language get language => _language;
  SearchMode get mode => _mode;
  SearchResult get result => _result;
  bool get searching => _searching;
  Object? get error => _error;

  set query(String value) {
    if (value == _query) return;
    _query = value;
    _fallback = null;
    _timer?.cancel();
    // A search of the previous text must not land (or switch the language).
    _generation++;
    if (value.trim().isEmpty) {
      _result = SearchResult.empty;
      _searching = false;
      _error = null;
      notifyListeners();
    } else {
      _timer = Timer(_debounce, _run);
    }
  }

  set language(Language value) {
    if (value == _language) return;
    _language = value;
    _restart();
  }

  set mode(SearchMode value) {
    if (value == _mode) return;
    _mode = value;
    _restart();
  }

  void lookUp(String text, Language language) => _start(text, language);

  /// Text from outside (another app, the clipboard, the command line) has no
  /// language: Czech letters mean Czech, and when nothing is found, the other
  /// language is tried.
  void lookUpText(String text) {
    final language = _czechLetters.hasMatch(text) ? Language.cze : _language;
    _start(text, language, fallback: language.other);
  }

  void _start(String text, Language language, {Language? fallback}) {
    _query = text;
    _language = language;
    _fallback = fallback;
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    if (_query.trim().isEmpty) {
      notifyListeners();
    } else {
      _run();
    }
  }

  Future<void> _run() async {
    final generation = ++_generation;
    final (query, language, mode, fallback) = (
      _query,
      _language,
      _mode,
      _fallback,
    );
    _fallback = null;
    _searching = true;
    notifyListeners();
    try {
      var result = await _dictionary.search(query, language, mode);
      if (generation != _generation) return;
      if (result.isEmpty && fallback != null) {
        final other = await _dictionary.search(query, fallback, mode);
        if (generation != _generation) return;
        if (!other.isEmpty) {
          _language = fallback;
          result = other;
        }
      }
      _result = result;
      _error = null;
    } catch (error) {
      if (generation != _generation) return;
      _error = error;
    }
    _searching = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
