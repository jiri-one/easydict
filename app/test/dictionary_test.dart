import 'dart:io';

import 'dart:async';

import 'package:easydict/data/dictionary.dart';
import 'package:easydict/data/open_dictionary.dart';
import 'package:easydict/search_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a small database from test/fixtures with data/tools/build_db.py and
/// searches it through the desktop SQLite binding.
void main() {
  late Directory tmp;
  late Dictionary dictionary;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('easydict_test');
    final db = '${tmp.path}/test.sqlite';
    final build = await Process.run('python3', [
      '../data/tools/build_db.py',
      db,
      '--en-cs',
      'test/fixtures/en-cs.txt',
      '--hunspell-dir',
      'test/fixtures/hunspell',
      '--wiktionary',
      'test/fixtures/forms.tsv',
    ]);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    dictionary = await Dictionary.open(await IsolateSqlReader.open(db));
  });

  tearDownAll(() async {
    await dictionary.close();
    await tmp.delete(recursive: true);
  });

  List<String> headwords(SearchResult result) => [
    for (final group in result.groups) group.headword,
  ];

  test('folding removes diacritics and case', () {
    expect(dictionary.fold('Žluťoučký KŮŇ'), 'zlutoucky kun');
    expect(dictionary.entryCount, 14); // the untranslated row is left out
  });

  test('translations are grouped by headword', () async {
    final result = await dictionary.search(
      'dog',
      Language.eng,
      SearchMode.startsWith,
    );
    expect(headwords(result), ['dog']);
    expect(
      [for (final e in result.groups.single.entries) e.cze],
      ['pes', 'čokl'],
    );
    expect(result.groups.single.entries.first.author, 'Milan Svoboda');
  });

  test('a Czech word in another form finds its base form', () async {
    final result = await dictionary.search(
      'psa',
      Language.cze,
      SearchMode.startsWith,
    );
    expect(result.baseForms, ['pes']);
    expect(headwords(result), ['pes', 'honicí pes']);
  });

  test('a headword is not taken for a form of another word', () async {
    // The fixture lists "žena" also as a form of "hnát" (like an old
    // transgressive); "žena" itself is a headword, so no base form is shown.
    final result = await dictionary.search(
      'žena',
      Language.cze,
      SearchMode.startsWith,
    );
    expect(result.baseForms, isEmpty);
    expect(headwords(result), ['žena']);
    final form = await dictionary.search(
      'ženu',
      Language.cze,
      SearchMode.startsWith,
    );
    expect(form.baseForms, ['hnát']);
  });

  test('irregular forms and missing diacritics', () async {
    final result = await dictionary.search(
      'sel',
      Language.cze,
      SearchMode.wholeWord,
    );
    expect(result.baseForms, ['jít']);
    expect(headwords(result), ['jít']);
  });

  test('negated forms are found without the prefix', () async {
    final result = await dictionary.search(
      'nezelená',
      Language.cze,
      SearchMode.startsWith,
    );
    expect(result.baseForms, ['zelený']);
    expect(headwords(result), ['zelený']);
  });

  test('the exact spelling comes first', () async {
    final result = await dictionary.search(
      'byt',
      Language.cze,
      SearchMode.wholeWord,
    );
    expect(headwords(result), ['byt', 'být']);
  });

  test('whole words and phrases', () async {
    expect(
      headwords(
        await dictionary.search(
          'washer fluid',
          Language.eng,
          SearchMode.wholeWord,
        ),
      ),
      ['washer fluid', 'windshield washer fluid'],
    );
    expect(
      headwords(
        await dictionary.search('done', Language.eng, SearchMode.wholeWord),
      ),
      ['well-done'],
    );
  });

  test('anywhere in the text, without diacritics', () async {
    final result = await dictionary.search(
      'ostrikovacu',
      Language.cze,
      SearchMode.fulltext,
    );
    expect(headwords(result), ['kapalina do ostřikovačů']);
    expect(result.groups.single.entries, hasLength(2));
  });

  test('special characters do not break the search', () async {
    for (final query in ['%', '_', r'\', "'", '"']) {
      for (final mode in SearchMode.values) {
        final result = await dictionary.search(query, Language.eng, mode);
        expect(result.groups, isEmpty);
      }
    }
    expect(
      (await dictionary.search(
        '  ',
        Language.eng,
        SearchMode.startsWith,
      )).groups,
      isEmpty,
    );
  });

  test('text from outside switches the language when needed', () async {
    final search = DictionarySearch(
      dictionary,
      language: Language.eng,
      mode: SearchMode.startsWith,
    );
    Future<void> settled() {
      final done = Completer<void>();
      void listener() {
        if (!search.searching && !done.isCompleted) done.complete();
      }

      search.addListener(listener);
      return done.future.whenComplete(() => search.removeListener(listener));
    }

    var finished = settled();
    search.lookUpText('psa'); // no Czech letters, nothing in English
    await finished;
    expect(search.language, Language.cze);
    expect(search.result.groups.first.headword, 'pes');

    finished = settled();
    search.lookUpText('čokl'); // Czech letters
    await finished;
    expect(search.language, Language.cze);
    expect(search.result.groups.single.entries.single.eng, 'dog');
    search.dispose();
  });
}
