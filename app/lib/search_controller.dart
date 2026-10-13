import 'dart:async';

import 'package:flutter/foundation.dart';

import 'data/dictionary.dart';

/// The state of the search screen: query, language, mode and results.
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

  /// Searched again in this language when nothing is found (see [lookUpText]).
  Language? _fallback;

  static final _czechLetters = RegExp('[ěščřžýáíéůúňťď]', caseSensitive: false);

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
    if (value.trim().isEmpty) {
      _generation++;
      _result = SearchResult.empty;
      _searching = false;
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

  /// Search [text] in [language] right away, e.g. a tapped translation.
  void lookUp(String text, Language language) {
    _query = text;
    _language = language;
    _fallback = null;
    _restart();
  }

  /// Search text that comes from outside (selected in another app, from the
  /// clipboard or the command line): Czech letters mean Czech, and when
  /// nothing is found the other language is tried.
  void lookUpText(String text) {
    final language = _czechLetters.hasMatch(text) ? Language.cze : _language;
    lookUp(text, language);
    _fallback = language.other;
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
    _searching = true;
    notifyListeners();
    try {
      var result = await _dictionary.search(_query, _language, _mode);
      if (generation != _generation) return;
      final fallback = _fallback;
      _fallback = null;
      if (result.isEmpty && fallback != null) {
        final other = await _dictionary.search(_query, fallback, _mode);
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
