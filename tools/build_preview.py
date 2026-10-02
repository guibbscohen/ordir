#!/usr/bin/env python3
"""Build the browser preview of the game guides from the same data the app ships.

Copies Preview/index.html, its screen text in other languages (strings.js, from the app's
Ordir/Localization/strings.json), its font (Preview/fonts), its icons
and web-app manifest, every game's turn script (scripts/<game>.json) with its translations
(scripts/<game>.<lang>.json, from <game>.turnscript.<lang>.json) and every picture each names
(img/<game>/<id>.jpg, the crops in Ordir/Assets.xcassets from tools/crop_source_images.py) into Preview/dist/,
so the preview can't drift from the app's data. Run from the repo root:

    python3 tools/build_preview.py

Then serve Preview/dist (e.g. `python3 -m http.server -d Preview/dist`) and open index.html.
Needs no PDFs. Exits non-zero if a picture is missing.
"""
import datetime
import json
import pathlib
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCRIPTS = sorted((ROOT / "Ordir" / "Games").rglob("*.turnscript.json"))
LANGUAGES = ("pt-BR", "es-419")  # besides English
DIST = ROOT / "Preview" / "dist"


def build_stamp():
    try:
        commit = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        commit = "dev"
    return f"{commit} · {datetime.datetime.now(datetime.timezone.utc):%Y-%m-%d %H:%M} UTC"


def main():
    shutil.rmtree(DIST, ignore_errors=True)
    DIST.mkdir(parents=True)
    # Stamp the version (commit and date) that the Account tab shows, so a phone can tell which build it runs.
    (DIST / "index.html").write_text((ROOT / "Preview" / "index.html").read_text().replace("__BUILD__", build_stamp()))
    shutil.copytree(ROOT / "Preview" / "fonts", DIST / "fonts")
    shutil.copytree(ROOT / "Preview" / "email", DIST / "email")  # images for the sign-in email (docs/email)
    shutil.copytree(ROOT / "Preview" / "icons", DIST / "icons")  # Home Screen and tab icons (rendered from icons/icon.svg)
    shutil.copy(ROOT / "Preview" / "manifest.webmanifest", DIST / "manifest.webmanifest")
    # Screen text in Portuguese and Spanish, shared with the app (Ordir/Localization/strings.json).
    strings = (ROOT / "Ordir" / "Localization" / "strings.json").read_text()
    (DIST / "strings.js").write_text(f"const STRINGS = {strings.strip()};\n")
    # Every game's turn script (scripts/<game>.json) and its pictures (img/<game>/<id>.jpg).
    (DIST / "scripts").mkdir()
    missing, built = [], []
    for path in SCRIPTS:
        script = json.loads(path.read_text())
        game = script["game"]
        assets = ROOT / "Ordir" / "Assets.xcassets" / game
        shutil.copy(path, DIST / "scripts" / f"{game}.json")
        for lang in LANGUAGES:
            translation = path.with_name(path.name.replace(".json", f".{lang}.json"))
            if translation.exists():
                shutil.copy(translation, DIST / "scripts" / f"{game}.{lang}.json")
        (DIST / "img" / game).mkdir(parents=True)
        for image in script["images"]:
            name = f"{game}-{image['id']}"
            source = assets / f"{name}.imageset" / f"{name}.jpg"
            if source.exists():
                shutil.copy(source, DIST / "img" / game / f"{image['id']}.jpg")
            else:
                missing.append(str(source.relative_to(ROOT)))
        built.append(f"{game} v{script['version']} ({len(script['images'])} pictures)")
    if missing:
        sys.exit("Missing pictures, run tools/crop_source_images.py:\n  " + "\n  ".join(missing))
    print(f"Built {DIST.relative_to(ROOT)}: " + ", ".join(built))

if __name__ == "__main__":
    main()
