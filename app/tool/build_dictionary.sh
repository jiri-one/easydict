#!/bin/sh
# Run it before `flutter run` or `flutter build`; it needs only python3.
set -eu

cd "$(dirname "$0")/.."
python3 ../data/tools/build_db.py assets/dictionary/easydict.sqlite
# The app copies the database out of its assets; the checksum tells it when
# the bundled database changed.
python3 -c "
import hashlib, pathlib
db = pathlib.Path('assets/dictionary/easydict.sqlite')
db.with_suffix('.sha256').write_text(hashlib.sha256(db.read_bytes()).hexdigest() + '\n')
"
