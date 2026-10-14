Free Dictionaries
=================
This directory continues the free English–Czech dictionary of the [Svobodné slovníky](https://github.com/lehrbuch/svobodneslovniky) project, formerly known as the *GNU/FDL Anglicko-Český slovník* (http://slovnik.zcu.cz). The svobodneslovniky.cz website is offline and its working repository has been quiet since October 2021, so the dictionary is now maintained here as part of EasyDict. The full history of the original repository is preserved.

Layout
------
- `en-cs/` – the English–Czech dictionary (GNU FDL 1.1 or later). The format is described in `en-cs/format.en.md`.
- `cs-forms/` – Czech word forms, so that words typed in other forms are found too (*psa* → *pes*):
  - `hunspell/` – the Czech Hunspell dictionary from [LibreOffice](https://github.com/LibreOffice/dictionaries/tree/master/cs_CZ) (GNU GPL 2), commit `b3a1c0b` of 2021-07-28.
  - `wiktionary/forms.tsv` – inflected forms extracted from [Wiktionary](https://en.wiktionary.org) via [kaikki.org](https://kaikki.org/dictionary/Czech/) (CC BY-SA 4.0), dump of 2026-10-03.
- `frequency/` – how common English and Czech words are, from [wordfreq](https://github.com/rspeer/wordfreq) 3.1.1 (CC BY-SA 4.0), so that the app shows the common translations first.
- `tools/` – `build_db.py` builds the database used by the EasyDict app; `extract_wiktionary_forms.py` and `extract_frequencies.py` refresh `cs-forms/wiktionary/forms.tsv` and `frequency/`.
- `tests/` – tests for the tools: `python3 -m pytest data/tests`.

Contributing
------------
Paths are relative to the root of the repository.

1. Fork the EasyDict repository.
2. Edit `data/en-cs/en-cs.txt`, keeping its format (see `data/en-cs/format.en.md`).
3. Run `data/en-cs/sort.sh`, which keeps the records in the correct order (it needs [PyICU](https://pypi.org/project/PyICU/)). Unsorted records fail the automatic check.
4. Open a pull request.

Building the database
---------------------
The build needs only Python 3.9+ and its standard library:

    python3 data/tools/build_db.py data/build/easydict.sqlite

Next to the database it writes `easydict.sqlite.NOTICE.txt`, the licence notice of the dictionary with its cover texts and authors, which the GNU FDL asks to keep with every copy.

---

Svobodné slovníky
=================
V tomto adresáři pokračujeme ve správě svobodného anglicko-českého slovníku projektu [Svobodné slovníky](https://github.com/lehrbuch/svobodneslovniky), dříve známého jako *GNU/FDL Anglicko-Český slovník* (http://slovnik.zcu.cz). Web svobodneslovniky.cz už neběží a jeho pracovní repozitář se od října 2021 nezměnil, proto slovník nyní spravujeme zde jako součást EasyDictu. Celá historie původního repozitáře je zachována.

Obsah
-----
- `en-cs/` – anglicko-český slovník (GNU FDL 1.1 nebo pozdější). Formát popisuje `en-cs/format.cs.md`.
- `cs-forms/` – tvary českých slov, aby se slova našla i v jiných tvarech (*psa* → *pes*):
  - `hunspell/` – český slovník Hunspell z [LibreOffice](https://github.com/LibreOffice/dictionaries/tree/master/cs_CZ) (GNU GPL 2), commit `b3a1c0b` z 28. 7. 2021.
  - `wiktionary/forms.tsv` – tvary z [Wikislovníku](https://en.wiktionary.org) přes [kaikki.org](https://kaikki.org/dictionary/Czech/) (CC BY-SA 4.0), export z 3. 10. 2026.
- `frequency/` – jak častá jsou anglická a česká slova, z [wordfreq](https://github.com/rspeer/wordfreq) 3.1.1 (CC BY-SA 4.0), aby aplikace ukazovala běžné překlady jako první.
- `tools/` – `build_db.py` sestaví databázi pro aplikaci EasyDict, `extract_wiktionary_forms.py` a `extract_frequencies.py` obnoví `cs-forms/wiktionary/forms.tsv` a `frequency/`.
- `tests/` – testy nástrojů: `python3 -m pytest data/tests`.

Jak přispívat
-------------
Cesty jsou uvedené od kořene repozitáře.

1. Založte fork repozitáře EasyDict.
2. Upravte `data/en-cs/en-cs.txt` a držte se jeho formátu (viz `data/en-cs/format.cs.md`).
3. Spusťte `data/en-cs/sort.sh`, který zaručí správné pořadí záznamů (potřebuje [PyICU](https://pypi.org/project/PyICU/)). Nesetříděné záznamy neprojdou automatickou kontrolou.
4. Pošlete pull request.

Sestavení databáze
------------------
Stačí Python 3.9+ a jeho standardní knihovna:

    python3 data/tools/build_db.py data/build/easydict.sqlite

Vedle databáze vznikne `easydict.sqlite.NOTICE.txt`, licenční oznámení slovníku s texty na obálku a seznamem autorů, které musí podle GNU FDL provázet každou kopii.
