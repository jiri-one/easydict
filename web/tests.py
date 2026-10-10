from django.test import TestCase

from .helpers import MAX_RESULTS
from .models import Record


class SearchTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        Record.objects.create(cze="pes", eng="dog")
        Record.objects.create(cze="pes domácí", eng="domestic dog", notes_eng="animal")
        Record.objects.create(cze="pesimista", eng="pessimist")
        Record.objects.create(cze="<b>tučně</b>", eng="bold & strong")

    def search(self, text, language="cze", mode="whole_word"):
        return self.client.post(
            "/search", {"searched_text": text, "language": language, "optionsRadios": mode}
        )

    def test_whole_word(self):
        response = self.search("pes")
        self.assertContains(response, "domestic dog")
        self.assertNotContains(response, "pessimist")

    def test_fulltext(self):
        self.assertContains(self.search("pes", mode="fulltext"), "pessimist")

    def test_closest_match_first(self):
        content = self.search("pes").content.decode()
        self.assertLess(content.index("&emsp;dog"), content.index("domestic dog"))

    def test_notes_are_shown(self):
        self.assertContains(self.search("domácí"), "domestic dog | animal")

    def test_regex_characters_are_literal(self):
        for text in ("(", ".*", "pe[s"):
            with self.subTest(text=text):
                response = self.search(text)
                self.assertEqual(response.status_code, 200)
                self.assertNotContains(response, "<hr>")

    def test_dictionary_data_is_escaped(self):
        response = self.search("tučně", mode="fulltext")
        self.assertContains(response, "&lt;b&gt;tučně&lt;/b&gt;")
        self.assertContains(response, "bold &amp; strong")

    def test_results_are_limited(self):
        Record.objects.bulk_create(
            Record(cze=f"kos {i}", eng=f"blackbird {i}") for i in range(MAX_RESULTS + 20)
        )
        response = self.search("kos")
        self.assertEqual(response.content.decode().count("<hr>"), MAX_RESULTS)
        self.assertContains(response, f"first {MAX_RESULTS} results shown")

    def test_unknown_language(self):
        self.assertEqual(self.search("a", language="author").status_code, 400)

    def test_empty_or_too_long_text(self):
        self.assertEqual(self.search("  ").status_code, 400)
        self.assertEqual(self.search("x" * 51).status_code, 400)

    def test_get_is_not_allowed(self):
        self.assertEqual(self.client.get("/search").status_code, 405)
