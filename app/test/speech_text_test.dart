import 'dart:convert';
import 'dart:io';

import 'package:easydict/data/dictionary.dart';
import 'package:easydict/data/speech_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = jsonDecode(
    File('test/fixtures/speech_text.json').readAsStringSync(),
  ) as List<dynamic>;
  for (final [String text, String language, String spoken] in cases) {
    test('$language: $text', () {
      expect(speechText(text, Language.values.byName(language)), spoken);
    });
  }
}
