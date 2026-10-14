"""The dictionary tests build their data with data/tools/build_db.py from the app's fixtures, so
they need a checkout of the whole repository."""

import importlib.util
import io
import tempfile
from pathlib import Path
from unittest import skipUnless

from django.core.management import call_command
from django.test import TestCase

REPOSITORY = Path(__file__).resolve().parents[3]
BUILD_DB = REPOSITORY / "data" / "tools" / "build_db.py"
APP_FIXTURES = REPOSITORY / "app" / "test" / "fixtures"


def build_database(output: Path, en_cs: Path, forms: bool = True) -> Path:
    spec = importlib.util.spec_from_file_location("build_db", BUILD_DB)
    build_db = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(build_db)
    # with the word frequencies, as `build_db.py` builds it for the tests of the app
    build_db.build(
        output,
        en_cs,
        APP_FIXTURES / "hunspell" if forms else None,
        APP_FIXTURES / "forms.tsv" if forms else None,
        REPOSITORY / "data" / "frequency",
    )
    return output


@skipUnless(BUILD_DB.exists(), "needs data/tools of the repository")
class DictionaryTestCase(TestCase):
    en_cs_lines: list[str] | None = None
    forms = True

    @classmethod
    def setUpTestData(cls):
        with tempfile.TemporaryDirectory() as tmp:
            en_cs = APP_FIXTURES / "en-cs.txt"
            if cls.en_cs_lines is not None:
                en_cs = Path(tmp) / "en-cs.txt"
                en_cs.write_text("\n".join(cls.en_cs_lines) + "\n", encoding="utf-8")
            database = build_database(Path(tmp) / "test.sqlite", en_cs, cls.forms)
            call_command("import_dictionary", database, "--replace", stdout=io.StringIO())
