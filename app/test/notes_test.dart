import 'dart:convert';
import 'dart:io';

import 'package:easydict/data/notes.dart';
import 'package:easydict/version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the app and website share all label explanations', () {
    final shared = jsonDecode(
      File('../web/web/note_labels.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(
      {
        for (final (code, (cs, en)) in noteExplanations) code: [cs, en],
      },
      shared,
      reason: 'Run python3 data/tools/generate_note_labels.py after editing the labels.',
    );
  });

  test('labels use the requested language and preserve unknown notes', () {
    final labels = parseNotes('v: [hovor.] [mužs. jméno] (acc) 2 10');
    expect(labels.map((label) => label.displayText('cs')), [
      'sloveso',
      'hovorově',
      '[mužs. jméno]',
      '(acc)',
    ]);
    expect(labels.map((label) => label.displayText('en')), [
      'verb',
      'colloquial',
      '[mužs. jméno]',
      '(acc)',
    ]);
  });

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

  test('only decimal priorities are hidden, other tokens remain visible', () {
    expect(
      parseNotes('1 +2 -3 10 0x10').map((label) => label.displayText('cs')),
      ['0x10'],
    );
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
