import gzip
import io
import tempfile
from pathlib import Path
from unittest import skipUnless

from django.core.management import CommandError, call_command
from django.db import connection
from django.test import TestCase

from web.models import CzechForm, DictionaryMeta, Record, Word

from . import APP_FIXTURES, BUILD_DB, build_database


@skipUnless(BUILD_DB.exists(), "needs data/tools of the repository")
class ImportTestCase(TestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.tmp = tempfile.TemporaryDirectory()
        tmp = Path(cls.tmp.name)
        cls.database = build_database(tmp / "test.sqlite", APP_FIXTURES / "en-cs.txt")
        # a newer version of the dictionary
        newer = tmp / "newer.txt"
        newer.write_text((APP_FIXTURES / "en-cs.txt").read_text() + "cat\tkočka\tn:\t\t\n")
        cls.newer = build_database(tmp / "newer.sqlite", newer)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()
        super().tearDownClass()

    def run_import(self, *arguments, database=None):
        output, errors = io.StringIO(), io.StringIO()
        call_command("import_dictionary", database or self.database, *arguments, stdout=output, stderr=errors)
        return output.getvalue() + errors.getvalue()


class ImportTests(ImportTestCase):
    def test_without_options_only_compares(self):
        Record.objects.create(eng="cat", cze="kočka", author="Someone")
        Record.objects.create(eng="dog", cze="pes", notes_cze="n:", author="Milan Svoboda")
        Record.objects.create(eng="untranslated", cze="")
        output = self.run_import()
        self.assertIn("2 in the database, 16 in the import; 1 only in the database (would be removed), 15 new", output)
        self.assertIn("  - cat | kočka |  |  | Someone", output)
        self.assertIn("1 records without a Czech translation are left out", output)
        self.assertIn("Nothing changed", output)
        self.assertEqual(Record.objects.count(), 3)
        self.assertFalse(DictionaryMeta.objects.exists())

    def test_replace(self):
        Record.objects.create(eng="cat", cze="kočka")
        self.assertIn("Imported 16 records", self.run_import("--replace"))
        self.assertEqual(Record.objects.count(), 16)
        self.assertFalse(Record.objects.filter(eng="cat").exists())
        dog = Record.objects.get(eng="dog", cze="pes")
        self.assertEqual((dog.eng_key, dog.cze_key, dog.notes_cze), ("dog", "pes", "n:"))
        self.assertTrue(Word.objects.filter(lang=1, word="pes", record=dog).exists())
        self.assertTrue(CzechForm.objects.filter(form_key="psa", lemma="pes").exists())
        self.assertEqual(DictionaryMeta.objects.get(key="entries").value, "16")
        self.assertEqual(len(DictionaryMeta.objects.get(key="sha256").value), 64)
        # records added later (in the admin) get new ids, and the keys have defaults
        new = Record.objects.create(eng="new", cze="nový")
        self.assertGreater(new.id, 16)
        new.refresh_from_db()
        self.assertEqual((new.eng_key, new.eng_rank), ("", 0))

    def test_long_entries(self):
        long = Path(self.tmp.name) / "long.txt"
        long.write_text(f"long\t{'dlouhý ' * 60}\tn:\t{'poznámka ' * 70}\t\n")
        self.run_import("--replace", database=build_database(Path(self.tmp.name) / "long.sqlite", long))
        self.assertGreater(len(Record.objects.get(eng="long").special_cze), 500)

    def test_deleting_a_record_deletes_its_words(self):
        self.run_import("--replace")
        dog = Record.objects.get(eng="dog", cze="pes")
        # in the database itself, so that an older image (after a rollback) can delete too
        with connection.cursor() as cursor:
            cursor.execute("DELETE FROM web_record WHERE id = %s", [dog.id])
        self.assertFalse(Word.objects.filter(record_id=dog.id).exists())

    def test_gzipped_database(self):
        packed = Path(self.tmp.name) / "test.sqlite.gz"
        packed.write_bytes(gzip.compress(self.database.read_bytes()))
        self.run_import("--replace", database=packed)
        self.assertEqual(Record.objects.count(), 16)

    def test_missing_database(self):
        with self.assertRaises(CommandError):
            self.run_import(database=Path(self.tmp.name) / "missing.sqlite")


class AutomaticImportTests(ImportTestCase):
    """--auto, run at every start of the container."""

    def test_first_import(self):
        # the records of the old site: all in the import, or without a Czech translation
        Record.objects.create(eng="dog", cze="pes", notes_cze="n:", author="Milan Svoboda")
        Record.objects.create(eng="untranslated", cze="")
        self.assertIn("Imported 16 records", self.run_import("--auto"))
        self.assertEqual(Record.objects.count(), 16)

    def test_records_that_the_import_would_remove(self):
        Record.objects.create(eng="cat", cze="kočka")
        self.assertIn("The dictionary was not replaced", self.run_import("--auto"))
        self.assertEqual(Record.objects.count(), 1)

    def test_legacy_columns_block_it(self):
        Record.objects.create(eng="dog", cze="pes", notes_cze="n:", author="Milan Svoboda", notes_eng="note")
        output = self.run_import("--auto")
        self.assertIn("1 records have notes_eng or special_eng", output)
        self.assertIn("The dictionary was not replaced", output)

    def test_the_same_database_again(self):
        self.run_import("--auto")
        self.assertIn("is imported already", self.run_import("--auto"))

    def test_a_newer_database(self):
        self.run_import("--auto")
        self.assertIn("Imported 17 records", self.run_import("--auto", database=self.newer))
        self.assertTrue(Record.objects.filter(eng="cat").exists())

    def test_records_changed_after_the_import(self):
        self.run_import("--auto")
        Record.objects.filter(eng="dog", cze="pes").update(cze="psisko")
        output = self.run_import("--auto", database=self.newer)
        self.assertIn("The records changed after the last import.", output)
        self.assertIn("The dictionary was not replaced", output)
        self.assertTrue(Record.objects.filter(cze="psisko").exists())
        # replaced on purpose
        self.run_import("--replace", database=self.newer)
        self.assertFalse(Record.objects.filter(cze="psisko").exists())
