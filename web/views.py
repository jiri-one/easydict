from django.shortcuts import render
from django.http import HttpResponse, HttpResponseBadRequest
from django.views.decorators.http import require_POST
from .helpers import LANGUAGES, db_search

MAX_SEARCHED_TEXT = 50


def index_cze(request):
    return render(request, 'web/index_cze.html')


def index_eng(request):
    return render(request, 'web/index_eng.html')


@require_POST
def search(request):
    searched_text = request.POST.get('searched_text', '')
    language = request.POST.get('language')
    fulltext = request.POST.get('optionsRadios')
    # language becomes part of a field lookup, so only the dictionary columns are allowed
    if language not in LANGUAGES:
        return HttpResponseBadRequest('Unknown language.')
    if not searched_text.strip() or len(searched_text) > MAX_SEARCHED_TEXT:
        return HttpResponseBadRequest(f'The searched text must have 1 to {MAX_SEARCHED_TEXT} characters.')
    results = db_search(language, searched_text, fulltext)
    return HttpResponse(results)
