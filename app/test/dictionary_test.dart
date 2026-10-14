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
  late SqlDictionary dictionary;

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
    dictionary = await SqlDictionary.open(await IsolateSqlReader.open(db));
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
    expect(dictionary.entryCount, 16); // the untranslated row is left out
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

  test('typed diacritics pick the right base form', () async {
    // "nedělá" (does not do) folds like "neděla", a form of "neděle".
    final result = await dictionary.search(
      'nedělá',
      Language.cze,
      SearchMode.startsWith,
    );
    expect(result.baseForms, ['dělat']);
    expect(headwords(result), ['dělat']);
    // Without diacritics both readings are possible; the stored form wins.
    final folded = await dictionary.search(
      'nedela',
      Language.cze,
      SearchMode.startsWith,
    );
    expect(folded.baseForms, ['neděle']);
    // The same word from text with combining marks (decomposed, NFD).
    final decomposed = await dictionary.search(
      'nede\u030Cla\u0301',
      Language.cze,
      SearchMode.startsWith,
    );
    expect(decomposed.baseForms, ['dělat']);
  });

  test('negated forms without diacritics', () async {
    for (final query in ['nezelena', 'nezeleny', 'nezelená']) {
      final result = await dictionary.search(
        query,
        Language.cze,
        SearchMode.startsWith,
      );
      expect(result.baseForms, ['zelený'], reason: query);
    }
  });

  test('anywhere means the text as typed', () async {
    for (final query in ['dog%', 'washer%fluid', 'dog_']) {
      final result = await dictionary.search(
        query,
        Language.eng,
        SearchMode.fulltext,
      );
      expect(result.groups, isEmpty, reason: query);
    }
  });

  test('odd input is cleaned up', () async {
    final nul = await dictionary.search(
      'dog\u0000garbage',
      Language.eng,
      SearchMode.fulltext,
    );
    expect(nul.query, 'dog garbage');
    expect(nul.groups, isEmpty);
    final long = await dictionary.search(
      'a' * 60000,
      Language.eng,
      SearchMode.fulltext,
    );
    expect(long.query.length, Dictionary.maxQueryLength);
  });

  test('a newer query is not switched by an older fallback', () async {
    final search = DictionarySearch(
      dictionary,
      language: Language.eng,
      mode: SearchMode.startsWith,
    );
    search.lookUpText('psa'); // would switch to Czech if it could finish
    search.query = 'washer fluid';
    final done = Completer<void>();
    search.addListener(() {
      if (!search.searching && search.result.query == 'washer fluid') {
        if (!done.isCompleted) done.complete();
      }
    });
    await done.future.timeout(const Duration(seconds: 5));
    expect(search.language, Language.eng);
    expect(search.result.groups.first.headword, 'washer fluid');
    search.dispose();
  });

  test(
    'closing the reader answers pending queries and rejects new ones',
    () async {
      final reader = await IsolateSqlReader.open('${tmp.path}/test.sqlite');
      final pending = reader.select('SELECT count(*) AS n FROM entries');
      // Closing twice at the same time finishes both.
      await Future.wait([reader.close(), reader.close()]);
      await reader.close();
      expect((await pending).single['n'], 16);
      expect(reader.select('SELECT 1'), throwsStateError);
    },
  );

  group('many matches', () {
    late SqlDictionary big;
    late Directory bigTmp;

    setUpAll(() async {
      // 400 entries with "in", 400 with "the" and 20 with the phrase "in the":
      // the phrase must be found although each word alone fills the limit.
      bigTmp = await Directory.systemTemp.createTemp('easydict_big');
      final source = File('${bigTmp.path}/en-cs.txt');
      source.writeAsStringSync(
        [
          for (var i = 0; i < 400; i++) 'in a$i\tv a$i\t\t\t',
          for (var i = 0; i < 400; i++) 'the b$i\tto b$i\t\t\t',
          for (var i = 0; i < 20; i++) 'c$i in the d$i\tc v d$i\t\t\t',
          for (var i = 0; i < 400; i++) 'take care $i\tstarat se $i\t\t\t',
          'carving\tvyřezávání\tn:\t\t',
          // 5 001 entries with both words apart before the one with the phrase
          for (var i = 0; i < 5001; i++)
            'x${i.toString().padLeft(4, '0')} in aa the\tx\t\t\t',
          'zzzz in the\tz\t\t\t',
          // 301 headwords starting with "car" but not with the word "car"
          for (var i = 0; i < 301; i++) 'carvings $i\tc\t\t\t',
          'car thing\tvěc auta\t\t\t',
        ].join('\n'),
      );
      final db = '${bigTmp.path}/big.sqlite';
      final build = await Process.run('python3', [
        '../data/tools/build_db.py',
        db,
        '--en-cs',
        source.path,
        '--no-forms',
      ]);
      expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
      big = await SqlDictionary.open(await IsolateSqlReader.open(db));
    });

    tearDownAll(() async {
      await big.close();
      await bigTmp.delete(recursive: true);
    });

    test('a phrase is found among frequent words', () async {
      final result = await big.search(
        'in the',
        Language.eng,
        SearchMode.wholeWord,
      );
      expect(result.groups, hasLength(21));
      expect(
        result.groups.map((group) => group.headword),
        contains('zzzz in the'),
      );
      expect(result.truncated, isFalse);
    });

    test('a whole word at the start is not pushed out', () async {
      final result = await big.search(
        'car',
        Language.eng,
        SearchMode.wholeWord,
      );
      expect(
        result.groups.map((group) => group.headword),
        contains('car thing'),
      );
    });

    test('a prefix match is not pushed out by other matches', () async {
      // "car" is in 400 entries ("care"), but "carving" starts with it.
      final result = await big.search('car', Language.eng, SearchMode.fulltext);
      expect(result.groups.map((group) => group.headword), contains('carving'));
      expect(result.truncated, isTrue);
    });
  });
}
