# EasyDict website
The website of the EasyDict project, [https://easydict.jiri.one](https://easydict.jiri.one): Django (Python) with PostgreSQL as the backend and some pure JavaScript as the frontend. It also serves the web build of the app at `/app`.

## The dictionary

The site searches the same dictionary as the app, in the same way: `web/dictionary.py` is a port of `app/lib/data/dictionary.dart`, and `web/tests/test_dictionary.py` runs the tests of the app against it. A change of the search belongs to both.

The data come from the SQLite database of the app, which `data/tools/build_db.py` builds from `data/` of this repository. `manage.py import_dictionary` copies it into PostgreSQL:

    python ../data/tools/build_db.py /tmp/easydict.sqlite
    python manage.py import_dictionary /tmp/easydict.sqlite             # only compares
    python manage.py import_dictionary /tmp/easydict.sqlite --replace   # imports

The production image has the database built in, and the container imports it when it starts (`--auto`), unless the import would remove translations added or changed in PostgreSQL itself, e.g. in the admin; then it only logs a warning and the site keeps its data. Until the first import, the search answers 503: a database with the records of the old site has to be imported once with `--replace` after checking the comparison. Once the site lets people add translations, those must get into `data/en-cs/en-cs.txt`, or the import must merge instead of replacing.

## The web app

`/app` shows the web build of the app (`app/tool/build_web.sh`): the view returns its `index.html`, and the container copies the rest to the static files, where it is served from `/static/app/`. The web app searches through `/api/search` and `/api/info`, so it has the same data as the site.

For development, build the web app and run the site with `WEBAPP_DIR=../app/build/web`; outside production, Django serves the build from `/static/app/` itself.

## Tests

The tests need PostgreSQL and a checkout of the whole repository (they build their data with `data/tools/build_db.py` from the fixtures of the app): `python manage.py test web`.

Label explanations in Czech and English live in `web/web/note_labels.json` and follow `data/en-cs/format.cs.md` and `format.en.md`. After editing them, run `python3 data/tools/generate_note_labels.py` from the repository root to update the app's copy. The app tests check that the two stay in sync. Unknown labels remain visible; translation priorities are hidden.

Result labels follow the app's interface language or the website's page language in both search directions, just like the controls and help.

## Production

The production image is built from `deploy/Containerfile` with the repository as the build context:

    podman build -f web/deploy/Containerfile .

The `Website image` workflow builds it on every change of `web/`, `app/` or `data/` on `main` once the tests pass, and publishes it as `ghcr.io/jiri-one/easydict-web`. The server runs that image and updates it at night with `podman auto-update`, so whatever is merged to `main` goes live, migrations included.

## Pronunciation

The speakers in the search results and the web app use `GET /api/speech?lang=cze&q=ahoj` (or `lang=eng`), which returns mono PCM WAV from the same bundled RHVoice 1.18.4, Radek and Slt as the app. `spoken_text` in `web/speech.py` is a port of `app/lib/data/speech_text.dart`, and both are tested against `app/test/fixtures/speech_text.json`: a change belongs to both. Requests accept 1–300 characters, run without a shell, and stop after ten seconds. Only one renderer runs at a time across the workers, and a request arriving meanwhile gets a 503, which the clients retry, so speech cannot block searching. Successful responses can be cached for one day. Each request uses an isolated renderer process so a timeout cannot leave synthesis running in a web worker.

For local development:

    cmake -S ../app/native -B speech -DCMAKE_BUILD_TYPE=Release -DSPEECH_CLI=ON
    cmake --build speech -j2

The container compiles this dependency from the vendored sources. `SPEECH_EXECUTABLE` and `SPEECH_DATA` override the executable and data directories. The production image includes the engine library next to the renderer and needs no audio device. Existing security middleware permits this same-origin GET endpoint.

Speech licences are listed in the [main README](../README.md); see `../app/native/README.md` for the sources.
