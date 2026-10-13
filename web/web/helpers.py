import difflib
import re

from django.db.models.functions import Length
from django.utils.html import format_html

from .models import Record

LANGUAGES = ("cze", "eng")
MAX_RESULTS = 100


def db_search(language, text, fulltext):
    if fulltext == "whole_word":
        # the searched text is literal, only \y (word boundary) is regex
        filter_value = rf"\y{re.escape(text)}\y"
        search_type = "iregex"
    else:
        filter_value = text
        search_type = "icontains"
    filter_key = f"{language}__{search_type}"
    filter_dict = {filter_key: filter_value}
    # Shortest matches first: they are also the most similar ones below, so the limit
    # keeps the best results. One more than the limit tells that some were left out.
    results = list(
        Record.objects.filter(**filter_dict)
        .order_by(Length(language), language)
        .values()[: MAX_RESULTS + 1]
    )
    truncated = len(results) > MAX_RESULTS
    del results[MAX_RESULTS:]

    results_with_matchratio = []
    for result in results:
        ratio = difflib.SequenceMatcher(None, result[language], text).ratio()
        results_with_matchratio.append([result, ratio])
    sorted_results = sorted(results_with_matchratio, key=lambda x: x[1], reverse=True)
    html = CreateHtml(sorted_results, language)()
    if truncated:
        html += f"<p>… (zobrazeno prvních {MAX_RESULTS} výsledků / first {MAX_RESULTS} results shown)</p>"
    return html

class CreateHtml:
    def __init__(self, results, language):
        self.lng1 = language
        self.lng2 = [lang for lang in LANGUAGES if lang != language][0]
        self.html_string = ""
        for row in results:
            self.html_string = self.html_string + self.create_html(row[0]) # zero is here bacause index 1 is matchratio

    def __call__(self):
        return self.html_string

    def create_html(self, row):
        notes = f" | {note}" if (note := row[f"notes_{self.lng2}"]) else ""
        special = f" | {spec}" if (spec := row[f"special_{self.lng2}"]) else ""
        # format_html escapes the dictionary data
        return format_html(
            "<p>{}<br>&emsp;{}{}{}</p><hr>\n",
            row[self.lng1],
            row[self.lng2],
            notes,
            special,
        )
