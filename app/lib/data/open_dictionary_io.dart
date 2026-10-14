import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import 'dictionary.dart';
import 'sqlite_ffi.dart';

const _asset = 'assets/dictionary/easydict.sqlite';
const _checksumAsset = 'assets/dictionary/easydict.sha256';

/// Android cannot open assets as files, so the database is copied out once
/// and opened with sqflite (the SQLite of the system). Desktop builds open the
/// bundled file in place through [SqliteDatabase].
Future<Dictionary> openDictionary() async {
  final SqlReader reader;
  if (Platform.isAndroid || Platform.isIOS) {
    final path = await _copyAsset(await sqflite.getDatabasesPath());
    reader = _SqfliteReader(
      await sqflite.openDatabase(path, readOnly: true, singleInstance: true),
    );
  } else {
    reader = await IsolateSqlReader.open(await _desktopDatabasePath());
  }
  return SqlDictionary.open(reader);
}

Future<String> _desktopDatabasePath() async {
  final executableDir = File(Platform.resolvedExecutable).parent.path;
  final assets = Platform.isMacOS
      ? '$executableDir/../Frameworks/App.framework/Resources/flutter_assets'
      : '$executableDir/data/flutter_assets';
  final bundled = File('$assets/$_asset');
  if (bundled.existsSync()) return bundled.path;
  return _copyAsset(Directory.systemTemp.path);
}

Future<String> _copyAsset(String directory) async {
  final checksum = (await rootBundle.loadString(_checksumAsset)).trim();
  final name = 'easydict-${checksum.substring(0, 16)}.sqlite';
  final target = File('$directory/$name');
  if (target.existsSync()) return target.path;
  await Directory(directory).create(recursive: true);
  final data = await rootBundle.load(_asset);
  // Two engines can copy at the same time (text selected in another app
  // during the first start), so each writes its own file and the rename
  // publishes a complete copy atomically.
  final partial = File(
    '${target.path}.$pid-${DateTime.now().microsecondsSinceEpoch}.partial',
  );
  await partial.writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    flush: true,
  );
  try {
    await partial.rename(target.path);
  } on FileSystemException {
    if (!target.existsSync()) rethrow;
    await partial.delete();
  }
  // databases (and unfinished copies) of older versions
  await for (final file in Directory(directory).list()) {
    final fileName = file.uri.pathSegments.last;
    if (file is File &&
        fileName.startsWith('easydict-') &&
        !fileName.startsWith(name)) {
      await file.delete();
    }
  }
  return target.path;
}

class _SqfliteReader implements SqlReader {
  _SqfliteReader(this._db);

  final sqflite.Database _db;

  @override
  Future<List<Map<String, Object?>>> select(
    String sql, [
    List<Object?> arguments = const [],
  ]) => _db.rawQuery(sql, arguments);

  @override
  Future<void> close() => _db.close();
}

/// Runs the queries of [SqliteDatabase] in a background isolate, so that the
/// user interface never waits for SQLite.
class IsolateSqlReader implements SqlReader {
  IsolateSqlReader._(this._isolate, this._commands);

  static Future<IsolateSqlReader> open(String path) async {
    final responses = ReceivePort();
    final isolate = await Isolate.spawn(_serve, (
      responses.sendPort,
      path,
    ), debugName: 'sqlite');
    final events = responses.asBroadcastStream();
    final first = await events.first;
    if (first is! SendPort) {
      responses.close();
      isolate.kill();
      throw SqliteException('$first');
    }
    final reader = IsolateSqlReader._(isolate, first);
    events.listen(reader._onResponse);
    reader._responses = responses;
    return reader;
  }

  final Isolate _isolate;
  final SendPort _commands;
  late final ReceivePort _responses;
  final _pending = <int, Completer<List<Map<String, Object?>>>>{};
  int _nextId = 0;

  /// shared by all callers of [close]
  Future<void>? _closing;

  final _workerClosed = Completer<void>();

  void _onResponse(Object? message) {
    if (message == _closedMessage) {
      if (!_workerClosed.isCompleted) _workerClosed.complete();
      return;
    }
    final (id, rows, error) =
        message! as (int, List<Map<String, Object?>>?, String?);
    final completer = _pending.remove(id)!;
    if (error == null) {
      completer.complete(rows);
    } else {
      completer.completeError(SqliteException(error));
    }
  }

  @override
  Future<List<Map<String, Object?>>> select(
    String sql, [
    List<Object?> arguments = const [],
  ]) {
    if (_closing != null) {
      return Future.error(StateError('The dictionary database is closed.'));
    }
    final id = _nextId++;
    final completer = Completer<List<Map<String, Object?>>>();
    _pending[id] = completer;
    _commands.send((id, sql, arguments));
    return completer.future;
  }

  /// Queries sent before are still answered (the worker handles messages in
  /// order); later ones fail.
  @override
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _commands.send(null);
    await _workerClosed.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
    for (final completer in _pending.values) {
      completer.completeError(StateError('The dictionary database is closed.'));
    }
    _pending.clear();
    _responses.close();
    _isolate.kill();
  }
}

const _closedMessage = 'closed';

void _serve((SendPort, String) init) {
  final (responses, path) = init;
  final SqliteDatabase db;
  try {
    db = SqliteDatabase.openImmutable(path);
  } catch (error) {
    responses.send('$error');
    return;
  }
  final commands = ReceivePort();
  responses.send(commands.sendPort);
  commands.listen((message) {
    if (message == null) {
      db.close();
      commands.close();
      responses.send(_closedMessage);
      return;
    }
    final (id, sql, arguments) = message as (int, String, List<Object?>);
    try {
      responses.send((id, db.select(sql, arguments), null));
    } catch (error) {
      responses.send((id, null, '$error'));
    }
  });
}
