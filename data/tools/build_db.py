#!/usr/bin/env python3
"""Build the EasyDict SQLite database from the dictionary sources.

Only the Python standard library is used, so the script also runs inside the
Flathub and F-Droid build environments. The database does not rely on any
optional SQLite feature (no FTS), so every SQLite build can read it.

    data/tools/build_db.py build/easydict.sqlite

Next to the database it writes the licence notice of the dictionary
(<database>.NOTICE.txt), which the GNU FDL asks to keep with every copy.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import sys
import textwrap
import unicodedata
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hunspell_forms import forms_by_lemma  # noqa: E402

SCHEMA_VERSION = 2
DATA_DIR = Path(__file__).resolve().parent.parent
WORD_RE = re.compile(r"[^\W_]+")
ENG, CZE = 0, 1
# Last year of the upstream Svobodné slovníky releases (the repository went quiet in 2021).
UPSTREAM_LAST_YEAR = 2021
# Longest first: the app tries them in this order when a word is not found.
NEGATION_PREFIXES = ("nejne", "nej", "ne")

# Letters that have no Unicode decomposition but should still fold to ASCII.
EXTRA_FOLDS = {"ł": "l", "ø": "o", "đ": "d", "ħ": "h", "ı": "i", "ß": "ss", "æ": "ae", "œ": "oe", "þ": "th"}

SCHEMA = """
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL) WITHOUT ROWID;
CREATE TABLE entries (
    id INTEGER PRIMARY KEY,
    eng TEXT NOT NULL,
    cze TEXT NOT NULL,
    notes TEXT,
    special TEXT,
    author TEXT,
    eng_key TEXT NOT NULL,
    cze_key TEXT NOT NULL,
    eng_rank INTEGER NOT NULL,
    cze_rank INTEGER NOT NULL
);
CREATE TABLE words (
    lang INTEGER NOT NULL,
    word TEXT NOT NULL,
    entry_id INTEGER NOT NULL,
    PRIMARY KEY (lang, word, entry_id)
) WITHOUT ROWID;
-- form_key is the folded form, form the form with diacritics: the app prefers
-- exact matches when the typed word has diacritics ("nedělá" is not "neděla").
CREATE TABLE cs_forms_hunspell (
    form_key TEXT NOT NULL,
    form TEXT NOT NULL,
    lemma TEXT NOT NULL,
    PRIMARY KEY (form_key, form, lemma)
) WITHOUT ROWID;
CREATE TABLE cs_forms_wiktionary (
    form_key TEXT NOT NULL,
    form TEXT NOT NULL,
    lemma TEXT NOT NULL,
    PRIMARY KEY (form_key, form, lemma)
) WITHOUT ROWID;
"""

INDEXES = """
CREATE INDEX entries_eng_key ON entries (eng_key);
CREATE INDEX entries_cze_key ON entries (cze_key);
"""

SOURCES = [
    {
        "name": "Svobodný anglicko-český slovník",
        "license": "GFDL-1.1-or-later",
        "url": "https://github.com/lehrbuch/svobodneslovniky",
        "notice": "Založeno na svobodném anglicko-českém slovníku, https://www.svobodneslovniky.cz/",
    },
    {
        "name": "Czech Hunspell dictionary",
        "license": "GPL-2.0",
        "url": "https://github.com/LibreOffice/dictionaries/tree/master/cs_CZ",
    },
    {
        "name": "Wiktionary (via kaikki.org)",
        "license": "CC-BY-SA-4.0",
        "url": "https://kaikki.org/dictionary/Czech/",
    },
    {
        "name": "wordfreq",
        "license": "CC-BY-SA-4.0",
        "url": "https://github.com/rspeer/wordfreq",
    },
]


def build_fold_map(extra_chars: set[str]) -> dict[str, str]:
    """Stored in the database, so that the app folds queries exactly like the keys."""
    chars = {chr(c) for c in range(0xC0, 0x250)} | {chr(c) for c in range(0x300, 0x370)} | extra_chars
    fold_map = {}
    for ch in sorted(chars):
        if ch != ch.lower() or len(ch) != 1:
            continue
        base = EXTRA_FOLDS.get(ch) or "".join(c for c in unicodedata.normalize("NFD", ch) if not unicodedata.combining(c))
        if base != ch:
            fold_map[ch] = base
    return fold_map


class Folder:
    def __init__(self, fold_map: dict[str, str]):
        self.table = str.maketrans(fold_map)

    def __call__(self, text: str) -> str:
        return text.lower().translate(self.table)


def words_of(text: str) -> set[str]:
    return set(WORD_RE.findall(text))


def read_en_cs(path: Path):
    with path.open(encoding="utf-8") as source:
        for number, line in enumerate(source, 1):
            if line.startswith("#") or not line.strip():
                continue
            columns = line.rstrip("\n").split("\t")
            if len(columns) != 5:
                raise ValueError(f"{path}:{number}: expected 5 tab-separated columns, got {len(columns)}")
            yield columns


def read_wiktionary_forms(path: Path) -> dict[str, set[str]]:
    forms_of: dict[str, set[str]] = {}
    with path.open(encoding="utf-8") as source:
        for line in source:
            if line.startswith("#") or not line.strip():
                continue
            lemma, forms = line.rstrip("\n").split("\t")
            forms_of[lemma] = set(forms.split("|"))
    return forms_of


def build_date() -> datetime:
    """SOURCE_DATE_EPOCH first, for reproducible builds."""
    if "SOURCE_DATE_EPOCH" in os.environ:
        return datetime.fromtimestamp(int(os.environ["SOURCE_DATE_EPOCH"]), tz=timezone.utc)
    return datetime.now(tz=timezone.utc)


def dictionary_notice(header: Path, authors: list[str]) -> str:
    """The GNU FDL asks to keep the notice with its cover texts and the list of
    authors, and to add a copyright notice for the modifications."""
    date = build_date()
    author_list = "\n".join(textwrap.wrap(", ".join(authors), width=72))
    text = "\n".join(line[1:].strip() if line.startswith("#") else line for line in header.read_text(encoding="utf-8").splitlines())
    # The upstream compilation ends with its last release; our changes get their own line.
    text = text.replace("@@@YEAR@@@", str(UPSTREAM_LAST_YEAR)).replace("@@@DATE@@@", date.strftime("%Y-%m-%d"))
    text = text.replace("@@@AUTHORS@@@", author_list)
    modifications = (
        f"Copyright (c)  2020–{date.year}  Jiří Němec and the contributors of EasyDict,\n"
        "https://github.com/jiri-one/easydict (modifications)."
    )
    first_paragraph_end = text.index("Permission is granted")
    return (text[:first_paragraph_end] + modifications + "\n" + text[first_paragraph_end:]).strip() + "\n"


def read_frequencies(path: Path) -> dict[str, float]:
    frequencies = {}
    with path.open(encoding="utf-8") as source:
        for line in source:
            if line.startswith("#") or not line.strip():
                continue
            word, zipf = line.rstrip("\n").split("\t")
            frequencies[word] = float(zipf)
    return frequencies


def rank(text: str, frequencies: dict[str, float]) -> int:
    """Phrases are much rarer than their words: every further word lowers the Zipf
    frequency of the rarest one by one. 0 means unknown."""
    words = WORD_RE.findall(text.lower())
    if not words or not frequencies:
        return 0
    zipf = min(frequencies.get(word, 0.0) for word in words) - (len(words) - 1)
    return max(0, round(zipf * 100))


def form_rows(forms_of: dict[str, set[str]], czech_words: set[str], fold: Folder) -> set[tuple[str, str, str]]:
    """(folded form, lowercase form, lowercase lemma) rows for lemmas used in the dictionary.

    Negated and superlative forms ("nedobrý", "nejlepší" from "lepší") are left
    out when the rest of the word is the lemma or another of its forms: the app
    strips NEGATION_PREFIXES itself when a word is not found.
    """
    rows = set()
    for lemma, forms in forms_of.items():
        lemma = lemma.lower()
        if lemma not in czech_words:
            continue
        lowered = {form.lower() for form in forms} - {lemma}
        for form in lowered:
            prefix = next((p for p in NEGATION_PREFIXES if form.startswith(p)), None)
            rest = form[len(prefix):] if prefix else None
            if rest is None or (rest != lemma and rest not in lowered):
                rows.add((fold(form), form, lemma))
    return rows


def build(
    output: Path,
    en_cs: Path,
    hunspell_dir: Path | None,
    wiktionary: Path | None,
    frequency_dir: Path | None = None,
    header: Path | None = None,
) -> dict[str, int]:
    rows = [columns for columns in read_en_cs(en_cs) if columns[1]]  # skip untranslated stubs
    en_freq = read_frequencies(frequency_dir / "en.tsv") if frequency_dir else {}
    cs_freq = read_frequencies(frequency_dir / "cs.tsv") if frequency_dir else {}
    chars = {ch for columns in rows for text in columns[:2] for ch in text.lower()}
    fold_map = build_fold_map(chars)
    fold = Folder(fold_map)

    output.parent.mkdir(parents=True, exist_ok=True)
    output.unlink(missing_ok=True)
    db = sqlite3.connect(output)
    db.executescript("PRAGMA journal_mode = OFF; PRAGMA synchronous = OFF; PRAGMA page_size = 4096;")
    db.executescript(SCHEMA)

    entries = []
    words = set()
    czech_words = set()
    for entry_id, (eng, cze, notes, special, author) in enumerate(rows, 1):
        eng_key, cze_key = fold(eng), fold(cze)
        entries.append((
            entry_id, eng, cze, notes or None, special or None, author or None,
            eng_key, cze_key, rank(eng, en_freq), rank(cze, cs_freq),
        ))
        words.update((ENG, word, entry_id) for word in words_of(eng_key))
        words.update((CZE, word, entry_id) for word in words_of(cze_key))
        czech_words.update(words_of(cze.lower()))
    db.executemany("INSERT INTO entries VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", entries)
    db.executemany("INSERT INTO words VALUES (?, ?, ?)", sorted(words))

    stats = {"entries": len(entries), "words": len(words), "forms_hunspell": 0, "forms_wiktionary": 0}
    if hunspell_dir:
        hunspell = forms_by_lemma(hunspell_dir / "cs_CZ.dic", hunspell_dir / "cs_CZ.aff", wanted=czech_words)
        hunspell_rows = sorted(form_rows(hunspell, czech_words, fold))
        db.executemany("INSERT INTO cs_forms_hunspell VALUES (?, ?, ?)", hunspell_rows)
        stats["forms_hunspell"] = len(hunspell_rows)
    if wiktionary:
        wiktionary_rows = sorted(form_rows(read_wiktionary_forms(wiktionary), czech_words, fold))
        db.executemany("INSERT INTO cs_forms_wiktionary VALUES (?, ?, ?)", wiktionary_rows)
        stats["forms_wiktionary"] = len(wiktionary_rows)

    db.executescript(INDEXES)
    # The GFDL asks for the list of authors; the app shows it.
    authors: dict[str, int] = {}
    for *_, author, _, _, _, _ in entries:
        for name in (author or "").split("; "):
            if name.strip():
                authors[name.strip()] = authors.get(name.strip(), 0) + 1
    authors_sorted = sorted(authors.items(), key=lambda item: (-item[1], item[0]))
    meta = {
        "authors": json.dumps(authors_sorted, ensure_ascii=False),
        "schema_version": str(SCHEMA_VERSION),
        "fold_map": json.dumps(fold_map, ensure_ascii=False, sort_keys=True),
        "negation_prefixes": json.dumps(NEGATION_PREFIXES),
        "sources": json.dumps(SOURCES, ensure_ascii=False),
        **{key: str(value) for key, value in stats.items()},
    }
    # Reproducible builds: only stamp a date when the build system provides one.
    if "SOURCE_DATE_EPOCH" in os.environ:
        meta["built"] = build_date().strftime("%Y-%m-%d")
    db.executemany("INSERT INTO meta VALUES (?, ?)", sorted(meta.items()))
    db.commit()
    db.execute("VACUUM")
    db.close()
    if header:
        notice = dictionary_notice(header, [name for name, _ in authors_sorted])
        output.with_name(output.name + ".NOTICE.txt").write_text(notice, encoding="utf-8")
    return stats


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("output", type=Path, help="path of the SQLite database to create")
    parser.add_argument("--en-cs", type=Path, default=DATA_DIR / "en-cs" / "en-cs.txt")
    parser.add_argument("--hunspell-dir", type=Path, default=DATA_DIR / "cs-forms" / "hunspell")
    parser.add_argument("--wiktionary", type=Path, default=DATA_DIR / "cs-forms" / "wiktionary" / "forms.tsv")
    parser.add_argument("--frequency-dir", type=Path, default=DATA_DIR / "frequency")
    parser.add_argument("--header", type=Path, default=DATA_DIR / "en-cs" / "_header",
                        help="licence notice template of the dictionary")
    parser.add_argument("--no-forms", action="store_true", help="build without the Czech inflection tables")
    args = parser.parse_args()

    stats = build(
        args.output,
        args.en_cs,
        None if args.no_forms else args.hunspell_dir,
        None if args.no_forms else args.wiktionary,
        args.frequency_dir,
        args.header,
    )
    size = args.output.stat().st_size / 1e6
    print(f"{args.output}: {size:.1f} MB, " + ", ".join(f"{key} {value}" for key, value in stats.items()))


if __name__ == "__main__":
    main()
