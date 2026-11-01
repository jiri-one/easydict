# EasyDict website
The website of the EasyDict project, [https://easydict.jiri.one](https://easydict.jiri.one): Django (Python) with PostgreSQL as the backend and some pure JavaScript as the frontend. It also answers the searches of the web app.

## The dictionary

The site searches the same dictionary as the app, in the same way: `web/dictionary.py` is a port of `app/lib/data/dictionary.dart`, and `web/tests/test_dictionary.py` runs the tests of the app against it. A change of the search belongs to both.

The data come from the SQLite database of the app, which `data/tools/build_db.py` builds from `data/` of this repository. `manage.py import_dictionary` copies it into PostgreSQL:

    python ../data/tools/build_db.py /tmp/easydict.sqlite
    python manage.py import_dictionary /tmp/easydict.sqlite             # only compares
    python manage.py import_dictionary /tmp/easydict.sqlite --replace   # imports

The production image has the database built in, and the container imports it when it starts (`--auto`), unless the import would remove translations added or changed in PostgreSQL itself, e.g. in the admin; then it only logs a warning and the site keeps its data. Until the first import, the search answers 503: a database with the records of the old site has to be imported once with `--replace` after checking the comparison. Once the site lets people add translations, those must get into `data/en-cs/en-cs.txt`, or the import must merge instead of replacing.

## The web app

The public web app lives on GitHub Pages at [app.easydict.jiri.one](https://app.easydict.jiri.one), so that it does not go down with the server (`app/tool/build_pages.sh`, deployed by the `CI` workflow from `main`). A Cloudflare redirect rule sends `/app` there, keeping the query. The app searches through `/api/search` and `/api/info`, so it has the same data as the site, which is why `WEBAPP_ORIGIN` in the settings allows that one origin to read them. When the API does not answer twice in a row (an error 5xx or 5 s of silence), the app downloads a copy of the dictionary from GitHub Pages once and searches in the browser, with SQLite compiled to WebAssembly and the same queries as the offline apps. It says so in a banner and tries the API again every minute. The copy is built from `data/` with every deployment, so it does not have translations approved since they were exported. Add `?source=copy` to the address to try it; `app/tool/check_copy.py` checks it in a browser in CI.

The image still builds its own copy of the app without the fallback (`app/tool/build_web.sh`): `/app` shows it if the redirect rule is off. The view returns its `index.html`, and the container copies the rest to the static files, where it is served from `/static/app/`.

For development, build the web app and run the site with `WEBAPP_DIR=../app/build/web`; outside production, Django serves the build from `/static/app/` itself. API and page then share an origin, so no CORS is involved.

## Tests

The tests need PostgreSQL and a checkout of the whole repository (they build their data with `data/tools/build_db.py` from the fixtures of the app): `python manage.py test web`.

## Production

The production image is built from `deploy/Containerfile` with the repository as the build context:

    podman build -f web/deploy/Containerfile .

The `Website image` workflow builds it on every change of `web/`, `app/` or `data/` on `main` once the tests pass, and publishes it as `ghcr.io/jiri-one/easydict-web`. The server runs that image and updates it at night with `podman auto-update`, so whatever is merged to `main` goes live, migrations included.
