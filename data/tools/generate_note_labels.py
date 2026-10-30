#!/usr/bin/env python3
"""Keep Flutter's label explanations in sync with the website."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def dart_string(text: str) -> str:
    return json.dumps(text, ensure_ascii=False).replace("$", r"\$")


def main():
    labels = json.loads((ROOT / "web/web/note_labels.json").read_text(encoding="utf-8"))
    entries = "\n".join(
        f"  {dart_string(code)}: ({dart_string(cs)}, {dart_string(en)}),"
        for code, (cs, en) in labels.items()
    )
    (ROOT / "app/lib/data/note_labels.g.dart").write_text(
        "// Generated from web/web/note_labels.json to keep both interfaces in sync.\n"
        "part of 'notes.dart';\n\n"
        f"const _explanations = <String, (String, String)>{{\n{entries}\n}};\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
