import 'dart:convert';

/// The side of the dictionary that is searched.
enum Language {
  eng,
  cze;

  Language get other => this == eng ? cze : eng;

  /// Value of `words.lang` in the database.
  int get code => index;
}

enum SearchMode { startsWith, wholeWord, fulltext }

/// Read access to the dictionary database.
abstract interface class SqlReader {
  Future<List<Map<String, Object?>>> select(
    String sql, [
    List<Object?> arguments = const [],
  ]);

  Future<void> close();
}

/// One translation: a row of the dictionary.
class Entry {
  const Entry({
    required this.id,
    required this.eng,
    required this.cze,
    this.notes,
    this.special,
    this.author,
  });

  factory Entry.fromRow(Map<String, Object?> row) => Entry(
    id: row['id']! as int,
    eng: row['eng']! as String,
    cze: row['cze']! as String,
    notes: row['notes'] as String?,
    special: row['special'] as String?,
    author: row['author'] as String?,
  );

  final int id;
  final String eng;
  final String cze;
  final String? notes;
  final String? special;
  final String? author;

  String text(Language language) => language == Language.eng ? eng : cze;
}

/// The translations of one headword.
class ResultGroup {
  ResultGroup(this.headword, this.entries);

  final String headword;
  final List<Entry> entries;
}

class SearchResult {
  const SearchResult({
    required this.query,
    required this.language,
    required this.mode,
    required this.groups,
    this.baseForms = const [],
    this.truncated = false,
  });

  static const empty = SearchResult(
    query: '',
    language: Language.eng,
    mode: SearchMode.startsWith,
    groups: [],
  );

  final String query;
  final Language language;
  final SearchMode mode;
  final List<ResultGroup> groups;

  /// Base forms of a Czech word typed in another form ("psa" -> "pes").
  final List<String> baseForms;

  /// Some matches were left out because of [Dictionary.rowLimit].
  final bool truncated;

  bool get isEmpty => groups.isEmpty;
}

/// Searches the database built by data/tools/build_db.py.
class Dictionary {
  Dictionary._(this._db, this._foldMap, this._negationPrefixes, this.meta);

  static const schemaVersion = '1';

  /// Maximum number of rows taken from one query.
  static const rowLimit = 300;

  static final _wordPattern = RegExp(r'[\p{L}\p{N}]+', unicode: true);
  static const _columns = 'e.id, e.eng, e.cze, e.notes, e.special, e.author';

  final SqlReader _db;
  final Map<String, String> _foldMap;
  final List<String> _negationPrefixes;
  final Map<String, String> meta;

  static Future<Dictionary> open(SqlReader db) async {
    final meta = {
      for (final row in await db.select('SELECT key, value FROM meta'))
        row['key']! as String: row['value']! as String,
    };
    if (meta['schema_version'] != schemaVersion) {
      throw StateError(
        'Unsupported dictionary schema ${meta['schema_version']}, '
        'expected $schemaVersion.',
      );
    }
    final foldMap = (jsonDecode(meta['fold_map']!) as Map<String, Object?>)
        .cast<String, String>();
    final prefixes = (jsonDecode(meta['negation_prefixes']!) as List<Object?>)
        .cast<String>();
    return Dictionary._(db, foldMap, prefixes, meta);
  }

  int get entryCount => int.parse(meta['entries'] ?? '0');

  Future<void> close() => _db.close();

  /// Lowercase [text] and remove diacritics, the same way the database keys
  /// were made.
  String fold(String text) {
    final buffer = StringBuffer();
    for (final rune in text.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_foldMap[char] ?? char);
    }
    return buffer.toString();
  }

  static List<String> words(String text) => [
    for (final match in _wordPattern.allMatches(text)) match[0]!,
  ];

  Future<SearchResult> search(
    String query,
    Language language,
    SearchMode mode,
  ) async {
    final text = query.trim();
    final key = fold(text);
    final tokens = words(key);
    if (tokens.isEmpty) {
      return SearchResult(
        query: text,
        language: language,
        mode: mode,
        groups: const [],
      );
    }

    final direct = switch (mode) {
      SearchMode.startsWith => await _startsWith(key, language),
      SearchMode.wholeWord => await _wholeWord(tokens, language),
      SearchMode.fulltext => await _fulltext(key, language),
    };
    var truncated = direct.length >= rowLimit;

    var baseForms = const <String>[];
    final viaBaseForm = <Entry>[];
    if (language == Language.cze && tokens.length == 1) {
      baseForms = [
        for (final lemma in await _baseForms(tokens.single))
          if (fold(lemma) != key) lemma,
      ];
      for (final lemma in baseForms) {
        final rows = await _wholeWord([fold(lemma)], language);
        truncated |= rows.length >= rowLimit;
        // The folded lookup also finds words that differ in diacritics only
        // ("byt" for "být"), so keep the entries with the exact base form.
        viaBaseForm.addAll(
          rows.where((entry) => words(entry.cze.toLowerCase()).contains(lemma)),
        );
      }
    }

    return SearchResult(
      query: text,
      language: language,
      mode: mode,
      groups: _rankAndGroup(
        text,
        key,
        language,
        direct,
        viaBaseForm,
        baseForms,
      ),
      baseForms: baseForms,
      truncated: truncated,
    );
  }

  Future<List<Entry>> _entries(String sql, List<Object?> arguments) async => [
    for (final row in await _db.select(sql, arguments)) Entry.fromRow(row),
  ];

  Future<List<Entry>> _startsWith(String key, Language language) {
    final column = '${language.name}_key';
    return _entries(
      'SELECT $_columns FROM entries e '
      'WHERE e.$column >= ? AND e.$column < ? '
      'ORDER BY length(e.$column), e.$column, e.id LIMIT $rowLimit',
      [key, '$key\u{10FFFF}'],
    );
  }

  Future<List<Entry>> _wholeWord(List<String> tokens, Language language) async {
    // Look the rarest word up, then keep the entries with the whole phrase.
    var rarest = tokens.first;
    if (tokens.length > 1) {
      var fewest = -1;
      for (final token in tokens.toSet()) {
        final rows = await _db.select(
          'SELECT count(*) AS n FROM words WHERE lang = ? AND word = ?',
          [language.code, token],
        );
        final count = rows.single['n']! as int;
        if (count == 0) return const [];
        if (fewest < 0 || count < fewest) {
          fewest = count;
          rarest = token;
        }
      }
    }
    final column = '${language.name}_key';
    final entries = await _entries(
      'SELECT $_columns FROM words w JOIN entries e ON e.id = w.entry_id '
      'WHERE w.lang = ? AND w.word = ? '
      'ORDER BY length(e.$column), e.$column, e.id LIMIT $rowLimit',
      [language.code, rarest],
    );
    if (tokens.length == 1) return entries;
    return [
      for (final entry in entries)
        if (_containsPhrase(words(fold(entry.text(language))), tokens)) entry,
    ];
  }

  Future<List<Entry>> _fulltext(String key, Language language) {
    final column = '${language.name}_key';
    return _entries(
      'SELECT $_columns FROM entries e WHERE e.$column LIKE ? ESCAPE ? '
      'ORDER BY length(e.$column), e.$column, e.id LIMIT $rowLimit',
      ['%${_escapeLike(key)}%', r'\'],
    );
  }

  /// Base forms of a folded Czech word; empty when the word is a base form.
  Future<List<String>> _baseForms(String token) async {
    final lemmas = await _lemmasOf(token);
    if (lemmas.isNotEmpty || await _czechWord(token) != null) return lemmas;
    // Negated and superlative forms are not stored: try without the prefix.
    for (final prefix in _negationPrefixes) {
      if (token.length <= prefix.length + 1 || !token.startsWith(prefix)) {
        continue;
      }
      final rest = token.substring(prefix.length);
      final restLemmas = await _lemmasOf(rest);
      if (restLemmas.isNotEmpty) return restLemmas;
      final word = await _czechWord(rest);
      if (word != null) return [word];
    }
    return const [];
  }

  Future<List<String>> _lemmasOf(String key) async => [
    for (final row in await _db.select(
      'SELECT lemma FROM cs_forms_hunspell WHERE form = ? '
      'UNION SELECT lemma FROM cs_forms_wiktionary WHERE form = ?',
      [key, key],
    ))
      row['lemma']! as String,
  ];

  /// The word with diacritics as it is written in the dictionary, or null.
  Future<String?> _czechWord(String key) async {
    final rows = await _db.select(
      'SELECT e.cze FROM words w JOIN entries e ON e.id = w.entry_id '
      'WHERE w.lang = 1 AND w.word = ? LIMIT 20',
      [key],
    );
    for (final row in rows) {
      for (final word in words((row['cze']! as String).toLowerCase())) {
        if (fold(word) == key) return word;
      }
    }
    return null;
  }

  List<ResultGroup> _rankAndGroup(
    String text,
    String key,
    Language language,
    List<Entry> direct,
    List<Entry> viaBaseForm,
    List<String> baseForms,
  ) {
    final lowerText = text.toLowerCase();
    final baseKeys = {for (final lemma in baseForms) fold(lemma)};
    final scored = <int, (int, int, int, String, Entry)>{};

    void add(Entry entry, {required bool fromBaseForm}) {
      final head = entry.text(language);
      final headKey = fold(head);
      final int tier;
      if (headKey == key) {
        tier = 0;
      } else if (baseKeys.contains(headKey)) {
        tier = 1;
      } else if (!fromBaseForm && headKey.startsWith(key)) {
        tier = 2;
      } else if (!fromBaseForm && _containsPhrase(words(headKey), words(key))) {
        tier = 3;
      } else if (fromBaseForm) {
        tier = 4;
      } else {
        tier = 5;
      }
      // Exact spelling (with diacritics) first: "být" before "byt".
      final exact =
          head.toLowerCase() == lowerText ||
              baseForms.contains(head.toLowerCase())
          ? 0
          : 1;
      final score = (tier, exact, headKey.length, headKey, entry);
      final previous = scored[entry.id];
      if (previous == null || _compare(score, previous) < 0) {
        scored[entry.id] = score;
      }
    }

    for (final entry in direct) {
      add(entry, fromBaseForm: false);
    }
    for (final entry in viaBaseForm) {
      add(entry, fromBaseForm: true);
    }

    final sorted = scored.values.toList()..sort(_compare);
    final groups = <String, ResultGroup>{};
    for (final (_, _, _, _, entry) in sorted) {
      final head = entry.text(language);
      groups.putIfAbsent(head, () => ResultGroup(head, [])).entries.add(entry);
    }
    return groups.values.toList();
  }

  static int _compare(
    (int, int, int, String, Entry) a,
    (int, int, int, String, Entry) b,
  ) {
    var result = a.$1.compareTo(b.$1);
    if (result == 0) result = a.$2.compareTo(b.$2);
    if (result == 0) result = a.$3.compareTo(b.$3);
    if (result == 0) result = a.$4.compareTo(b.$4);
    if (result == 0) result = a.$5.id.compareTo(b.$5.id);
    return result;
  }

  static bool _containsPhrase(List<String> haystack, List<String> phrase) {
    for (var start = 0; start + phrase.length <= haystack.length; start++) {
      var matches = true;
      for (var i = 0; i < phrase.length && matches; i++) {
        matches = haystack[start + i] == phrase[i];
      }
      if (matches) return true;
    }
    return false;
  }

  static String _escapeLike(String text) => text
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}
