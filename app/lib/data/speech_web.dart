import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'api.dart';
import 'dictionary.dart';

web.HTMLAudioElement? _audio;
Future<void> speak(String text, Language language) async {
  _audio?.pause();
  final audio = web.HTMLAudioElement();
  _audio = audio;
  final source = Uri.base
      .resolve(apiBase)
      .resolve('speech')
      .replace(queryParameters: {'lang': language.name, 'q': text})
      .toString();
  // The server renders one word at a time, and a replaced word can still hold it.
  // A deadline, because play() does not tell a busy server from a render that failed.
  final tapped = Stopwatch()..start();
  while (true) {
    audio.src = source;
    try {
      await audio.play().toDart;
      return;
    } catch (_) {
      if (!identical(_audio, audio)) return;
      if (tapped.elapsedMilliseconds >= 6000) rethrow;
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!identical(_audio, audio)) return;
  }
}
