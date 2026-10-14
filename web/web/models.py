"""The tables of the app's SQLite database (data/tools/build_db.py), so that web/dictionary.py
can search them with the app's queries."""

from django.db import models

# as in the SQLite database
ENG, CZE = 0, 1


class Record(models.Model):
    """notes_cze and special_cze hold the notes and special columns of the dictionary; notes_eng
    and special_eng are left from the first version of the site and stay empty."""

    # text: a longer entry in data/ must not make the import fail
    cze = models.TextField("Word in CZech")
    eng = models.TextField("Word in ENglish")
    notes_cze = models.TextField("Notes about translation", blank=True, null=True)
    notes_eng = models.CharField("Notes about translation", max_length=500, blank=True, null=True)
    special_cze = models.TextField("Special notes", blank=True, null=True)
    special_eng = models.CharField("Special notes", max_length=500, blank=True, null=True)
    author = models.TextField("Author's name of translation", blank=True, null=True)
    time_added = models.DateTimeField("Date of addition", blank=True, null=True)
    time_changed = models.DateTimeField("Date of change", blank=True, null=True)
    # Collation "C" compares by code point like SQLite, so both sort alike. The defaults are in
    # the database, so that an older image (after a rollback) can still add records.
    eng_key = models.TextField(db_default="", editable=False, db_collation="C")
    cze_key = models.TextField(db_default="", editable=False, db_collation="C")
    eng_rank = models.IntegerField(db_default=0, editable=False)
    cze_rank = models.IntegerField(db_default=0, editable=False)

    class Meta:
        indexes = [
            models.Index(fields=["eng_key"], name="web_record_eng_key"),
            models.Index(fields=["cze_key"], name="web_record_cze_key"),
        ]

    def __str__(self):
        return f"{self.cze} - {self.eng}"


class Word(models.Model):
    pk = models.CompositePrimaryKey("lang", "word", "record")
    lang = models.SmallIntegerField(choices=[(ENG, "English"), (CZE, "Czech")])
    word = models.TextField(db_collation="C")
    # in the database, so that an older image (after a rollback) can still delete records
    record = models.ForeignKey(Record, on_delete=models.DB_CASCADE)


class CzechForm(models.Model):
    HUNSPELL, WIKTIONARY = 0, 1

    pk = models.CompositePrimaryKey("form_key", "form", "lemma", "source")
    form_key = models.TextField(db_collation="C")
    form = models.TextField(db_collation="C")
    lemma = models.TextField(db_collation="C")
    source = models.SmallIntegerField(choices=[(HUNSPELL, "Hunspell"), (WIKTIONARY, "Wiktionary")])


class DictionaryMeta(models.Model):
    key = models.CharField(max_length=100, primary_key=True)
    value = models.TextField()

    def __str__(self):
        return self.key
