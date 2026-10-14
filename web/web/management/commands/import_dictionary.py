"""Import the dictionary into PostgreSQL from the SQLite database that data/tools/build_db.py
builds for the app, so that the website searches the same data as the app.

Without options it only compares the records with the database and changes nothing. --replace
replaces the whole dictionary (records, words, word forms) in one transaction: searches keep
working on the old data until it is committed, and an interrupted import changes nothing.

--auto is for the start of the container (deploy/entrypoint.py): it imports a database that is
not imported yet, unless that would remove records added or changed in the database itself
(in the admin, for example). Those cases are only reported, and the site keeps the old data.
"""

import gzip
import hashlib
import sqlite3
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.core.management.color import no_style
from django.db import connection, transaction
from django.db.models import Q

from web.dictionary import SCHEMA_VERSION
from web.models import CzechForm, DictionaryMeta, Record

EXAMPLES = 20


def database_sha256(path: Path) -> str:
    """From <database>.sha256 when it is there (deploy/Containerfile writes it), so that an
    unchanged database is not unpacked at every start."""
    checksum = path.with_name(path.name.removesuffix(".gz") + ".sha256")
    if path.suffix == ".gz" and checksum.is_file():
        return checksum.read_text().split()[0]
    return hashlib.sha256(read_database(path)).hexdigest()


def read_database(path: Path) -> bytes:
    data = path.read_bytes()
    return gzip.decompress(data) if path.suffix == ".gz" else data


def open_database(data: bytes) -> sqlite3.Connection:
    database = sqlite3.connect(":memory:")
    database.deserialize(data)
    return database


class CopyStream:
    """Streamed, so that no whole table is in memory as text: the server has little RAM."""

    def __init__(self, rows):
        self.rows = iter(rows)
        self.buffer = ""

    @staticmethod
    def field(value) -> str:
        if value is None:
            return "\\N"
        return str(value).replace("\\", "\\\\").replace("\t", "\\t").replace("\n", "\\n").replace("\r", "\\r")

    def read(self, size=-1) -> str:
        while size < 0 or len(self.buffer) < size:
            row = next(self.rows, None)
            if row is None:
                break
            self.buffer += "\t".join(map(self.field, row)) + "\n"
        if size < 0:
            size = len(self.buffer)
        data, self.buffer = self.buffer[:size], self.buffer[size:]
        return data



def copy_rows(table: str, columns: tuple[str, ...], rows) -> None:
    with connection.cursor() as cursor:
        cursor.copy_expert(f"COPY {table} ({', '.join(columns)}) FROM STDIN", CopyStream(rows), 65536)


def records_checksum() -> str:
    """Tells later whether the records changed after the import."""
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT md5(coalesce(string_agg("
            "row(id, eng, cze, notes_cze, notes_eng, special_cze, special_eng, author)::text, "
            "E'\\n' ORDER BY id), '')) FROM web_record"
        )
        return cursor.fetchone()[0]


def record_key(eng, cze, notes, special, author) -> tuple:
    return (eng, cze, notes or "", special or "", author or "")


class Command(BaseCommand):
    help = __doc__

    def add_arguments(self, parser):
        parser.add_argument(
            "database",
            nargs="?",
            default=settings.DICTIONARY_DATABASE,
            help="easydict.sqlite or easydict.sqlite.gz (default: %(default)s)",
        )
        mode = parser.add_mutually_exclusive_group()
        mode.add_argument("--replace", action="store_true", help="replace the dictionary")
        mode.add_argument(
            "--auto", action="store_true", help="import a new database when no records would be lost"
        )

    def handle(self, database, replace, auto, **options):
        path = Path(database)
        if not path.is_file():
            raise CommandError(f"{path} does not exist; build it with data/tools/build_db.py.")
        imported = dict(DictionaryMeta.objects.filter(key__in=("sha256", "records_checksum")).values_list())
        if auto and imported.get("sha256") == database_sha256(path):
            self.stdout.write(f"{path} is imported already.")
            return
        data = read_database(path)
        source = open_database(data)
        meta = dict(source.execute("SELECT key, value FROM meta"))
        if meta.get("schema_version") != SCHEMA_VERSION:
            raise CommandError(f"{path} has schema {meta.get('schema_version')}, expected {SCHEMA_VERSION}.")
        if not replace:
            if "records_checksum" in imported:
                # imported before: the records must be as that import left them
                lost = records_checksum() != imported["records_checksum"]
                if lost:
                    self.stdout.write("The records changed after the last import.")
                if not auto:
                    self.compare(source)
            else:
                lost = self.compare(source) > 0
            if not auto:
                self.stdout.write("Nothing changed. Run with --replace to import.")
                return
            if lost:
                self.stderr.write(
                    f"The dictionary was not replaced with {path}: that would remove records added or "
                    "changed here. Check them with `manage.py import_dictionary` and replace them with "
                    "--replace."
                )
                return
        self.replace(source, meta, hashlib.sha256(data).hexdigest())

    def compare(self, source: sqlite3.Connection) -> int:
        """Returns the number of records the import would remove. Records without a Czech
        translation don't count: build_db.py leaves them out, and nothing shows them."""
        current = Counter(
            record_key(*values)
            for values in Record.objects.exclude(cze="").values_list(
                "eng", "cze", "notes_cze", "special_cze", "author"
            )
        )
        imported = Counter(
            record_key(*row) for row in source.execute("SELECT eng, cze, notes, special, author FROM entries")
        )
        removed = current - imported
        added = imported - current
        self.stdout.write(
            f"Translations: {current.total()} in the database, {imported.total()} in the import; "
            f"{removed.total()} only in the database (would be removed), {added.total()} new."
        )
        for eng, cze, notes, special, author in list(removed.elements())[:EXAMPLES]:
            self.stdout.write(f"  - {eng} | {cze} | {notes} | {special} | {author}")
        untranslated = Record.objects.filter(cze="").count()
        if untranslated:
            self.stdout.write(f"{untranslated} records without a Czech translation are left out.")
        legacy = Record.objects.filter(Q(notes_eng__gt="") | Q(special_eng__gt="")).count()
        if legacy:
            self.stdout.write(f"{legacy} records have notes_eng or special_eng, which the import does not keep.")
        return removed.total() + legacy

    def replace(self, source: sqlite3.Connection, meta: dict[str, str], sha256: str) -> None:
        started = datetime.now(timezone.utc)
        with transaction.atomic():
            with connection.cursor() as cursor:
                # DELETE, not TRUNCATE: searches go on with the old data until the commit.
                for table in ("web_word", "web_czechform", "web_dictionarymeta", "web_record"):
                    cursor.execute(f"DELETE FROM {table}")
            copy_rows(
                "web_record",
                ("id", "eng", "cze", "notes_cze", "special_cze", "author", "eng_key", "cze_key", "eng_rank", "cze_rank"),
                source.execute(
                    "SELECT id, eng, cze, notes, special, author, eng_key, cze_key, eng_rank, cze_rank "
                    "FROM entries ORDER BY id"
                ),
            )
            copy_rows("web_word", ("lang", "word", "record_id"), source.execute("SELECT lang, word, entry_id FROM words"))
            for table, kind in (
                ("cs_forms_hunspell", CzechForm.HUNSPELL),
                ("cs_forms_wiktionary", CzechForm.WIKTIONARY),
            ):
                copy_rows(
                    "web_czechform",
                    ("form_key", "form", "lemma", "source"),
                    (row + (kind,) for row in source.execute(f"SELECT form_key, form, lemma FROM {table}")),
                )
            # New records (from the admin) must not take the ids of the imported ones.
            with connection.cursor() as cursor:
                for sql in connection.ops.sequence_reset_sql(no_style(), [Record]):
                    cursor.execute(sql)
            DictionaryMeta.objects.bulk_create(
                DictionaryMeta(key=key, value=value)
                for key, value in {
                    **meta,
                    "sha256": sha256,
                    "records_checksum": records_checksum(),
                    "imported": started.isoformat(timespec="seconds"),
                }.items()
            )
        with connection.cursor() as cursor:
            cursor.execute("ANALYZE web_record, web_word, web_czechform")
        seconds = (datetime.now(timezone.utc) - started).total_seconds()
        self.stdout.write(
            f"Imported {meta['entries']} records, {meta['words']} words and "
            f"{int(meta['forms_hunspell']) + int(meta['forms_wiktionary'])} word forms in {seconds:.0f} s."
        )
