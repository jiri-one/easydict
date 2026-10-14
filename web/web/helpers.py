from django.utils.html import format_html, format_html_join

from .dictionary import SearchResult, other

MAX_RESULTS = 100

TEXTS = {
    "cze": {
        "nothing": "Nic nenalezeno.",
        "base_form": "Nalezeno jako tvar slova {}.",
        "base_forms": "Nalezeno jako tvar slov {}.",
        "quotes": "„{}“",
        "more": "… (zobrazeno prvních {} překladů)",
        "updating": "Slovník se právě aktualizuje, zkuste to prosím za chvíli.",
    },
    "eng": {
        "nothing": "Nothing found.",
        "base_form": "Found as a form of {}.",
        "base_forms": "Found as a form of {}.",
        "quotes": "“{}”",
        "more": "… (the first {} translations are shown)",
        "updating": "The dictionary is being updated, please try again in a moment.",
    },
}


def results_html(result: SearchResult, page_language: str) -> str:
    texts = TEXTS[page_language]
    if not result.groups:
        return format_html("<p>{}</p>", texts["nothing"])
    html = ""
    if result.base_forms:
        quoted = ", ".join(texts["quotes"].format(form) for form in result.base_forms)
        sentence = texts["base_form" if len(result.base_forms) == 1 else "base_forms"]
        html += format_html("<p>{}</p><hr>\n", sentence.format(quoted))
    translation_language = other(result.language)
    shown = 0
    truncated = result.truncated
    for group in result.groups:
        entries = group.entries[: MAX_RESULTS - shown]
        if not entries:
            truncated = True
            break
        truncated |= len(entries) < len(group.entries)
        shown += len(entries)
        # format_html escapes the dictionary data
        html += format_html(
            "<p><b>{}</b>{}</p><hr>\n",
            group.headword,
            format_html_join(
                "",
                "<br>&emsp;{}{}",
                (
                    (
                        entry.text(translation_language),
                        " | ".join(["", *filter(None, (entry.notes, entry.special))]),
                    )
                    for entry in entries
                ),
            ),
        )
    if truncated:
        html += format_html("<p>{}</p>", texts["more"].format(shown))
    return html
