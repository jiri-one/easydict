import 'dart:async';

import 'package:flutter/foundation.dart';

import 'dictionary.dart';

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
    Duration probeInterval = const Duration(minutes: 1),
  }) async {
    final dictionary = FailoverDictionary._(
      openServer,
      openCopy,
      probeInterval,
      copyDate,
    );
    try {
      dictionary._server = await _twice(openServer);
    } on ServerUnavailable {
      dictionary._fallBack(null);
    }
    return dictionary;
  }

  final Future<Dictionary> Function() _openServer;
  final Future<Dictionary> Function(void Function(double)) _openCopy;
  final Duration _probeInterval;

  final DateTime copyDate;

  /// Results already on the screen came from the copy.
  VoidCallback? onServerBack;

  Dictionary? _server;
  Future<Dictionary>? _copy;
  Dictionary? _openedCopy;
  int _copyAttempt = 0;
  Timer? _probe;

  double _progress = 0;
  double get progress => _progress;

  CopyStatus get status {
    if (_server != null) return CopyStatus.unused;
    if (_copy == null) return CopyStatus.failed;
    return _openedCopy == null ? CopyStatus.downloading : CopyStatus.ready;
  }

  Dictionary? get _current => _server ?? _openedCopy;

  @override
  Map<String, String> get meta => _current?.meta ?? const {};

  @override
  int get entryCount => _current?.entryCount ?? 0;

  @override
  Future<SearchResult> search(
    String query,
    Language language,
    SearchMode mode,
  ) async {
    final server = _server;
    if (server == null) {
      final copy = await (_copy ?? _startCopy());
      return copy.search(query, language, mode);
    }
    try {
      return await _twice(() => server.search(query, language, mode));
    } on ServerUnavailable {
      _fallBack(server);
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
    _probe = Timer.periodic(_probeInterval, (_) => _askServer());
    _startCopy();
  }

  Future<Dictionary> _startCopy() {
    _openedCopy = null;
    _progress = 0;
    // a failure is for the banner and the next search, not an uncaught error
    final copy = _copy = _loadCopy(++_copyAttempt)..ignore();
    notifyListeners();
    return copy;
  }

  /// A download the server's return left behind must not touch a later one.
  Future<Dictionary> _loadCopy(int attempt) async {
    bool current() => attempt == _copyAttempt;
    try {
      final copy = await _openCopy((fraction) {
        // chunks arrive far more often than the bar can move
        if (current() && fraction - _progress >= 0.01) {
          _progress = fraction;
          notifyListeners();
        }
      });
      if (current()) {
        _openedCopy = copy;
        notifyListeners();
      }
      return copy;
    } catch (_) {
      if (current()) {
        _copy = null;
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
    _server = server;
    unawaited(_closeCopy());
    notifyListeners();
    onServerBack?.call();
  }

  /// A running download is left to finish: the browser keeps it for next time.
  Future<void> _closeCopy() async {
    final copy = _copy;
    _copy = null;
    _openedCopy = null;
    _copyAttempt++;
    await copy?.then((copy) => copy.close(), onError: (Object _) {});
  }

  void retryCopy() {
    if (_server == null && _copy == null) _startCopy();
  }

  @override
  Future<void> close() async {
    _probe?.cancel();
    await Future.wait([?_server?.close(), _closeCopy()]);
    dispose();
  }
}
