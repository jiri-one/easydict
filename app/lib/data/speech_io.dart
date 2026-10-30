import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import 'bundled_assets.dart';
import 'dictionary.dart';

final _library = DynamicLibrary.open(switch (Platform.operatingSystem) {
  'android' => 'libeasydict_speech.so',
  'macos' => '$executableDir/../Frameworks/libeasydict_speech.dylib',
  'windows' => '$executableDir/easydict_speech.dll',
  _ => '$executableDir/lib/libeasydict_speech.so',
});
final _replace = _library.lookupFunction<Uint64 Function(), int Function()>(
  'ed_speech_replace',
);
final _speech = _library
    .lookupFunction<
      Int32 Function(
        Pointer<Utf8>,
        Pointer<Utf8>,
        Pointer<Utf8>,
        Uint64,
        Pointer<Utf8>,
      ),
      int Function(
        Pointer<Utf8>,
        Pointer<Utf8>,
        Pointer<Utf8>,
        int,
        Pointer<Utf8>,
      )
    >('ed_speech');

Future<void> speak(String text, Language language) async {
  final request = _replace();
  final path = await _assetPath();
  final result = await Isolate.run(
    () => _synthesize(path, language.name, text, request),
  );
  if (result < 0) throw StateError('Speech failed');
}

int _synthesize(String path, String language, String text, int request) =>
    using(
      (arena) => _speech(
        path.toNativeUtf8(allocator: arena),
        language.toNativeUtf8(allocator: arena),
        text.toNativeUtf8(allocator: arena),
        request,
        nullptr,
      ),
    );

/// RHVoice needs real files, and Android cannot open assets as files.
Future<String> _assetPath() async {
  if (!Platform.isAndroid) return '$desktopAssetsDir/assets/speech';
  final checksum = (await rootBundle.loadString('assets/speech/checksum.txt'))
      .trim();
  final base = await getDatabasesPath();
  final target = Directory('$base/easydict-speech-$checksum');
  if (await target.exists()) return target.path;
  final partial = Directory(
    '${target.path}.$pid-${DateTime.now().microsecondsSinceEpoch}.partial',
  );
  await partial.create(recursive: true);
  try {
    final manifest = jsonDecode(
      await rootBundle.loadString('assets/speech/manifest.json'),
    ) as Map<String, dynamic>;
    for (final name in manifest.keys) {
      final file = File('${partial.path}/$name');
      await file.parent.create(recursive: true);
      final data = await rootBundle.load('assets/speech/$name');
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    try {
      await partial.rename(target.path);
    } on FileSystemException {
      if (!await target.exists()) rethrow;
    }
  } finally {
    if (await partial.exists()) await partial.delete(recursive: true);
  }
  // An update leaves the old voices behind, a killed app an unfinished copy.
  await for (final entry in Directory(base).list()) {
    if (entry is Directory &&
        entry.path.startsWith('$base/easydict-speech-') &&
        !entry.path.startsWith(target.path)) {
      await entry.delete(recursive: true);
    }
  }
  return target.path;
}
