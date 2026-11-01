#!/bin/sh
# The web app for GitHub Pages, app.easydict.jiri.one. Run tool/build_dictionary.sh
# first. It searches on the website, and when that does not answer, in a copy of
# the dictionary (lib/data/failover_dictionary.dart). The copy and SQLite load
# only then, so they cost the visitors of a working website nothing.
set -eu

cd "$(dirname "$0")/.."

# Fetched here and not a dependency of the app: F-Droid and Flathub build
# everything from source (pubspec.yaml), and only this build needs it.
sqlite_wasm=3.54.1-build1
sqlite_wasm_sha256=06aaad2dd0b58a46631000a31a4469afff4abeffbc383f37372b6590396d9bbd

copy="easydict-$(cut -c1-16 assets/dictionary/easydict.sha256).sqlite.gz"
BASE_HREF=/ tool/build_web.sh \
    --dart-define=EASYDICT_API=https://easydict.jiri.one/api/ \
    --dart-define=DICTIONARY_COPY="$copy" \
    --dart-define=DICTIONARY_COPY_DATE="$(date -u +%F)" \
    "$@"
gzip -9nc assets/dictionary/easydict.sqlite > "build/web/$copy"

archive=build/sqlite-wasm.tgz
curl -fsSL -o "$archive" "https://registry.npmjs.org/@sqlite.org/sqlite-wasm/-/sqlite-wasm-$sqlite_wasm.tgz"
echo "$sqlite_wasm_sha256  $archive" | sha256sum -c --quiet -
mkdir -p build/web/sqlite
tar xzf "$archive" -C build/web/sqlite --strip-components=2 package/dist/index.mjs package/dist/sqlite3.wasm
