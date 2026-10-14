import tempfile
from pathlib import Path

from django.test import SimpleTestCase, TestCase, override_settings

from web.dictionary import Entry, Group, SearchResult
from web.helpers import MAX_RESULTS, results_html

from . import DictionaryTestCase


class HomePageSearchTests(DictionaryTestCase):
    def search(self, text, language="cze", mode="whole_word", page_language="cze"):
        return self.client.post(
            "/search",
            {"searched_text": text, "language": language, "optionsRadios": mode, "page_language": page_language},
        )

    def test_translations_of_a_headword(self):
        content = self.search("dog", language="eng").content.decode()
        self.assertIn("<b>dog</b>", content)
        self.assertLess(content.index("&emsp;pes | n:"), content.index("&emsp;čokl | n: [hovor.]"))

    def test_a_form_finds_its_base_form(self):
        self.assertContains(self.search("psa"), "Nalezeno jako tvar slova „pes“.")
        self.assertContains(self.search("psa", page_language="eng"), "Found as a form of “pes”.")
        self.assertContains(self.search("psa"), "<b>pes</b>")

    def test_whole_word_and_fulltext(self):
        self.assertContains(self.search("ostrikovacu"), "<b>kapalina do ostřikovačů</b>")
        self.assertNotContains(self.search("ostrik"), "<b>")
        self.assertContains(self.search("ostrik", mode="fulltext"), "<b>kapalina do ostřikovačů</b>")

    def test_nothing_found(self):
        self.assertContains(self.search("xyz"), "Nic nenalezeno.")
        self.assertContains(self.search("(", page_language="eng"), "Nothing found.")

    def test_unknown_language(self):
        self.assertEqual(self.search("a", language="author").status_code, 400)

    def test_empty_or_too_long_text(self):
        self.assertEqual(self.search("  ").status_code, 400)
        self.assertEqual(self.search("x" * 51).status_code, 400)

    def test_get_is_not_allowed(self):
        self.assertEqual(self.client.get("/search").status_code, 405)


class HomePageEscapingTests(DictionaryTestCase):
    en_cs_lines = ["bold & strong\t<b>tučně</b>\t<i>\t\t", *(f"kos {i}\tkos {i}\t\t\t" for i in range(MAX_RESULTS + 20))]
    forms = False

    def search(self, text, language):
        return self.client.post(
            "/search", {"searched_text": text, "language": language, "optionsRadios": "fulltext"}
        )

    def test_dictionary_data_is_escaped(self):
        response = self.search("tučně", "cze")
        self.assertContains(response, "<b>&lt;b&gt;tučně&lt;/b&gt;</b>")
        self.assertContains(response, "&emsp;bold &amp; strong | &lt;i&gt;")

    def test_results_are_limited(self):
        content = self.search("kos", "cze").content.decode()
        self.assertEqual(content.count("&emsp;"), MAX_RESULTS)
        self.assertIn(f"zobrazeno prvních {MAX_RESULTS} překladů", content)


class ApiTests(DictionaryTestCase):
    def test_search(self):
        response = self.client.get("/api/search", {"q": "psa", "lang": "cze", "mode": "startsWith"})
        self.assertEqual(response["Cache-Control"], "public, max-age=60")
        result = response.json()
        self.assertEqual(result["query"], "psa")
        self.assertEqual(result["base_forms"], ["pes"])
        self.assertFalse(result["truncated"])
        self.assertEqual([group["headword"] for group in result["groups"]], ["pes", "honicí pes"])
        self.assertEqual(
            result["groups"][0]["entries"][0],
            {
                "id": 4,
                "eng": "dog",
                "cze": "pes",
                "notes": "n:",
                "special": None,
                "author": "Milan Svoboda",
                "eng_rank": 510,
                "cze_rank": 484,
            },
        )

    def test_empty_query(self):
        self.assertEqual(self.client.get("/api/search", {"lang": "eng"}).json()["groups"], [])

    def test_unknown_language_or_mode(self):
        self.assertEqual(self.client.get("/api/search", {"q": "a", "lang": "author"}).status_code, 400)
        self.assertEqual(self.client.get("/api/search", {"q": "a", "mode": "regex"}).status_code, 400)

    def test_info(self):
        meta = self.client.get("/api/info").json()["meta"]
        self.assertEqual(meta["entries"], "16")
        self.assertEqual(meta["schema_version"], "2")
        self.assertIn("Milan Svoboda", meta["authors"])
        self.assertNotIn("fold_map", meta)


class BaseFormTextTests(SimpleTestCase):
    def html(self, base_forms, page_language="cze"):
        entry = Entry(1, "dog", "pes", None, None, None, 0, 0)
        result = SearchResult("psa", "cze", "wholeWord", [Group("pes", [entry])], base_forms)
        return results_html(result, page_language)

    def test_one_or_more_base_forms(self):
        self.assertIn("Nalezeno jako tvar slova „pes“.", self.html(["pes"]))
        self.assertIn("Nalezeno jako tvar slov „pes“, „psát“.", self.html(["pes", "psát"]))
        self.assertIn("Found as a form of “pes”, “psát”.", self.html(["pes", "psát"], "eng"))


class NotImportedTests(TestCase):
    """Before the first import the search answers 503 instead of failing."""

    def test_search(self):
        response = self.client.post("/search", {"searched_text": "dog", "language": "eng"})
        self.assertContains(response, "Slovník se právě aktualizuje", status_code=503)
        self.assertEqual(self.client.get("/api/search", {"q": "dog"}).status_code, 503)
        self.assertEqual(self.client.get("/api/info").status_code, 503)


class WebAppTests(TestCase):
    def test_index_of_the_build(self):
        with tempfile.TemporaryDirectory() as tmp, override_settings(WEBAPP_DIR=Path(tmp)):
            (Path(tmp) / "index.html").write_text('<base href="/static/app/">', encoding="utf-8")
            response = self.client.get("/app")
            self.assertContains(response, '<base href="/static/app/">')
            self.assertEqual(response["Cache-Control"], "no-cache")

    def test_not_built(self):
        with tempfile.TemporaryDirectory() as tmp, override_settings(WEBAPP_DIR=Path(tmp)):
            self.assertEqual(self.client.get("/app").status_code, 404)
