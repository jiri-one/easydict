import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// A minimal read-only binding to the SQLite library of the operating system.
///
/// Desktop builds use it instead of a bundled SQLite: Linux distributions and
/// the Flatpak runtime ship libsqlite3.so.0, Windows 10+ ships winsqlite3.dll
/// and macOS ships libsqlite3.dylib.
class SqliteDatabase {
  SqliteDatabase._(this._api, this._db);

  /// Open the database at [path] read-only. It must not change while open.
  factory SqliteDatabase.openImmutable(String path) {
    final api = _SqliteApi.instance;
    final uri = '${Uri.file(path)}?immutable=1';
    final out = calloc<Pointer<Void>>();
    final name = uri.toNativeUtf8();
    try {
      final rc = api.open(name, out, _openReadOnly | _openUri, nullptr);
      final db = out.value;
      if (rc != _ok) {
        final message = db == nullptr ? 'error $rc' : api.errorMessage(db);
        if (db != nullptr) api.close(db);
        throw SqliteException('Cannot open $path: $message');
      }
      return SqliteDatabase._(api, db);
    } finally {
      calloc.free(name);
      calloc.free(out);
    }
  }

  static const _ok = 0;
  static const _row = 100;
  static const _done = 101;
  static const _openReadOnly = 0x01;
  static const _openUri = 0x40;
  static const _integer = 1;
  static const _float = 2;
  static const _text = 3;
  static const _null = 5;

  final _SqliteApi _api;
  Pointer<Void> _db;

  List<Map<String, Object?>> select(
    String sql, [
    List<Object?> arguments = const [],
  ]) {
    if (_db == nullptr) throw SqliteException('The database is closed.');
    final sqlNative = sql.toNativeUtf8();
    final statementOut = calloc<Pointer<Void>>();
    final allocated = <Pointer<Utf8>>[sqlNative];
    try {
      if (_api.prepare(_db, sqlNative, -1, statementOut, nullptr) != _ok) {
        throw SqliteException('${_api.errorMessage(_db)} in: $sql');
      }
      final statement = statementOut.value;
      try {
        for (var i = 0; i < arguments.length; i++) {
          final rc = switch (arguments[i]) {
            null => _api.bindNull(statement, i + 1),
            final int value => _api.bindInt(statement, i + 1, value),
            final String value => () {
              // The length in bytes keeps a NUL inside the text.
              final bytes = utf8.encode(value);
              final text = calloc<Uint8>(bytes.length + 1);
              text.asTypedList(bytes.length).setAll(0, bytes);
              allocated.add(text.cast());
              return _api.bindText(
                statement,
                i + 1,
                text.cast(),
                bytes.length,
                nullptr,
              );
            }(),
            final other => throw ArgumentError('Unsupported argument $other'),
          };
          if (rc != _ok) throw SqliteException(_api.errorMessage(_db));
        }
        final columns = [
          for (var i = 0; i < _api.columnCount(statement); i++)
            _api.columnName(statement, i).toDartString(),
        ];
        final rows = <Map<String, Object?>>[];
        while (true) {
          final rc = _api.step(statement);
          if (rc == _done) break;
          if (rc != _row) throw SqliteException(_api.errorMessage(_db));
          rows.add({
            for (var i = 0; i < columns.length; i++)
              columns[i]: switch (_api.columnType(statement, i)) {
                _integer => _api.columnInt(statement, i),
                _float => _api.columnDouble(statement, i),
                _text => utf8.decode(
                  _api
                      .columnText(statement, i)
                      .cast<Uint8>()
                      .asTypedList(_api.columnBytes(statement, i)),
                ),
                _null => null,
                _ => throw SqliteException('Unsupported column type'),
              },
          });
        }
        return rows;
      } finally {
        _api.finalize(statement);
      }
    } finally {
      // The texts are bound without a destructor, so they live until here.
      for (final pointer in allocated) {
        calloc.free(pointer);
      }
      calloc.free(statementOut);
    }
  }

  void close() {
    if (_db == nullptr) return;
    _api.close(_db);
    _db = nullptr;
  }
}

class SqliteException implements Exception {
  SqliteException(this.message);

  final String message;

  @override
  String toString() => 'SqliteException: $message';
}

class _SqliteApi {
  _SqliteApi(DynamicLibrary lib)
    : open = lib
          .lookupFunction<
            Int32 Function(
              Pointer<Utf8>,
              Pointer<Pointer<Void>>,
              Int32,
              Pointer<Utf8>,
            ),
            int Function(
              Pointer<Utf8>,
              Pointer<Pointer<Void>>,
              int,
              Pointer<Utf8>,
            )
          >('sqlite3_open_v2'),
      close = lib
          .lookupFunction<
            Int32 Function(Pointer<Void>),
            int Function(Pointer<Void>)
          >('sqlite3_close_v2'),
      _errmsg = lib
          .lookupFunction<
            Pointer<Utf8> Function(Pointer<Void>),
            Pointer<Utf8> Function(Pointer<Void>)
          >('sqlite3_errmsg'),
      prepare = lib
          .lookupFunction<
            Int32 Function(
              Pointer<Void>,
              Pointer<Utf8>,
              Int32,
              Pointer<Pointer<Void>>,
              Pointer<Pointer<Utf8>>,
            ),
            int Function(
              Pointer<Void>,
              Pointer<Utf8>,
              int,
              Pointer<Pointer<Void>>,
              Pointer<Pointer<Utf8>>,
            )
          >('sqlite3_prepare_v2'),
      bindNull = lib
          .lookupFunction<
            Int32 Function(Pointer<Void>, Int32),
            int Function(Pointer<Void>, int)
          >('sqlite3_bind_null'),
      bindInt = lib
          .lookupFunction<
            Int32 Function(Pointer<Void>, Int32, Int64),
            int Function(Pointer<Void>, int, int)
          >('sqlite3_bind_int64'),
      bindText = lib
          .lookupFunction<
            Int32 Function(
              Pointer<Void>,
              Int32,
              Pointer<Utf8>,
              Int32,
              Pointer<Void>,
            ),
            int Function(Pointer<Void>, int, Pointer<Utf8>, int, Pointer<Void>)
          >('sqlite3_bind_text'),
      step = lib
          .lookupFunction<
            Int32 Function(Pointer<Void>),
            int Function(Pointer<Void>)
          >('sqlite3_step'),
      finalize = lib
          .lookupFunction<
            Int32 Function(Pointer<Void>),
            int Function(Pointer<Void>)
          >('sqlite3_finalize'),
      columnCount = lib
          .lookupFunction<
            Int32 Function(Pointer<Void>),
            int Function(Pointer<Void>)
          >('sqlite3_column_count'),
      columnName = lib
          .lookupFunction<
            Pointer<Utf8> Function(Pointer<Void>, Int32),
            Pointer<Utf8> Function(Pointer<Void>, int)
          >('sqlite3_column_name'),
      columnType = lib
          .lookupFunction<
            Int32 Function(Pointer<Void>, Int32),
            int Function(Pointer<Void>, int)
          >('sqlite3_column_type'),
      columnInt = lib
          .lookupFunction<
            Int64 Function(Pointer<Void>, Int32),
            int Function(Pointer<Void>, int)
          >('sqlite3_column_int64'),
      columnDouble = lib
          .lookupFunction<
            Double Function(Pointer<Void>, Int32),
            double Function(Pointer<Void>, int)
          >('sqlite3_column_double'),
      columnText = lib
          .lookupFunction<
            Pointer<Utf8> Function(Pointer<Void>, Int32),
            Pointer<Utf8> Function(Pointer<Void>, int)
          >('sqlite3_column_text'),
      columnBytes = lib
          .lookupFunction<
            Int32 Function(Pointer<Void>, Int32),
            int Function(Pointer<Void>, int)
          >('sqlite3_column_bytes');

  static final instance = _SqliteApi(_load());

  static DynamicLibrary _load() {
    final candidates = switch (Platform.operatingSystem) {
      'linux' => ['libsqlite3.so.0', 'libsqlite3.so'],
      'windows' => ['sqlite3.dll', 'winsqlite3.dll'],
      'macos' => ['/usr/lib/libsqlite3.dylib', 'libsqlite3.dylib'],
      _ => ['libsqlite3.so'],
    };
    for (final name in candidates) {
      try {
        return DynamicLibrary.open(name);
      } on ArgumentError {
        // try the next name
      }
    }
    throw SqliteException(
      'No SQLite library found (${candidates.join(', ')}).',
    );
  }

  final int Function(Pointer<Utf8>, Pointer<Pointer<Void>>, int, Pointer<Utf8>)
  open;
  final int Function(Pointer<Void>) close;
  final Pointer<Utf8> Function(Pointer<Void>) _errmsg;
  final int Function(
    Pointer<Void>,
    Pointer<Utf8>,
    int,
    Pointer<Pointer<Void>>,
    Pointer<Pointer<Utf8>>,
  )
  prepare;
  final int Function(Pointer<Void>, int) bindNull;
  final int Function(Pointer<Void>, int, int) bindInt;
  final int Function(Pointer<Void>, int, Pointer<Utf8>, int, Pointer<Void>)
  bindText;
  final int Function(Pointer<Void>) step;
  final int Function(Pointer<Void>) finalize;
  final int Function(Pointer<Void>) columnCount;
  final Pointer<Utf8> Function(Pointer<Void>, int) columnName;
  final int Function(Pointer<Void>, int) columnType;
  final int Function(Pointer<Void>, int) columnInt;
  final double Function(Pointer<Void>, int) columnDouble;
  final Pointer<Utf8> Function(Pointer<Void>, int) columnText;
  final int Function(Pointer<Void>, int) columnBytes;

  String errorMessage(Pointer<Void> db) => _errmsg(db).toDartString();
}
