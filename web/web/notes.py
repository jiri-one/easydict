import json
import re
from pathlib import Path

EXPLANATIONS = json.loads(Path(__file__).with_name("note_labels.json").read_text(encoding="utf-8"))
_TOKEN = re.compile(r"\[[^\]]*\]|\([^)]*\)|\S+")
_PRIORITY = re.compile(r"[+-]?[0-9]+")


def note_labels(notes: str | None, label_language: str) -> list[str]:
    language = 0 if label_language == "cze" else 1
    return [
        EXPLANATIONS[token][language] if token in EXPLANATIONS else token
        for token in _TOKEN.findall(notes or "")
        if not _PRIORITY.fullmatch(token)
    ]
