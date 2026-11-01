import 'dart:async';

import 'package:flutter/foundation.dart';

import 'dictionary.dart';
import 'remote_dictionary.dart';

enum CopyStatus { unused, downloading, ready, failed }

/// The server whenever it answers, so that the web app shows what the website
/// shows, even a translation approved a minute ago. The copy of the dictionary
/// costs a big download and may be older, so it is only for when it does not.
class FailoverDictionary extends ChangeNotifier implements Dictionary {
  FailoverDictionary._(
    this._openServer,
    this._openCopy,
    this._probeInterval,
    this.copyDate,
  );

  static Future<FailoverDictionary> open({
    required Future<Dictionary> Function() openServer,
    required Future<Dictionary> Function(void Function(double) onProgress)
    openCopy,
    required DateTime copyDate,
    bool preferCopy = false,
    Duration probeInterval = const Duration(minutes: 1),
  }) async {
    final dictionary = FailoverDictionary._(
      openServer,
      openCopy,
      probeInterval,
      copyDate,
    );
    if (preferCopy) {
      dictionary._startCopy();
    } else {
      try {
        dictionary._server = await _twice(openServer);
      } on ServerUnavailable {
        dictionary._fallBack(null);
      }
    }
    return dictionary;
  }

  final Future<Dictionary> Function() _openServer;
  final Future<Dictionary> Function(void Function(double)) _openCopy;
  final Duration _probeInterval;

  final DateTime copyDate;

  Dictionary? _server;
  Future<Dictionary>? _copy;
  Map<String, String> _copyMeta = const {};
  Timer? _probe;

  CopyStatus _status = CopyStatus.unused;
  CopyStatus get status => _status;

  double _progress = 0;
  double get progress => _progress;

  @override
  Map<String, String> get meta => _server?.meta ?? _copyMeta;

  @override
  int get entryCount => int.parse(meta['entries'] ?? '0');

  @override
  Future<SearchResult> search(
    String query,
    Language language,
    SearchMode mode,
  ) async {
    final server = _server;
    if (server == null) return _searchCopy(query, language, mode);
    try {
      return await _twice(() => server.search(query, language, mode));
    } on ServerUnavailable {
      _fallBack(server);
      return search(query, language, mode);
    }
  }

  Future<SearchResult> _searchCopy(
    String query,
    Language language,
    SearchMode mode,
  ) async {
    try {
      final copy = await (_copy ?? _startCopy());
      return await copy.search(query, language, mode);
    } catch (_) {
      // the server came back and the copy was closed under this search
      if (_server == null) rethrow;
      return search(query, language, mode);
    }
  }

  /// One lost answer must not cost the visitor the download.
  static Future<T> _twice<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on ServerUnavailable {
      return request();
    }
  }

  /// Several searches can fail at once, and an older one must not push out a
  /// server that has come back since.
  void _fallBack(Dictionary? failed) {
    if (!identical(_server, failed)) return;
    _server = null;
    unawaited(failed?.close());
    _probe ??= Timer.periodic(_probeInterval, (_) => _askServer());
    if (_copy == null) _startCopy();
  }

  Future<Dictionary> _startCopy() {
    _status = CopyStatus.downloading;
    _progress = 0;
    notifyListeners();
    // a failure is for the banner and the next search, not an uncaught error
    return _copy = _loadCopy()..ignore();
  }

  Future<Dictionary> _loadCopy() async {
    try {
      final copy = await _openCopy((fraction) {
        _progress = fraction;
        notifyListeners();
      });
      if (_server == null) {
        _copyMeta = copy.meta;
        _status = CopyStatus.ready;
        notifyListeners();
      }
      return copy;
    } catch (_) {
      if (_server == null) {
        _copy = null;
        _status = CopyStatus.failed;
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> _askServer() async {
    final Dictionary server;
    try {
      server = await _openServer();
    } catch (_) {
      return;
    }
    _probe?.cancel();
    _probe = null;
    _server = server;
    final copy = _copy;
    _copy = null;
    // A running download is left to finish: the browser keeps it for next time.
    unawaited(copy?.then((copy) => copy.close(), onError: (Object _) {}));
    _status = CopyStatus.unused;
    notifyListeners();
  }

  void retryCopy() {
    if (_server == null && _copy == null) _startCopy();
  }

  @override
  Future<void> close() async {
    _probe?.cancel();
    final copy = _copy;
    await Future.wait([
      ?_server?.close(),
      if (copy != null)
        copy.then((copy) => copy.close(), onError: (Object _) {}),
    ]);
    dispose();
  }
}
