import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'dictionary.dart';

web.HTMLAudioElement? _audio;
Future<void> speak(String text, Language language) async {
  _audio?.pause();
  final audio = web.HTMLAudioElement();
  _audio = audio;
  audio.src = Uri.base
      .resolve('/api/speech')
      .replace(queryParameters: {'lang': language.name, 'q': text})
      .toString();
  try {
    await audio.play().toDart;
  } catch (_) {
    if (identical(_audio, audio)) rethrow;
  }
}
