"""The tests of app/test/dictionary_test.dart for the search of the website: the same fixtures
must give the same results."""

from web.dictionary import MAX_QUERY_LENGTH, MODES, Dictionary

from . import DictionaryTestCase


def headwords(result):
    return [group.headword for group in result.groups]


class SearchTests(DictionaryTestCase):
    def setUp(self):
        self.dictionary = Dictionary.load()

    def search(self, query, language, mode):
        return self.dictionary.search(query, language, mode)

    def test_folding(self):
        self.assertEqual(self.dictionary.fold("Žluťoučký KŮŇ"), "zlutoucky kun")
        self.assertEqual(self.dictionary.entry_count, 16)  # the untranslated row is left out

    def test_translations_are_grouped_by_headword(self):
        result = self.search("dog", "eng", "startsWith")
        self.assertEqual(headwords(result), ["dog"])
        self.assertEqual([entry.cze for entry in result.groups[0].entries], ["pes", "čokl"])
        self.assertEqual(result.groups[0].entries[0].author, "Milan Svoboda")

    def test_a_form_finds_its_base_form(self):
        result = self.search("psa", "cze", "startsWith")
        self.assertEqual(result.base_forms, ["pes"])
        self.assertEqual(headwords(result), ["pes", "honicí pes"])

    def test_a_headword_is_not_taken_for_a_form_of_another_word(self):
        # The fixture lists "žena" also as a form of "hnát"; "žena" itself is a headword.
        result = self.search("žena", "cze", "startsWith")
        self.assertEqual(result.base_forms, [])
        self.assertEqual(headwords(result), ["žena"])
        self.assertEqual(self.search("ženu", "cze", "startsWith").base_forms, ["hnát"])

    def test_irregular_forms_and_missing_diacritics(self):
        result = self.search("sel", "cze", "wholeWord")
        self.assertEqual(result.base_forms, ["jít"])
        self.assertEqual(headwords(result), ["jít"])

    def test_negated_forms_are_found_without_the_prefix(self):
        result = self.search("nezelená", "cze", "startsWith")
        self.assertEqual(result.base_forms, ["zelený"])
        self.assertEqual(headwords(result), ["zelený"])
        for query in ("nezelena", "nezeleny"):
            self.assertEqual(self.search(query, "cze", "startsWith").base_forms, ["zelený"], query)

    def test_the_exact_spelling_comes_first(self):
        self.assertEqual(headwords(self.search("byt", "cze", "wholeWord")), ["byt", "být"])

    def test_whole_words_and_phrases(self):
        self.assertEqual(
            headwords(self.search("washer fluid", "eng", "wholeWord")),
            ["washer fluid", "windshield washer fluid"],
        )
        self.assertEqual(headwords(self.search("done", "eng", "wholeWord")), ["well-done"])

    def test_anywhere_without_diacritics(self):
        result = self.search("ostrikovacu", "cze", "fulltext")
        self.assertEqual(headwords(result), ["kapalina do ostřikovačů"])
        self.assertEqual(len(result.groups[0].entries), 2)

    def test_special_characters_do_not_break_the_search(self):
        for query in ("%", "_", "\\", "'", '"', "  "):
            for mode in MODES:
                with self.subTest(query=query, mode=mode):
                    self.assertEqual(self.search(query, "eng", mode).groups, [])

    def test_typed_diacritics_pick_the_right_base_form(self):
        # "nedělá" (does not do) folds like "neděla", a form of "neděle".
        result = self.search("nedělá", "cze", "startsWith")
        self.assertEqual(result.base_forms, ["dělat"])
        self.assertEqual(headwords(result), ["dělat"])
        # Without diacritics both readings are possible; the stored form wins.
        self.assertEqual(self.search("nedela", "cze", "startsWith").base_forms, ["neděle"])
        # The same word from text with combining marks (decomposed, NFD)
        self.assertEqual(self.search("nede\u030cla\u0301", "cze", "startsWith").base_forms, ["dělat"])

    def test_anywhere_means_the_text_as_typed(self):
        for query in ("dog%", "washer%fluid", "dog_"):
            self.assertEqual(self.search(query, "eng", "fulltext").groups, [], query)

    def test_odd_input_is_cleaned_up(self):
        result = self.search("dog\x00garbage", "eng", "fulltext")
        self.assertEqual(result.query, "dog garbage")
        self.assertEqual(result.groups, [])
        self.assertEqual(len(self.search("a" * 60000, "eng", "fulltext").query), MAX_QUERY_LENGTH)

    def test_unknown_language_or_mode(self):
        with self.assertRaises(ValueError):
            self.search("dog", "author", "startsWith")
        with self.assertRaises(ValueError):
            self.search("dog", "eng", "regex")


class ManyMatchesTests(DictionaryTestCase):
    # 400 entries with "in", 400 with "the" and 20 with the phrase "in the": the phrase must be
    # found although each word alone fills the limit.
    en_cs_lines = [
        *(f"in a{i}\tv a{i}\t\t\t" for i in range(400)),
        *(f"the b{i}\tto b{i}\t\t\t" for i in range(400)),
        *(f"c{i} in the d{i}\tc v d{i}\t\t\t" for i in range(20)),
        *(f"take care {i}\tstarat se {i}\t\t\t" for i in range(400)),
        "carving\tvyřezávání\tn:\t\t",
        # 5 001 entries with both words apart before the one with the phrase
        *(f"x{i:04} in aa the\tx\t\t\t" for i in range(5001)),
        "zzzz in the\tz\t\t\t",
        # 301 headwords starting with "car" but not with the word "car"
        *(f"carvings {i}\tc\t\t\t" for i in range(301)),
        "car thing\tvěc auta\t\t\t",
    ]
    forms = False

    def setUp(self):
        self.dictionary = Dictionary.load()

    def test_a_phrase_is_found_among_frequent_words(self):
        result = self.dictionary.search("in the", "eng", "wholeWord")
        self.assertEqual(len(result.groups), 21)
        self.assertIn("zzzz in the", headwords(result))
        self.assertFalse(result.truncated)

    def test_a_whole_word_at_the_start_is_not_pushed_out(self):
        self.assertIn("car thing", headwords(self.dictionary.search("car", "eng", "wholeWord")))

    def test_a_prefix_match_is_not_pushed_out_by_other_matches(self):
        # "car" is in 400 entries ("care"), but "carving" starts with it.
        result = self.dictionary.search("car", "eng", "fulltext")
        self.assertIn("carving", headwords(result))
        self.assertTrue(result.truncated)
