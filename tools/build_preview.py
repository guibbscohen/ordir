#!/usr/bin/env python3
"""Build the browser preview of the Dune guide from the same data the app ships.

Copies Preview/index.html, its font (Preview/fonts), the turn script and every picture it names (the crops in
Ordir/Assets.xcassets, from tools/crop_source_images.py) into Preview/dist/, so the preview can't
drift from the app's data. Run from the repo root:

    python3 tools/build_preview.py

Then serve Preview/dist (e.g. `python3 -m http.server -d Preview/dist`) and open index.html.
Needs no PDFs. Exits non-zero if a picture is missing.
"""
import json
import pathlib
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "Ordir" / "Games" / "Dune" / "duneWarForArrakis.turnscript.json"
DIST = ROOT / "Preview" / "dist"


def main():
    script = json.loads(SCRIPT.read_text())
    game = script["game"]
    assets = ROOT / "Ordir" / "Assets.xcassets" / game
    shutil.rmtree(DIST, ignore_errors=True)
    (DIST / "img").mkdir(parents=True)
    shutil.copy(ROOT / "Preview" / "index.html", DIST / "index.html")
    shutil.copytree(ROOT / "Preview" / "fonts", DIST / "fonts")
    shutil.copy(SCRIPT, DIST / "turnscript.json")
    missing = []
    for image in script["images"]:
        name = f"{game}-{image['id']}"
        source = assets / f"{name}.imageset" / f"{name}.jpg"
        if source.exists():
            shutil.copy(source, DIST / "img" / f"{image['id']}.jpg")
        else:
            missing.append(str(source.relative_to(ROOT)))
    if missing:
        sys.exit("Missing pictures, run tools/crop_source_images.py:\n  " + "\n  ".join(missing))
    print(f"Built {DIST.relative_to(ROOT)}: turn script v{script['version']}, {len(script['images'])} pictures")


if __name__ == "__main__":
    main()
