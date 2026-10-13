import 'dart:io';

import 'package:easydict/data/notes.dart';
import 'package:easydict/version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notes are split into labels with explanations', () {
    final labels = parseNotes('n: [med.] [mužs. jméno] (acc) 2');
    expect(labels.map((label) => label.text), [
      'n:',
      '[med.]',
      '[mužs. jméno]',
      '(acc)',
    ]);
    expect(labels[0].explanation, ('podstatné jméno', 'noun'));
    expect(labels[1].explanation, ('medicína', 'medicine'));
    expect(labels[2].explanation, isNull);
  });

  test('empty notes have no labels', () {
    expect(parseNotes(null), isEmpty);
    expect(parseNotes(''), isEmpty);
  });

  test('appVersion matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version: ([^+\s]+)',
      multiLine: true,
    ).firstMatch(pubspec)![1];
    expect(appVersion, version);
  });
}
