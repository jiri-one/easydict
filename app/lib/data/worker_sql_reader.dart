import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'dictionary.dart';

/// SQLite in web/dictionary_worker.js: the database would otherwise keep the
/// page waiting for as long as it takes to unpack.
class WorkerSqlReader implements SqlReader {
  WorkerSqlReader._(this._worker);

  static Future<WorkerSqlReader> open(
    String copy,
    void Function(double) onProgress,
  ) async {
    final worker = web.Worker(
      'dictionary_worker.js'.toJS,
      web.WorkerOptions(type: 'module'),
    );
    final reader = WorkerSqlReader._(worker);
    worker.onerror = ((web.Event event) {
      reader._failPending(StateError('The dictionary worker failed.'));
    }).toJS;
    worker.onmessage = ((web.MessageEvent event) {
      final message = event.data.dartify()! as Map<Object?, Object?>;
      if (message['progress'] case final num fraction) {
        onProgress(fraction.toDouble());
      } else {
        reader._answer(message);
      }
    }).toJS;
    try {
      await reader._ask({'open': copy});
    } catch (_) {
      worker.terminate();
      rethrow;
    }
    return reader;
  }

  final web.Worker _worker;
  final _pending = <int, Completer<List<Map<String, Object?>>>>{};
  int _nextId = 0;
  bool _closed = false;

  void _answer(Map<Object?, Object?> message) {
    final completer = _pending.remove(message['id']! as int)!;
    if (message['error'] case final String error) {
      completer.completeError(StateError(error));
    } else {
      completer.complete([
        for (final row in message['rows']! as List<Object?>)
          (row! as Map<Object?, Object?>).cast<String, Object?>(),
      ]);
    }
  }

  void _failPending(Object error) {
    for (final completer in _pending.values) {
      completer.completeError(error);
    }
    _pending.clear();
  }

  @override
  Future<List<Map<String, Object?>>> select(
    String sql, [
    List<Object?> arguments = const [],
  ]) {
    if (_closed) {
      return Future.error(StateError('The dictionary copy is closed.'));
    }
    return _ask({'sql': sql, 'arguments': arguments});
  }

  Future<List<Map<String, Object?>>> _ask(Map<String, Object?> request) {
    final id = _nextId++;
    final completer = Completer<List<Map<String, Object?>>>();
    _pending[id] = completer;
    _worker.postMessage({'id': id, ...request}.jsify());
    return completer.future;
  }

  /// Ends the worker, and with it the memory of the database.
  @override
  Future<void> close() async {
    _closed = true;
    _worker.terminate();
    _failPending(StateError('The dictionary copy is closed.'));
  }
}
