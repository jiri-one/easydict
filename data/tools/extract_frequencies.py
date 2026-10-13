#!/usr/bin/env python3
"""Export word frequencies from wordfreq for the words used in the dictionary.

The app orders translations and headwords by them, so that "pes" comes before
"kramle" among the translations of "dog". Needs `pip install wordfreq`.

Usage:
    data/tools/extract_frequencies.py data/en-cs/en-cs.txt data/frequency
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

import wordfreq

WORD_RE = re.compile(r"[^\W_]+")
HEADER = """\
# Zipf frequencies of {language} words from wordfreq {version} by Robyn Speer
# (https://github.com/rspeer/wordfreq), exported by data/tools/extract_frequencies.py.
# License: CC BY-SA 4.0. wordfreq data come from Wikipedia, OpenSubtitles 2018
# (http://www.opensubtitles.org), SUBTLEX by Marc Brysbaert et al. (freely available
# data), Google Books Ngrams (http://books.google.com/ngrams), the Leeds Internet
# Corpus, ParaCrawl and Twitter statistics.
# Format: word<TAB>zipf frequency
"""


def dictionary_words(en_cs: Path, column: int) -> set[str]:
    words = set()
    with en_cs.open(encoding="utf-8") as source:
        for line in source:
            columns = line.rstrip("\n").split("\t")
            if len(columns) == 5 and columns[1]:
                words.update(w.lower() for w in WORD_RE.findall(columns[column]))
    return words


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("en_cs", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()

    from importlib.metadata import version

    args.output_dir.mkdir(parents=True, exist_ok=True)
    for code, name, column in (("en", "English", 0), ("cs", "Czech", 1)):
        rows = []
        for word in sorted(dictionary_words(args.en_cs, column)):
            zipf = wordfreq.zipf_frequency(word, code, wordlist="large")
            if zipf > 0:
                rows.append(f"{word}\t{zipf:.2f}\n")
        output = args.output_dir / f"{code}.tsv"
        output.write_text(HEADER.format(language=name, version=version("wordfreq")) + "".join(rows), encoding="utf-8")
        print(f"{output}: {len(rows)} words")


if __name__ == "__main__":
    main()
