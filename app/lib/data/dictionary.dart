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

/// The web app has no database: it searches on the website (RemoteDictionary).
abstract interface class Dictionary {
  /// Longer queries are cut: nobody types them, and SQLite rejects too long
  /// LIKE patterns.
  static const maxQueryLength = 100;

  int get entryCount;

  Map<String, String> get meta;

  Future<SearchResult> search(String query, Language language, SearchMode mode);

  Future<void> close();
}

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
    this.engRank = 0,
    this.czeRank = 0,
  });

  factory Entry.fromRow(Map<String, Object?> row) => Entry(
    id: row['id']! as int,
    eng: row['eng']! as String,
    cze: row['cze']! as String,
    notes: row['notes'] as String?,
    special: row['special'] as String?,
    author: row['author'] as String?,
    engRank: row['eng_rank']! as int,
    czeRank: row['cze_rank']! as int,
  );

  final int id;
  final String eng;
  final String cze;
  final String? notes;
  final String? special;
  final String? author;

  /// How common the English and the Czech text are (word frequency).
  final int engRank;
  final int czeRank;

  String text(Language language) => language == Language.eng ? eng : cze;

  int rank(Language language) => language == Language.eng ? engRank : czeRank;
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

  /// Some matches were left out because of [SqlDictionary.rowLimit].
  final bool truncated;

  bool get isEmpty => groups.isEmpty;
}

/// The website searches the same way (web/web/dictionary.py): a change belongs
/// to both.
class SqlDictionary implements Dictionary {
  SqlDictionary._(this._db, this._foldMap, this._negationPrefixes, this.meta);

  static const schemaVersion = '2';

  /// Maximum number of rows taken from one query.
  static const rowLimit = 300;

  static final _wordPattern = RegExp(r'[\p{L}\p{N}]+', unicode: true);
  static const _columns =
      'e.id, e.eng, e.cze, e.notes, e.special, e.author, e.eng_rank, e.cze_rank';

  final SqlReader _db;
  final Map<String, String> _foldMap;
  final List<String> _negationPrefixes;
  @override
  final Map<String, String> meta;

  static Future<SqlDictionary> open(SqlReader db) async {
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
    return SqlDictionary._(db, foldMap, prefixes, meta);
  }

  @override
  int get entryCount => int.parse(meta['entries'] ?? '0');

  @override
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

  static final _unsafeCharacters = RegExp(r'[\u0000-\u001F\u007F]');
  static final _combiningMarks = RegExp(r'[\u0300-\u036F]');
  static final _decomposed = RegExp(r'[A-Za-z][\u0301\u030A\u030C]');

  /// Czech letters written as a base letter and a combining mark (text from
  /// some macOS apps): composed, so that they compare equal to typed ones.
  static const _compositions = {
    'a\u0301': 'á',
    'e\u0301': 'é',
    'i\u0301': 'í',
    'o\u0301': 'ó',
    'u\u0301': 'ú',
    'y\u0301': 'ý',
    'A\u0301': 'Á',
    'E\u0301': 'É',
    'I\u0301': 'Í',
    'O\u0301': 'Ó',
    'U\u0301': 'Ú',
    'Y\u0301': 'Ý',
    'u\u030A': 'ů',
    'U\u030A': 'Ů',
    'c\u030C': 'č',
    'd\u030C': 'ď',
    'e\u030C': 'ě',
    'n\u030C': 'ň',
    'r\u030C': 'ř',
    's\u030C': 'š',
    't\u030C': 'ť',
    'z\u030C': 'ž',
    'C\u030C': 'Č',
    'D\u030C': 'Ď',
    'E\u030C': 'Ě',
    'N\u030C': 'Ň',
    'R\u030C': 'Ř',
    'S\u030C': 'Š',
    'T\u030C': 'Ť',
    'Z\u030C': 'Ž',
  };

  static String _composeCzech(String text) => text.replaceAllMapped(
    _decomposed,
    (match) => _compositions[match[0]!] ?? match[0]!,
  );

  @override
  Future<SearchResult> search(
    String query,
    Language language,
    SearchMode mode,
  ) async {
    var text = _composeCzech(query.replaceAll(_unsafeCharacters, ' ')).trim();
    if (text.length > Dictionary.maxQueryLength) {
      text = text.substring(0, Dictionary.maxQueryLength).trim();
    }
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

    // Each mode also takes the better kinds of matches (the start of the
    // headword, whole words), so that the row limit of the broad query cannot
    // push them out before the final ranking.
    final parts = switch (mode) {
      SearchMode.startsWith => [await _startsWith(key, language)],
      SearchMode.wholeWord => [
        await _startsWithWords(tokens, key, language),
        await _wholeWord(tokens, key, language),
      ],
      SearchMode.fulltext => [
        await _startsWith(key, language),
        await _wholeWord(tokens, key, language),
        await _fulltext(key, language),
      ],
    };
    final direct = [
      for (final (entries, _) in parts)
        for (final entry in entries)
          // "Anywhere" means the text as typed, also with "%" or "-" in it.
          if (mode != SearchMode.fulltext ||
              fold(entry.text(language)).contains(key))
            entry,
    ];
    var truncated = parts.any((part) => part.$2);

    var baseForms = const <String>[];
    final viaBaseForm = <Entry>[];
    // A typed word that is a headword itself needs no base form: "žena" is
    // also a rare form of "hnát", but nobody looking up "žena" means that.
    final isHeadword = direct.any((entry) => fold(entry.text(language)) == key);
    if (language == Language.cze && tokens.length == 1 && !isHeadword) {
      baseForms = [
        for (final lemma in await _baseForms(tokens.single, _exactWord(text)))
          if (fold(lemma) != key) lemma,
      ];
      for (final lemma in baseForms) {
        final (rows, more) = await _wholeWord(
          [fold(lemma)],
          fold(lemma),
          language,
        );
        truncated |= more;
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

  /// The typed word in lowercase, when it is one word typed with diacritics;
  /// null otherwise (without diacritics, any diacritics may be meant).
  String? _exactWord(String text) {
    if (_combiningMarks.hasMatch(text)) return null;
    final exact = words(text.toLowerCase());
    if (exact.length != 1 || fold(exact.single) == exact.single) return null;
    return exact.single;
  }

  Future<List<Entry>> _entries(String sql, List<Object?> arguments) async => [
    for (final row in await _db.select(sql, arguments)) Entry.fromRow(row),
  ];

  /// The exact match first, then the most common texts, then the shortest.
  static String _order(Language language, int limit, [int offset = 0]) {
    final column = 'e.${language.name}_key';
    return 'ORDER BY $column = ? DESC, e.${language.name}_rank DESC, '
        'length($column), $column, e.id LIMIT $limit OFFSET $offset';
  }

  /// Entries whose headword starts with [key]; true when more were left out.
  Future<(List<Entry>, bool)> _startsWith(String key, Language language) async {
    final column = '${language.name}_key';
    final entries = await _entries(
      'SELECT $_columns FROM entries e '
      'WHERE e.$column >= ? AND e.$column < ? ${_order(language, rowLimit + 1)}',
      [key, '$key\u{10FFFF}', key],
    );
    return _limited(entries);
  }

  /// Entries whose headword starts with the whole words of [tokens].
  Future<(List<Entry>, bool)> _startsWithWords(
    List<String> tokens,
    String key,
    Language language,
  ) async {
    final column = '${language.name}_key';
    // The word must end where the typed text ends ("car thing", not
    // "carving"), checked before the limit.
    final entries = await _entries(
      'SELECT $_columns FROM entries e '
      'WHERE e.$column >= ? AND e.$column < ? AND (length(e.$column) = ? '
      "OR substr(e.$column, ? + 1, 1) NOT GLOB '[a-z0-9]') "
      '${_order(language, rowLimit + 1)}',
      [key, '$key\u{10FFFF}', key.length, key.length, key],
    );
    return _limited([
      for (final entry in entries)
        if (_startsWithPhrase(words(fold(entry.text(language))), tokens)) entry,
    ]);
  }

  /// Entries containing the words of [tokens] next to each other.
  Future<(List<Entry>, bool)> _wholeWord(
    List<String> tokens,
    String key,
    Language language,
  ) async {
    final column = '${language.name}_key';
    if (tokens.length == 1) {
      final entries = await _entries(
        'SELECT $_columns FROM words w JOIN entries e ON e.id = w.entry_id '
        'WHERE w.lang = ? AND w.word = ? ${_order(language, rowLimit + 1)}',
        [language.code, tokens.single, key],
      );
      return _limited(entries);
    }
    // A phrase: look the rarest word up, let SQLite keep the entries that
    // have all the words in this order, then check the word boundaries.
    var rarest = tokens.first;
    var fewest = -1;
    for (final token in tokens.toSet()) {
      final rows = await _db.select(
        'SELECT count(*) AS n FROM words WHERE lang = ? AND word = ?',
        [language.code, token],
      );
      final count = rows.single['n']! as int;
      if (count == 0) return (const <Entry>[], false);
      if (fewest < 0 || count < fewest) {
        fewest = count;
        rarest = token;
      }
    }
    // Page through the candidates until there are enough real matches.
    const page = 2000;
    final matches = <Entry>[];
    for (var offset = 0; matches.length <= rowLimit; offset += page) {
      final candidates = await _entries(
        'SELECT $_columns FROM words w JOIN entries e ON e.id = w.entry_id '
        'WHERE w.lang = ? AND w.word = ? AND e.$column LIKE ? ESCAPE ? '
        '${_order(language, page, offset)}',
        [
          language.code,
          rarest,
          '%${tokens.map(_escapeLike).join('%')}%',
          r'\',
          key,
        ],
      );
      matches.addAll(
        candidates.where(
          (entry) => _containsPhrase(words(fold(entry.text(language))), tokens),
        ),
      );
      if (candidates.length < page) break;
    }
    return _limited(matches);
  }

  /// Entries containing [key] anywhere.
  Future<(List<Entry>, bool)> _fulltext(String key, Language language) async {
    final column = '${language.name}_key';
    final entries = await _entries(
      'SELECT $_columns FROM entries e WHERE e.$column LIKE ? ESCAPE ? '
      '${_order(language, rowLimit + 1)}',
      ['%${_escapeLike(key)}%', r'\', key],
    );
    return _limited(entries);
  }

  static (List<Entry>, bool) _limited(List<Entry> entries) =>
      entries.length > rowLimit
      ? (entries.sublist(0, rowLimit), true)
      : (entries, false);

  /// Base forms of a Czech word ([key] folded, [exact] as typed with its
  /// diacritics); empty when the word is a base form itself.
  ///
  /// With diacritics typed, forms with the same diacritics win, so "nedělá"
  /// finds "dělat" and not "neděle" (whose form "neděla" folds the same).
  Future<List<String>> _baseForms(String key, String? exact) async {
    final found = await _baseFormsMatching(key, exact);
    if (found != null && found.isEmpty && exact != null) {
      // Nothing with the typed diacritics: they may be wrong, try any.
      return await _baseFormsMatching(key, null) ?? const [];
    }
    return found ?? const [];
  }

  /// Base forms of forms equal to [exact] (any form with the folded [key]
  /// when null); null when the word is a base form itself.
  Future<List<String>?> _baseFormsMatching(String key, String? exact) async {
    final lemmas = _lemmasOf(await _formRows(key), exact);
    if (lemmas.isNotEmpty) return lemmas;
    final word = await _czechWord(key);
    if (word != null && (exact == null || word == exact)) return null;
    // Negated and superlative forms are not stored: try without the prefix.
    for (final prefix in _negationPrefixes) {
      if (key.length <= prefix.length + 1 ||
          !key.startsWith(prefix) ||
          // "něco" folds to "neco" but has no "ne-" to strip
          (exact != null && !exact.startsWith(prefix))) {
        continue;
      }
      final restKey = key.substring(prefix.length);
      final restExact = exact?.substring(prefix.length);
      final restLemmas = _lemmasOf(await _formRows(restKey), restExact);
      if (restLemmas.isNotEmpty) return restLemmas;
      final restWord = await _czechWord(restKey);
      if (restWord != null && (restExact == null || restWord == restExact)) {
        return [restWord];
      }
    }
    return const [];
  }

  Future<List<(String, String)>> _formRows(String key) async => [
    for (final row in await _db.select(
      'SELECT form, lemma FROM cs_forms_hunspell WHERE form_key = ? '
      'UNION SELECT form, lemma FROM cs_forms_wiktionary WHERE form_key = ?',
      [key, key],
    ))
      (row['form']! as String, row['lemma']! as String),
  ];

  /// The lemmas of the rows whose form is [exact] (any form when null).
  static List<String> _lemmasOf(List<(String, String)> rows, String? exact) => {
    for (final (form, lemma) in rows)
      if (exact == null || form == exact) lemma,
  }.toList();

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
    final scored = <int, _Score>{};

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
      final score = _Score(tier, exact, headKey, entry, language);
      final previous = scored[entry.id];
      if (previous == null || score.compareTo(previous) < 0) {
        scored[entry.id] = score;
      }
    }

    for (final entry in direct) {
      add(entry, fromBaseForm: false);
    }
    for (final entry in viaBaseForm) {
      add(entry, fromBaseForm: true);
    }

    final sorted = scored.values.toList()..sort();
    final groups = <String, ResultGroup>{};
    for (final _Score(:entry) in sorted) {
      final head = entry.text(language);
      groups.putIfAbsent(head, () => ResultGroup(head, [])).entries.add(entry);
    }
    return groups.values.toList();
  }

  static bool _startsWithPhrase(List<String> haystack, List<String> phrase) =>
      haystack.length >= phrase.length &&
      _containsPhrase(haystack.sublist(0, phrase.length), phrase);

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

/// The order of results: how well the headword matches, how common it is,
/// then (within a headword) how common the translation is.
class _Score implements Comparable<_Score> {
  _Score(this.tier, this.exact, this.headKey, this.entry, Language language)
    : headRank = entry.rank(language),
      translationRank = entry.rank(language.other);

  final int tier;
  final int exact;
  final String headKey;
  final Entry entry;
  final int headRank;
  final int translationRank;

  @override
  int compareTo(_Score other) {
    var result = tier.compareTo(other.tier);
    if (result == 0) result = exact.compareTo(other.exact);
    if (result == 0) result = other.headRank.compareTo(headRank);
    if (result == 0) result = headKey.length.compareTo(other.headKey.length);
    if (result == 0) result = headKey.compareTo(other.headKey);
    // Same headword: the most common translation first.
    if (result == 0) result = other.translationRank.compareTo(translationRank);
    if (result == 0) result = entry.id.compareTo(other.entry.id);
    return result;
  }
}
