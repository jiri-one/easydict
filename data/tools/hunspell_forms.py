"""Expand Hunspell dictionary entries (stem/FLAGS) into all their word forms.

Only the subset of the Hunspell affix format used by the Czech dictionary is
supported: single-character flags, PFX/SFX classes with cross products,
two-level suffixes (continuation flags on a suffix) and prefixes attached
through a suffix's continuation flags (e.g. comparative + "nej").
"""

from __future__ import annotations

import re
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path

FORBIDDEN_FLAGS_KEYS = ("FORBIDDENWORD",)


@dataclass(frozen=True)
class Affix:
    flag: str
    strip: str
    add: str
    cont: str  # continuation flags
    condition: re.Pattern
    cross_product: bool

    def applies(self, word: str, prefix: bool) -> bool:
        if prefix:
            return word.startswith(self.strip) and self.condition.search(word) is not None
        return word.endswith(self.strip) and self.condition.search(word) is not None

    def apply(self, word: str, prefix: bool) -> str:
        if prefix:
            return self.add + word[len(self.strip):]
        return word[: len(word) - len(self.strip)] + self.add


def _condition_regex(condition: str, prefix: bool) -> re.Pattern:
    if condition == ".":
        return re.compile("")
    # Hunspell conditions only use literals, [...] / [^...] groups and "."
    pattern = condition.replace("\\", "\\\\")
    return re.compile(("^" + pattern) if prefix else (pattern + "$"))


@dataclass
class AffixFile:
    prefixes: dict[str, list[Affix]]
    suffixes: dict[str, list[Affix]]
    forbidden_flag: str | None


def load_affixes(aff_path: Path) -> AffixFile:
    prefixes: dict[str, list[Affix]] = defaultdict(list)
    suffixes: dict[str, list[Affix]] = defaultdict(list)
    cross: dict[tuple[str, str], bool] = {}
    forbidden = None
    for raw in aff_path.read_text(encoding="utf-8").splitlines():
        parts = raw.split("#", 1)[0].split()
        if not parts:
            continue
        if parts[0] == "FORBIDDENWORD":
            forbidden = parts[1]
        if parts[0] not in ("PFX", "SFX"):
            continue
        kind, flag = parts[0], parts[1]
        if len(parts) == 4 and parts[2] in ("Y", "N"):  # class header
            cross[(kind, flag)] = parts[2] == "Y"
            continue
        strip, add_field, condition = parts[2], parts[3], parts[4] if len(parts) > 4 else "."
        add, _, cont = add_field.partition("/")
        is_prefix = kind == "PFX"
        affix = Affix(
            flag=flag,
            strip="" if strip == "0" else strip,
            add="" if add == "0" else add,
            cont=cont,
            condition=_condition_regex(condition, is_prefix),
            cross_product=cross[(kind, flag)],
        )
        (prefixes if is_prefix else suffixes)[flag].append(affix)
    return AffixFile(dict(prefixes), dict(suffixes), forbidden)


def expand(word: str, flags: str, aff: AffixFile) -> set[str]:
    forms = {word}
    suffixed: list[tuple[str, Affix]] = []
    for flag in flags:
        for sfx in aff.suffixes.get(flag, ()):
            if not sfx.applies(word, prefix=False):
                continue
            form = sfx.apply(word, prefix=False)
            forms.add(form)
            suffixed.append((form, sfx))
            for cont_flag in sfx.cont:
                for sfx2 in aff.suffixes.get(cont_flag, ()):
                    if sfx2.applies(form, prefix=False):
                        form2 = sfx2.apply(form, prefix=False)
                        forms.add(form2)
                        # a prefix can combine with the second suffix too
                        if sfx.cross_product and sfx2.cross_product:
                            suffixed.append((form2, sfx2))
                for pfx in aff.prefixes.get(cont_flag, ()):
                    if pfx.applies(form, prefix=True):
                        forms.add(pfx.apply(form, prefix=True))
    for flag in flags:
        for pfx in aff.prefixes.get(flag, ()):
            if pfx.applies(word, prefix=True):
                forms.add(pfx.apply(word, prefix=True))
            if not pfx.cross_product:
                continue
            for form, sfx in suffixed:
                if sfx.cross_product and pfx.applies(form, prefix=True):
                    forms.add(pfx.apply(form, prefix=True))
    return forms


def read_dic(dic_path: Path):
    with dic_path.open(encoding="utf-8") as dic:
        next(dic)  # the first line is the entry count
        for line in dic:
            entry = line.strip()
            if not entry:
                continue
            stem, _, flags = entry.partition("/")
            yield stem, flags


def forms_by_lemma(dic_path: Path, aff_path: Path, wanted: set[str] | None = None) -> dict[str, set[str]]:
    """Forbidden words are left out, also when another stem generates them."""
    aff = load_affixes(aff_path)
    entries = list(read_dic(dic_path))
    forbidden = {stem for stem, flags in entries if aff.forbidden_flag and aff.forbidden_flag in flags}
    result: dict[str, set[str]] = defaultdict(set)
    for stem, flags in entries:
        if stem in forbidden:
            continue
        if wanted is not None and stem.lower() not in wanted:
            continue
        result[stem] |= expand(stem, flags, aff) - {stem} - forbidden
    return dict(result)
