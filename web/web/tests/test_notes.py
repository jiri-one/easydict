from django.test import SimpleTestCase

from web.notes import note_labels


class NoteLabelTests(SimpleTestCase):
    def test_labels_follow_the_requested_language(self):
        self.assertEqual(note_labels("v: [hovor.] pl.", "cze"), ["sloveso", "hovorově", "množné číslo"])
        self.assertEqual(note_labels("v: [hovor.] pl.", "eng"), ["verb", "colloquial", "plural"])

    def test_unknown_labels_and_grouped_notes_are_preserved(self):
        self.assertEqual(
            note_labels("n: [mužs. jméno] (acc) 2 10", "cze"),
            ["podstatné jméno", "[mužs. jméno]", "(acc)"],
        )

    def test_missing_notes(self):
        self.assertEqual(note_labels(None, "cze"), [])
        self.assertEqual(note_labels("", "eng"), [])

    def test_only_decimal_priorities_are_hidden(self):
        self.assertEqual(note_labels("1 +2 -3 10 0x10", "cze"), ["0x10"])
