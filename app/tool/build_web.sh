#!/bin/sh
# Run tool/build_dictionary.sh first: the web app has no database, but it needs
# the licence notice of the dictionary. Arguments go to `flutter build web`.
#
# Nothing may come from elsewhere than the website: CanvasKit is in the build
# (--no-web-resources-cdn), and Roboto, which the engine would fetch from Google
# Fonts, comes from the Flutter SDK.
set -eu

cd "$(dirname "$0")/.."
flutter build web --release --no-web-resources-cdn --base-href /static/app/ "$@"
# A JavaScript build loads only canvaskit/ or canvaskit/chromium/: skwasm is for
# WebAssembly builds, the symbols for debugging.
rm -r build/web/canvaskit/skwasm* build/web/canvaskit/wimp* build/web/canvaskit/webparagraph
find build/web/canvaskit -name '*.symbols' -delete

fonts="$(flutter --version --machine | python3 -c 'import json, sys; print(json.load(sys.stdin)["flutterRoot"])')/bin/cache/artifacts/material_fonts"
roboto=build/web/assets/fonts/roboto
mkdir -p "$roboto"
for weight in Regular Medium Bold; do
    cp "$fonts/Roboto-$weight.ttf" "$roboto/"
done
cp "$fonts/Roboto_LICENSE.txt" "$roboto/LICENSE.txt"
python3 - <<'EOF'
import json
from pathlib import Path

manifest = Path("build/web/assets/FontManifest.json")
families = [family for family in json.loads(manifest.read_text()) if family["family"] != "Roboto"]
families.append({
    "family": "Roboto",
    "fonts": [
        {"asset": "fonts/roboto/Roboto-Regular.ttf"},
        {"asset": "fonts/roboto/Roboto-Medium.ttf", "weight": 500},
        {"asset": "fonts/roboto/Roboto-Bold.ttf", "weight": 700},
    ],
})
manifest.write_text(json.dumps(families))
EOF
