from django.template.loader import render_to_string

from .dictionary import SearchResult, other
from .notes import note_labels
from .speech import spoken_text

MAX_RESULTS = 100
MAX_SEARCHED_TEXT = 50

TEXTS = {
    "cze": {
        "nothing": "Nic nenalezeno.",
        "author": "Autor překladu",
        "look_up": "Vyhledat „{}“",
        "copy": "Kopírovat",
        "base_form": "Nalezeno jako tvar slova {}.",
        "base_forms": "Nalezeno jako tvar slov {}.",
        "quotes": "„{}“",
        "more": "… (zobrazeno prvních {} překladů)",
        "updating": "Slovník se právě aktualizuje, zkuste to prosím za chvíli.",
        "speak": "Přehrát výslovnost",
    },
    "eng": {
        "nothing": "Nothing found.",
        "author": "Translated by",
        "look_up": "Look up “{}”",
        "copy": "Copy",
        "base_form": "Found as a form of {}.",
        "base_forms": "Found as a form of {}.",
        "quotes": "“{}”",
        "more": "… (the first {} translations are shown)",
        "updating": "The dictionary is being updated, please try again in a moment.",
        "speak": "Speak pronunciation",
    },
}


def results_html(result: SearchResult, page_language: str) -> str:
    texts = TEXTS[page_language]
    base_forms = ""
    if result.base_forms:
        quoted = ", ".join(texts["quotes"].format(form) for form in result.base_forms)
        sentence = texts["base_form" if len(result.base_forms) == 1 else "base_forms"]
        base_forms = sentence.format(quoted)
    translation_language = other(result.language)
    groups = []
    shown = 0
    truncated = result.truncated
    for group in result.groups:
        entries = group.entries[: MAX_RESULTS - shown]
        if not entries:
            truncated = True
            break
        truncated |= len(entries) < len(group.entries)
        shown += len(entries)
        translations = []
        for entry in entries:
            translation = entry.text(translation_language)
            translations.append({
                "source": entry.text(result.language),
                "translation": translation,
                "speech": spoken_text(translation, translation_language),
                "labels": " · ".join(note_labels(entry.notes, page_language)),
                "special": entry.special,
                "author": entry.author,
                "look_up": texts["look_up"].format(translation),
                "can_look_up": len(translation) <= MAX_SEARCHED_TEXT,
            })
        groups.append({
            "headword": group.headword,
            "speech": spoken_text(group.headword, result.language),
            "entries": translations,
        })
    return render_to_string("web/search_results.html", {
        "groups": groups,
        "base_forms": base_forms,
        "texts": texts,
        "language": result.language,
        "translation_language": translation_language,
        "more": texts["more"].format(shown) if truncated else "",
    })
