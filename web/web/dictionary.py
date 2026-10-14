"""A port of app/lib/data/dictionary.dart, so that the website finds exactly what the app finds.
A change of the search belongs to both; web/tests/test_dictionary.py runs the app's tests here.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field

from django.db import connection

from .models import CZE, ENG

LANGUAGES = {"eng": ENG, "cze": CZE}
MODES = ("startsWith", "wholeWord", "fulltext")
SCHEMA_VERSION = "2"

ROW_LIMIT = 300
# nobody types longer queries
MAX_QUERY_LENGTH = 100

# must split words like data/tools/build_db.py, which made the words table
_WORD = re.compile(r"[^\W_]+")
_UNSAFE_CHARACTERS = re.compile(r"[\x00-\x1f\x7f]")
_COMBINING_MARKS = re.compile(r"[\u0300-\u036f]")
_DECOMPOSED = re.compile(r"[A-Za-z][\u0301\u030a\u030c]")
# Some macOS apps write Czech letters decomposed; typed text and the dictionary are composed.
_COMPOSITIONS = {
    **{base + "\u0301": composed for base, composed in zip("aeiouyAEIOUY", "áéíóúýÁÉÍÓÚÝ")},
    "u\u030a": "ů",
    "U\u030a": "Ů",
    **{base + "\u030c": composed for base, composed in zip("cdenrstzCDENRSTZ", "čďěňřšťžČĎĚŇŘŠŤŽ")},
}

_COLUMNS = (
    "r.id, r.eng, r.cze, r.notes_cze AS notes, r.special_cze AS special, r.author, "
    "r.eng_rank, r.cze_rank"
)


@dataclass
class Entry:
    id: int
    eng: str
    cze: str
    notes: str | None
    special: str | None
    author: str | None
    eng_rank: int
    cze_rank: int

    def text(self, language: str) -> str:
        return self.eng if language == "eng" else self.cze

    def rank(self, language: str) -> int:
        return self.eng_rank if language == "eng" else self.cze_rank


@dataclass
class Group:
    headword: str
    entries: list[Entry] = field(default_factory=list)


@dataclass
class SearchResult:
    query: str
    language: str
    mode: str
    groups: list[Group]
    base_forms: list[str] = field(default_factory=list)
    truncated: bool = False

    def as_json(self) -> dict:
        return {
            "query": self.query,
            "language": self.language,
            "mode": self.mode,
            "base_forms": self.base_forms,
            "truncated": self.truncated,
            "groups": [
                {"headword": group.headword, "entries": [vars(entry) for entry in group.entries]}
                for group in self.groups
            ],
        }


class DictionaryNotImported(Exception):
    """The dictionary tables are empty: run `manage.py import_dictionary`."""


def other(language: str) -> str:
    return "cze" if language == "eng" else "eng"


def words(text: str) -> list[str]:
    return _WORD.findall(text)


def _compose_czech(text: str) -> str:
    return _DECOMPOSED.sub(lambda match: _COMPOSITIONS.get(match[0], match[0]), text)


def _escape_like(text: str) -> str:
    return text.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


def _starts_with_phrase(haystack: list[str], phrase: list[str]) -> bool:
    return len(haystack) >= len(phrase) and haystack[: len(phrase)] == phrase


def _contains_phrase(haystack: list[str], phrase: list[str]) -> bool:
    return any(
        haystack[start : start + len(phrase)] == phrase
        for start in range(len(haystack) - len(phrase) + 1)
    )


def _limited(entries: list[Entry]) -> tuple[list[Entry], bool]:
    return (entries[:ROW_LIMIT], True) if len(entries) > ROW_LIMIT else (entries, False)


class Dictionary:
    def __init__(self, meta: dict[str, str]):
        if meta.get("schema_version") != SCHEMA_VERSION:
            raise DictionaryNotImported(
                f"Dictionary schema {meta.get('schema_version')}, expected {SCHEMA_VERSION}."
            )
        self.meta = meta
        self._fold_table = str.maketrans(json.loads(meta["fold_map"]))
        self._negation_prefixes = json.loads(meta["negation_prefixes"])

    @classmethod
    def load(cls) -> Dictionary:
        with connection.cursor() as cursor:
            cursor.execute("SELECT key, value FROM web_dictionarymeta")
            return cls(dict(cursor.fetchall()))

    @property
    def entry_count(self) -> int:
        return int(self.meta.get("entries", "0"))

    def fold(self, text: str) -> str:
        return text.lower().translate(self._fold_table)

    def _select(self, sql: str, arguments: list) -> list[tuple]:
        with connection.cursor() as cursor:
            cursor.execute(sql, arguments)
            return cursor.fetchall()

    def _entries(self, sql: str, arguments: list) -> list[Entry]:
        return [Entry(*row) for row in self._select(sql, arguments)]

    def search(self, query: str, language: str, mode: str) -> SearchResult:
        # both become part of the SQL (column names)
        if language not in LANGUAGES or mode not in MODES:
            raise ValueError(f"Unknown language {language!r} or mode {mode!r}.")
        text = _compose_czech(_UNSAFE_CHARACTERS.sub(" ", query)).strip()
        if len(text) > MAX_QUERY_LENGTH:
            text = text[:MAX_QUERY_LENGTH].strip()
        key = self.fold(text)
        tokens = words(key)
        if not tokens:
            return SearchResult(text, language, mode, [])

        # Each mode also takes the better kinds of matches (the start of the headword, whole
        # words), so that the row limit of the broad query cannot push them out before the
        # final ranking.
        if mode == "startsWith":
            parts = [self._starts_with(key, language)]
        elif mode == "wholeWord":
            parts = [
                self._starts_with_words(tokens, key, language),
                self._whole_word(tokens, key, language),
            ]
        else:
            parts = [
                self._starts_with(key, language),
                self._whole_word(tokens, key, language),
                self._fulltext(key, language),
            ]
        direct = [
            entry
            for entries, _ in parts
            for entry in entries
            # "Anywhere" means the text as typed, also with "%" or "-" in it.
            if mode != "fulltext" or key in self.fold(entry.text(language))
        ]
        truncated = any(more for _, more in parts)

        base_forms: list[str] = []
        via_base_form: list[Entry] = []
        # A typed word that is a headword itself needs no base form: "žena" is also a rare form
        # of "hnát", but nobody looking up "žena" means that.
        is_headword = any(self.fold(entry.text(language)) == key for entry in direct)
        if language == "cze" and len(tokens) == 1 and not is_headword:
            base_forms = [
                lemma
                for lemma in self._base_forms(tokens[0], self._exact_word(text))
                if self.fold(lemma) != key
            ]
            for lemma in base_forms:
                rows, more = self._whole_word([self.fold(lemma)], self.fold(lemma), language)
                truncated |= more
                # The folded lookup also finds words that differ in diacritics only ("byt" for
                # "být"), so keep the entries with the exact base form.
                via_base_form += [entry for entry in rows if lemma in words(entry.cze.lower())]

        return SearchResult(
            query=text,
            language=language,
            mode=mode,
            groups=self._rank_and_group(text, key, language, direct, via_base_form, base_forms),
            base_forms=base_forms,
            truncated=truncated,
        )

    def _exact_word(self, text: str) -> str | None:
        if _COMBINING_MARKS.search(text):
            return None
        exact = words(text.lower())
        # without diacritics typed, any diacritics may be meant
        if len(exact) != 1 or self.fold(exact[0]) == exact[0]:
            return None
        return exact[0]

    @staticmethod
    def _order(language: str, limit: int, offset: int = 0) -> str:
        column = f"r.{language}_key"
        return (
            f"ORDER BY {column} = %s DESC, r.{language}_rank DESC, length({column}), {column}, "
            f"r.id LIMIT {limit} OFFSET {offset}"
        )

    def _starts_with(self, key: str, language: str) -> tuple[list[Entry], bool]:
        column = f"{language}_key"
        entries = self._entries(
            f"SELECT {_COLUMNS} FROM web_record r WHERE r.{column} >= %s AND r.{column} < %s "
            + self._order(language, ROW_LIMIT + 1),
            [key, key + "\U0010ffff", key],
        )
        return _limited(entries)

    def _starts_with_words(
        self, tokens: list[str], key: str, language: str
    ) -> tuple[list[Entry], bool]:
        column = f"{language}_key"
        # The word must end where the typed text ends ("car thing", not "carving"), checked
        # before the limit.
        entries = self._entries(
            f"SELECT {_COLUMNS} FROM web_record r WHERE r.{column} >= %s AND r.{column} < %s "
            f"AND (length(r.{column}) = %s OR substr(r.{column}, %s + 1, 1) !~ '^[a-z0-9]$') "
            + self._order(language, ROW_LIMIT + 1),
            [key, key + "\U0010ffff", len(key), len(key), key],
        )
        return _limited(
            [
                entry
                for entry in entries
                if _starts_with_phrase(words(self.fold(entry.text(language))), tokens)
            ]
        )

    def _whole_word(self, tokens: list[str], key: str, language: str) -> tuple[list[Entry], bool]:
        column = f"{language}_key"
        lang = LANGUAGES[language]
        if len(tokens) == 1:
            entries = self._entries(
                f"SELECT {_COLUMNS} FROM web_word w JOIN web_record r ON r.id = w.record_id "
                "WHERE w.lang = %s AND w.word = %s " + self._order(language, ROW_LIMIT + 1),
                [lang, tokens[0], key],
            )
            return _limited(entries)
        # the rarest word of a phrase gives the fewest candidates
        rarest, fewest = tokens[0], -1
        for token in dict.fromkeys(tokens):
            [(count,)] = self._select(
                "SELECT count(*) FROM web_word WHERE lang = %s AND word = %s", [lang, token]
            )
            if count == 0:
                return [], False
            if fewest < 0 or count < fewest:
                rarest, fewest = token, count
        # One LIMIT could end before the real matches: many candidates fail the boundary check.
        page = 2000
        matches: list[Entry] = []
        offset = 0
        while len(matches) <= ROW_LIMIT:
            candidates = self._entries(
                f"SELECT {_COLUMNS} FROM web_word w JOIN web_record r ON r.id = w.record_id "
                f"WHERE w.lang = %s AND w.word = %s AND r.{column} LIKE %s ESCAPE '\\' "
                + self._order(language, page, offset),
                [lang, rarest, "%" + "%".join(map(_escape_like, tokens)) + "%", key],
            )
            matches += [
                entry
                for entry in candidates
                if _contains_phrase(words(self.fold(entry.text(language))), tokens)
            ]
            if len(candidates) < page:
                break
            offset += page
        return _limited(matches)

    def _fulltext(self, key: str, language: str) -> tuple[list[Entry], bool]:
        column = f"{language}_key"
        entries = self._entries(
            f"SELECT {_COLUMNS} FROM web_record r WHERE r.{column} LIKE %s ESCAPE '\\' "
            + self._order(language, ROW_LIMIT + 1),
            ["%" + _escape_like(key) + "%", key],
        )
        return _limited(entries)

    def _base_forms(self, key: str, exact: str | None) -> list[str]:
        # Typed diacritics pick the form: "nedělá" is "dělat", not "neděle", whose form "neděla"
        # folds the same.
        found = self._base_forms_matching(key, exact)
        if found is not None and not found and exact is not None:
            # the typed diacritics may be wrong
            return self._base_forms_matching(key, None) or []
        return found or []

    def _base_forms_matching(self, key: str, exact: str | None) -> list[str] | None:
        """None when the word is a base form itself."""
        lemmas = self._lemmas_of(self._form_rows(key), exact)
        if lemmas:
            return lemmas
        word = self._czech_word(key)
        if word is not None and (exact is None or word == exact):
            return None
        # negated and superlative forms are not stored
        for prefix in self._negation_prefixes:
            if (
                len(key) <= len(prefix) + 1
                or not key.startswith(prefix)
                # "něco" folds to "neco" but has no "ne-" to strip
                or (exact is not None and not exact.startswith(prefix))
            ):
                continue
            rest_key = key[len(prefix) :]
            rest_exact = exact[len(prefix) :] if exact is not None else None
            rest_lemmas = self._lemmas_of(self._form_rows(rest_key), rest_exact)
            if rest_lemmas:
                return rest_lemmas
            rest_word = self._czech_word(rest_key)
            if rest_word is not None and (rest_exact is None or rest_word == rest_exact):
                return [rest_word]
        return []

    def _form_rows(self, key: str) -> list[tuple[str, str]]:
        # the order of SQLite's UNION in the app, so that both list the base forms alike
        return self._select(
            "SELECT DISTINCT form, lemma FROM web_czechform WHERE form_key = %s "
            "ORDER BY form, lemma",
            [key],
        )

    @staticmethod
    def _lemmas_of(rows: list[tuple[str, str]], exact: str | None) -> list[str]:
        return list(dict.fromkeys(lemma for form, lemma in rows if exact is None or form == exact))

    def _czech_word(self, key: str) -> str | None:
        # ordered like the app's SQLite returns them (by its primary key)
        rows = self._select(
            "SELECT r.cze FROM web_word w JOIN web_record r ON r.id = w.record_id "
            "WHERE w.lang = %s AND w.word = %s ORDER BY w.record_id LIMIT 20",
            [CZE, key],
        )
        for (cze,) in rows:
            for word in words(cze.lower()):
                if self.fold(word) == key:
                    return word
        return None

    def _rank_and_group(
        self,
        text: str,
        key: str,
        language: str,
        direct: list[Entry],
        via_base_form: list[Entry],
        base_forms: list[str],
    ) -> list[Group]:
        lower_text = text.lower()
        base_keys = {self.fold(lemma) for lemma in base_forms}
        key_words = words(key)
        scored: dict[int, tuple] = {}

        def add(entry: Entry, from_base_form: bool) -> None:
            head = entry.text(language)
            head_key = self.fold(head)
            if head_key == key:
                tier = 0
            elif head_key in base_keys:
                tier = 1
            elif not from_base_form and head_key.startswith(key):
                tier = 2
            elif not from_base_form and _contains_phrase(words(head_key), key_words):
                tier = 3
            elif from_base_form:
                tier = 4
            else:
                tier = 5
            # "být" before "byt" when "být" was typed
            exact = 0 if head.lower() == lower_text or head.lower() in base_forms else 1
            score = (
                tier,
                exact,
                -entry.rank(language),
                len(head_key),
                head_key,
                -entry.rank(other(language)),
                entry.id,
                entry,
            )
            previous = scored.get(entry.id)
            if previous is None or score[:-1] < previous[:-1]:
                scored[entry.id] = score

        for entry in direct:
            add(entry, from_base_form=False)
        for entry in via_base_form:
            add(entry, from_base_form=True)

        groups: dict[str, Group] = {}
        for *_, entry in sorted(scored.values(), key=lambda score: score[:-1]):
            head = entry.text(language)
            groups.setdefault(head, Group(head)).entries.append(entry)
        return list(groups.values())
