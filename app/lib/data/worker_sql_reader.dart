import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'dictionary.dart';

/// SQLite in web/dictionary_worker.js: the database would otherwise keep the
/// page waiting for as long as it takes to unpack.
class WorkerSqlReader implements SqlReader {
  WorkerSqlReader._(this._worker);

  /// [copy] is relative to the page: the worker has its own address.
  static Future<WorkerSqlReader> open(
    String copy,
    void Function(double) onProgress,
  ) {
    final worker = web.Worker(
      'dictionary_worker.js'.toJS,
      web.WorkerOptions(type: 'module'),
    );
    final reader = WorkerSqlReader._(worker);
    final opened = Completer<WorkerSqlReader>();
    worker.onerror = ((web.Event event) {
      final error = StateError('The dictionary worker failed.');
      if (!opened.isCompleted) opened.completeError(error);
      reader._failPending(error);
    }).toJS;
    worker.onmessage = ((web.MessageEvent event) {
      final message = event.data.dartify()! as Map<Object?, Object?>;
      if (message['progress'] case final num fraction) {
        onProgress(fraction.toDouble());
      } else if (message['opened'] == true) {
        opened.complete(reader);
      } else if (message['failed'] case final String error) {
        worker.terminate();
        opened.completeError(StateError(error));
      } else {
        reader._answer(message);
      }
    }).toJS;
    final base = Uri.parse(web.document.baseURI);
    worker.postMessage({'open': base.resolve(copy).toString()}.jsify());
    return opened.future;
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
    final id = _nextId++;
    final completer = Completer<List<Map<String, Object?>>>();
    _pending[id] = completer;
    _worker.postMessage({'id': id, 'sql': sql, 'arguments': arguments}.jsify());
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
