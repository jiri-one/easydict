#!/bin/sh
# The web app for GitHub Pages, app.easydict.jiri.one. Run tool/build_dictionary.sh
# first. The copy of the dictionary and SQLite load only when the website does
# not answer, so they cost its visitors nothing.
set -eu

cd "$(dirname "$0")/.."

# Fetched here and not a dependency of the app: F-Droid and Flathub build
# everything from source (pubspec.yaml), and only this build needs it.
sqlite_wasm=3.54.1-build1
sqlite_wasm_sha256=06aaad2dd0b58a46631000a31a4469afff4abeffbc383f37372b6590396d9bbd

# The date of the data, not of this build. The app does not start without it.
copy_date="$(git log -1 --format=%cs -- ../data)"
test -n "$copy_date"

# The last --base-href wins. A deployment replaces the whole site, so the file
# keeps its name for tabs opened before it; the query tells browsers it changed.
tool/build_web.sh --base-href / \
    --dart-define=EASYDICT_API=https://easydict.jiri.one/api/ \
    --dart-define=DICTIONARY_COPY="easydict.sqlite.gz?v=$(cut -c1-16 assets/dictionary/easydict.sha256)" \
    --dart-define=DICTIONARY_COPY_DATE="$copy_date" \
    "$@"
gzip -9nc assets/dictionary/easydict.sqlite > build/web/easydict.sqlite.gz

archive=build/sqlite-wasm.tgz
curl -fsSL -o "$archive" "https://registry.npmjs.org/@sqlite.org/sqlite-wasm/-/sqlite-wasm-$sqlite_wasm.tgz"
echo "$sqlite_wasm_sha256  $archive" | sha256sum -c --quiet -
mkdir -p build/web/sqlite
tar xzf "$archive" -C build/web/sqlite --strip-components=2 package/dist/index.mjs package/dist/sqlite3.wasm
