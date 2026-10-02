#!/usr/bin/env python3
"""Check that every piece of screen text has its Portuguese and Spanish translation.

Screen text is looked up by its English wording in Ordir/Localization/strings.json, shared by the app
(tr("…"), Text(tr: "…"), and lists such as the tutorial's cards and Home's phrases) and the browser preview
(t("…"), and the tables of tabs, games, tour cards and phrases in Preview/index.html). This finds every such
string and checks both languages have it, with the same {0}, {1}… placeholders. Run from the repo root:

    python3 tools/check_strings.py
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LANGUAGES = ("pt-BR", "es-419")
QUOTED = r'"((?:[^"\\]|\\.)*)"'


def block(text, start, end="\n];"):
    """The text between a line that starts a list and the line that closes it."""
    begin = text.index(start)
    return text[begin:text.index(end, begin)]


def preview_strings():
    html = (ROOT / "Preview" / "index.html").read_text()
    found = re.findall(r"\bt\(" + QUOTED, html)
    found += re.findall(r'\["(?:games|ask|join|account)", "([^"]+)"\]', html)  # tab labels
    found += [s for s in re.findall(QUOTED, block(html, '${[["table", "One phone', "]].map"))
              if s not in ("table", "pass", "own")]  # play modes
    found += re.findall(r"(?:title|text): " + QUOTED, block(html, "const TOUR = ["))
    found += re.findall(r"(?:detail|askExample): " + QUOTED, block(html, "const GAMES = ["))
    found += re.findall(QUOTED, block(html, "const PHRASES = ["))
    return found


def app_strings():
    found = []
    for path in (ROOT / "Ordir").rglob("*.swift"):
        swift = path.read_text()
        found += re.findall(r"\btr\(" + QUOTED, swift)
        found += re.findall(r"Text\(tr: " + QUOTED, swift)
        if "static let phrases = [" in swift:
            found += re.findall(QUOTED, block(swift, "static let phrases = [", "\n    ]"))
        if "private static let cards = [" in swift:
            found += re.findall(r"(?:title|text): " + QUOTED, block(swift, "private static let cards = [", "\n    ]"))
    return found


def placeholders(text):
    return sorted(re.findall(r"\{\d\}", text))


def main():
    table = json.loads((ROOT / "Ordir" / "Localization" / "strings.json").read_text())
    used = {s.replace('\\"', '"') for s in preview_strings() + app_strings()}
    errors = []
    for lang in LANGUAGES:
        words = table.get(lang, {})
        for english in sorted(used):
            if english not in words:
                errors.append(f"{lang}: missing {english!r}")
            elif placeholders(words[english]) != placeholders(english):
                errors.append(f"{lang}: placeholders differ in {english!r}")
    if errors:
        print("FAIL Ordir/Localization/strings.json")
        for e in errors:
            print(f"  - {e}")
        sys.exit(1)
    print(f"ok   Ordir/Localization/strings.json: {len(used)} strings in {', '.join(LANGUAGES)}")


if __name__ == "__main__":
    main()
