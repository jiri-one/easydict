from django.conf import settings
from django.http import Http404, HttpResponse, HttpResponseBadRequest, JsonResponse
from django.shortcuts import render
from django.views.decorators.http import require_GET, require_POST

from .dictionary import LANGUAGES, MODES, Dictionary, DictionaryNotImported
from .helpers import MAX_SEARCHED_TEXT, TEXTS, results_html

FORM_MODES = {"starts_with": "startsWith", "whole_word": "wholeWord", "fulltext": "fulltext"}


def index_cze(request):
    return render(request, 'web/index_cze.html')


def index_eng(request):
    return render(request, 'web/index_eng.html')


@require_POST
def search(request):
    searched_text = request.POST.get('searched_text', '')
    language = request.POST.get('language')
    mode = FORM_MODES.get(request.POST.get('optionsRadios'), "wholeWord")
    page_language = "eng" if request.POST.get('page_language') == "eng" else "cze"
    if language not in LANGUAGES:
        return HttpResponseBadRequest('Unknown language.')
    if not searched_text.strip() or len(searched_text) > MAX_SEARCHED_TEXT:
        return HttpResponseBadRequest(f'The searched text must have 1 to {MAX_SEARCHED_TEXT} characters.')
    try:
        result = Dictionary.load().search(searched_text, language, mode)
    except DictionaryNotImported:
        return HttpResponse(TEXTS[page_language]["updating"], status=503)
    return HttpResponse(results_html(result, page_language))


@require_GET
def api_search(request):
    language = request.GET.get('lang', 'eng')
    mode = request.GET.get('mode', 'startsWith')
    if language not in LANGUAGES or mode not in MODES:
        return JsonResponse({'error': 'Unknown language or mode.'}, status=400)
    try:
        result = Dictionary.load().search(request.GET.get('q', ''), language, mode)
    except DictionaryNotImported:
        return JsonResponse({'error': 'The dictionary is being updated.'}, status=503)
    response = JsonResponse(result.as_json())
    response['Cache-Control'] = 'public, max-age=60'
    return response


@require_GET
def api_info(request):
    try:
        meta = Dictionary.load().meta
    except DictionaryNotImported:
        return JsonResponse({'error': 'The dictionary is being updated.'}, status=503)
    response = JsonResponse({'meta': {key: value for key, value in meta.items() if key != 'fold_map'}})
    response['Cache-Control'] = 'public, max-age=60'
    return response


@require_GET
def app(request):
    """Only index.html; the rest of the build is static, served from STATIC_URL + "app/"."""
    try:
        html = (settings.WEBAPP_DIR / 'index.html').read_text(encoding='utf-8')
    except FileNotFoundError:
        raise Http404('The web app is not built (app/tool/build_web.sh).')
    response = HttpResponse(html)
    response['Cache-Control'] = 'no-cache'
    return response
