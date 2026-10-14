#!/usr/bin/env python3
"""Extract Czech inflected forms from the Wiktionary data published by kaikki.org.

Only real inflections are kept (cases, numbers, persons, tenses, degrees, ...);
derived words such as diminutives, feminine counterparts, aspect partners or
relational adjectives are dropped, and so are archaic forms and transgressives.
Only lemmas that occur as a word on the Czech side of the dictionary are
exported.

Usage:
    curl -LO https://kaikki.org/dictionary/Czech/kaikki.org-dictionary-Czech.jsonl
    data/tools/extract_wiktionary_forms.py kaikki.org-dictionary-Czech.jsonl \
        data/en-cs/en-cs.txt data/cs-forms/wiktionary/forms.tsv
"""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

INFLECTION_TAGS = {
    "nominative", "genitive", "dative", "accusative", "vocative", "locative", "instrumental",
    "singular", "plural", "dual",
    "present", "past", "future", "imperative", "infinitive", "transgressive", "participle",
    "first-person", "second-person", "third-person", "indicative", "conditional",
    "passive", "active", "comparative", "superlative", "short-form",
}
DERIVATION_TAGS = {
    "table-tags", "inflection-template", "class", "canonical", "romanization",
    "alternative", "adjective", "relational", "adverb", "diminutive", "augmentative",
    "demonym", "imperfective", "perfective", "noun-from-verb", "possessive", "abbreviation",
    "suffix", "uppercase", "lowercase", "error-unrecognized-form", "error-unknown-tag",
    # forms nobody types today; they would only collide with common words
    # (the transgressive "žena" of "hnát", "jsa" of "být")
    "transgressive", "archaic", "obsolete", "dated",
}
WORD_RE = re.compile(r"[^\W_]+")


def dictionary_words(en_cs: Path) -> set[str]:
    words = set()
    with en_cs.open(encoding="utf-8") as source:
        for line in source:
            if line.startswith("#"):
                continue
            columns = line.rstrip("\n").split("\t")
            if len(columns) == 5 and columns[1]:
                words.update(w.lower() for w in WORD_RE.findall(columns[1]))
    return words


def is_inflection(form: dict) -> bool:
    tags = set(form.get("tags", ()))
    return bool(tags & INFLECTION_TAGS) and not tags & DERIVATION_TAGS


def extract(kaikki_jsonl: Path, wanted: set[str]) -> dict[str, set[str]]:
    forms_of: dict[str, set[str]] = defaultdict(set)
    with kaikki_jsonl.open(encoding="utf-8") as source:
        for line in source:
            entry = json.loads(line)
            lemma = entry.get("word", "")
            if entry.get("lang_code") != "cs" or lemma.lower() not in wanted:
                continue
            for form in entry.get("forms") or ():
                text = form.get("form", "").strip()
                if not text or text.startswith("-") or " " in text or not is_inflection(form):
                    continue
                if text.lower() != lemma.lower():
                    forms_of[lemma].add(text)
    return forms_of


def drop_borrowed_tables(forms_of: dict[str, set[str]]) -> dict[str, set[str]]:
    """Drop forms that a lemma got from the table of an unrelated word.

    Some Wiktionary entries use the inflection template of another word, e.g.
    "zašeptat" shows the forms of "dělat". Such forms mostly belong to one
    other lemma, which starts with a different letter, as do all the forms.
    (Suppletive forms like "lidé" of "člověk" are only a minority.)
    """
    lemmas_of: dict[str, set[str]] = defaultdict(set)
    for lemma, forms in forms_of.items():
        for form in forms | {lemma}:
            lemmas_of[form.lower()].add(lemma)
    cleaned = {}
    for lemma, forms in forms_of.items():
        lowered = {form.lower() for form in forms}
        others = Counter(other for form in lowered for other in lemmas_of[form] if other != lemma)
        if len(lowered) >= 4 and others:
            other, overlap = others.most_common(1)[0]
            shared = {form for form in lowered if other in lemmas_of[form]}
            first = lemma[0].lower()
            if overlap >= 0.6 * len(lowered) and other[0].lower() != first and all(f[0] != first for f in shared):
                # the whole table is borrowed: keep only what starts like the lemma
                forms = {form for form in forms if form[0].lower() == first}
        if forms:
            cleaned[lemma] = forms
    return cleaned


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("kaikki_jsonl", type=Path)
    parser.add_argument("en_cs", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    forms_of = drop_borrowed_tables(extract(args.kaikki_jsonl, dictionary_words(args.en_cs)))
    with args.output.open("w", encoding="utf-8") as out:
        out.write(
            "# Czech inflected forms extracted from Wiktionary (https://en.wiktionary.org)\n"
            "# via wiktextract / kaikki.org by data/tools/extract_wiktionary_forms.py.\n"
            "# License: CC BY-SA 4.0 (Wiktionary contributors).\n"
            "# Format: lemma<TAB>form|form|...\n"
        )
        for lemma in sorted(forms_of):
            out.write(f"{lemma}\t{'|'.join(sorted(forms_of[lemma]))}\n")
    print(f"{len(forms_of)} lemmas, {sum(map(len, forms_of.values()))} forms -> {args.output}")


if __name__ == "__main__":
    main()
