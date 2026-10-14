import json
import sqlite3
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))
from build_db import Folder, build, build_fold_map, dictionary_notice, rank  # noqa: E402
from extract_wiktionary_forms import drop_borrowed_tables  # noqa: E402
from hunspell_forms import expand, forms_by_lemma, load_affixes  # noqa: E402

AFF = """\
SET UTF-8
FORBIDDENWORD q
PFX N Y 1
PFX N   0     ne      .
PFX E Y 1
PFX E   0     nej     .
PFX F Y 1
PFX F   0     jedna   .
SFX Y Y 3
SFX Y   ý     á       ý
SFX Y   ý     é       ý
SFX Y   ův    ova     ův
SFX y Y 1
SFX y   ý     ější/E  [nv]ý
SFX P Y 1
SFX P   0     ův/Y    [^aeo]
"""

DIC = """\
6
zelený/YyN
Novák/P
osmdesátník/PF
zakázaný/q
zelené/q
pes
"""

EN_CS = """\
# comment line
dog\tpes\tn:\t\tMilan Svoboda
green\tzelený\tadj:\t\t
untranslated\t\tn:\t\t
Novák's\tNovákův\t\t\t
"""

FREQUENCIES = {
    "en": "# comment\ndog\t5.10\ngreen\t5.00\n",
    "cs": "pes\t4.84\nzelený\t4.50\n",
}

WIKTIONARY = """\
# Format: lemma<TAB>form|form|...
pes\tpsa|psovi
kočka\tkočky
"""


@pytest.fixture
def hunspell_dir(tmp_path: Path) -> Path:
    (tmp_path / "cs_CZ.aff").write_text(AFF, encoding="utf-8")
    (tmp_path / "cs_CZ.dic").write_text(DIC, encoding="utf-8")
    return tmp_path


def test_expand_suffixes_prefixes_and_continuations(hunspell_dir):
    aff = load_affixes(hunspell_dir / "cs_CZ.aff")
    assert expand("zelený", "YyN", aff) >= {
        "zelený", "zelená", "zelené",  # SFX Y
        "zelenější", "nejzelenější",  # SFX y with the E prefix as continuation
        "nezelený", "nezelená", "nezelenější",  # PFX N, cross product with suffixes
    }
    assert expand("Novák", "P", aff) == {"Novák", "Novákův", "Novákova"}  # two-level suffix
    # a prefix combines with both suffix levels
    assert {"jednaosmdesátníkův", "jednaosmdesátníkova"} <= expand("osmdesátník", "PF", aff)


def test_forms_by_lemma_skips_forbidden_and_unwanted(hunspell_dir):
    forms = forms_by_lemma(hunspell_dir / "cs_CZ.dic", hunspell_dir / "cs_CZ.aff", wanted={"zelený", "zakázaný"})
    assert set(forms) == {"zelený"}
    assert "zelený" not in forms["zelený"]
    # a forbidden word is left out also when another stem generates it
    assert "zelená" in forms["zelený"] and "zelené" not in forms["zelený"]


def test_fold_removes_diacritics_and_case():
    fold = Folder(build_fold_map(set()))
    assert fold("Žluťoučký KŮŇ úpěl ďábelské ódy") == "zlutoucky kun upel dabelske ody"
    assert fold("Straße Øresund") == "strasse oresund"


def test_rank_is_the_rarest_word_minus_a_penalty_per_word():
    frequencies = {"pes": 4.84, "honicí": 2.0}
    assert rank("Pes", frequencies) == 484
    assert rank("honicí pes", frequencies) == 100
    assert rank("neznámé slovo", frequencies) == 0
    assert rank("pes", {}) == 0


def test_build_database(tmp_path, hunspell_dir):
    en_cs = tmp_path / "en-cs.txt"
    en_cs.write_text(EN_CS, encoding="utf-8")
    wiktionary = tmp_path / "forms.tsv"
    wiktionary.write_text(WIKTIONARY, encoding="utf-8")
    frequency_dir = tmp_path / "frequency"
    frequency_dir.mkdir()
    for code, text in FREQUENCIES.items():
        (frequency_dir / f"{code}.tsv").write_text(text, encoding="utf-8")
    output = tmp_path / "out" / "easydict.sqlite"

    stats = build(output, en_cs, hunspell_dir, wiktionary, frequency_dir)

    db = sqlite3.connect(output)
    assert stats["entries"] == 3  # the untranslated row is skipped
    rows = db.execute("SELECT eng, cze, notes, special, author, eng_key, cze_key FROM entries ORDER BY id").fetchall()
    assert rows[0] == ("dog", "pes", "n:", None, "Milan Svoboda", "dog", "pes")
    assert rows[1][-1] == "zeleny"
    ranks = db.execute("SELECT eng_rank, cze_rank FROM entries ORDER BY id").fetchall()
    assert ranks[:2] == [(510, 484), (500, 450)]

    words = set(db.execute("SELECT lang, word FROM words"))
    assert {(0, "dog"), (1, "zeleny"), (0, "novak"), (0, "s"), (1, "novakuv")} <= words

    hunspell = set(db.execute("SELECT form_key, form, lemma FROM cs_forms_hunspell"))
    assert ("zelena", "zelená", "zelený") in hunspell  # folded key, form with diacritics, lemma
    assert not any(form == "nejzelenější" for _, form, _ in hunspell)  # "nej" + another form: left to the app
    assert not any(form == "nezelená" for _, form, _ in hunspell)  # "ne" + another form: left to the app

    wiktionary_forms = set(db.execute("SELECT form_key, form, lemma FROM cs_forms_wiktionary"))
    assert wiktionary_forms == {("psa", "psa", "pes"), ("psovi", "psovi", "pes")}  # "kočka" is not used

    meta = dict(db.execute("SELECT key, value FROM meta"))
    assert meta["schema_version"] == "2"
    assert json.loads(meta["fold_map"])["ž"] == "z"
    assert json.loads(meta["negation_prefixes"]) == ["nejne", "nej", "ne"]
    assert "built" not in meta  # no SOURCE_DATE_EPOCH in the test environment


def test_dictionary_notice(tmp_path, monkeypatch):
    header = tmp_path / "_header"
    header.write_text(
        "#      Copyright (c)  2016–@@@YEAR@@@  xHire.\n"
        "#      Permission is granted to copy (...) with the Front-Cover Texts being\n"
        "#      \"Založeno na svobodném anglicko-českém slovníku\", and with the Back-Cover Texts\n"
        "#      \"Autoři:\n#      @@@AUTHORS@@@\n#      \"\n"
        "#      Date: @@@DATE@@@\n",
        encoding="utf-8",
    )
    monkeypatch.setenv("SOURCE_DATE_EPOCH", "1760000000")  # 2025-10-09
    notice = dictionary_notice(header, ["Milan Svoboda", "Pino"])
    assert "@@@" not in notice and "#" not in notice
    assert "Copyright (c)  2016–2021  xHire." in notice
    assert notice.index("Jiří Němec") < notice.index("Permission is granted")  # next to the other copyrights
    assert "Milan Svoboda, Pino" in notice
    assert "Date: 2025-10-09" in notice


def test_build_is_reproducible(tmp_path, hunspell_dir, monkeypatch):
    en_cs = tmp_path / "en-cs.txt"
    en_cs.write_text(EN_CS, encoding="utf-8")
    monkeypatch.setenv("SOURCE_DATE_EPOCH", "1760000000")
    first, second = tmp_path / "a.sqlite", tmp_path / "b.sqlite"
    build(first, en_cs, hunspell_dir, None)
    build(second, en_cs, hunspell_dir, None)
    assert first.read_bytes() == second.read_bytes()


def test_drop_borrowed_tables():
    dělat = {"dělám", "děláš", "dělá", "děláme", "dělal"}
    forms = drop_borrowed_tables({
        "dělat": set(dělat),
        "zašeptat": dělat | {"zašeptati", "dělavší"},  # a wrong template on Wiktionary
        "člověk": {"člověka", "člověku", "člověkem", "lidé", "lidí"},  # suppletive plural
        "lid": {"lidu", "lidem", "lidé", "lidí"},
    })
    assert forms["dělat"] == dělat
    assert forms["zašeptat"] == {"zašeptati"}
    assert {"lidé", "lidí"} <= forms["člověk"]
