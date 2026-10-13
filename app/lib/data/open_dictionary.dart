import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import 'dictionary.dart';
import 'sqlite_ffi.dart';

const _asset = 'assets/dictionary/easydict.sqlite';
const _checksumAsset = 'assets/dictionary/easydict.sha256';

/// Open the dictionary database bundled with the app.
///
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
  return Dictionary.open(reader);
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

/// Copy the bundled database to [directory] unless this version is there.
Future<String> _copyAsset(String directory) async {
  final checksum = (await rootBundle.loadString(_checksumAsset)).trim();
  final target = File(
    '$directory/easydict-${checksum.substring(0, 16)}.sqlite',
  );
  if (!target.existsSync()) {
    await Directory(directory).create(recursive: true);
    final data = await rootBundle.load(_asset);
    final partial = File('${target.path}.partial');
    await partial.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    await partial.rename(target.path);
    // Remove the databases of older versions.
    await for (final file in Directory(directory).list()) {
      final name = file.uri.pathSegments.last;
      if (file is File &&
          name.startsWith('easydict-') &&
          name.endsWith('.sqlite') &&
          file.path != target.path) {
        await file.delete();
      }
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

  void _onResponse(Object? message) {
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
    final id = _nextId++;
    final completer = Completer<List<Map<String, Object?>>>();
    _pending[id] = completer;
    _commands.send((id, sql, arguments));
    return completer.future;
  }

  @override
  Future<void> close() async {
    _commands.send(null);
    _responses.close();
    _isolate.kill();
  }
}

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
