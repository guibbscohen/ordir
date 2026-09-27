#!/usr/bin/env python3
"""Crop component images out of the official PDFs, as listed in each turn script's "images".

Each image names a source, a page and a crop box (fractions of the page: x0, y0, x1, y1), so every
picture in the app traces back to a rulebook page. Output goes to
Ordir/Assets.xcassets/<game>/<game>-<id>.imageset. Run from the repo root after editing a script:

    python3 tools/crop_source_images.py

Needs pypdfium2 and Pillow (`pip install pypdfium2 pillow`).
"""
import json
import pathlib
import shutil

import pypdfium2

ROOT = pathlib.Path(__file__).resolve().parent.parent
ASSETS = ROOT / "Ordir" / "Assets.xcassets"
SCALE = 3  # 216 dpi: sharp at the sizes the app shows
INFO = {"info": {"author": "xcode", "version": 1}}


def main():
    for path in sorted((ROOT / "Ordir" / "Games").rglob("*.turnscript.json")):
        script = json.loads(path.read_text())
        game = script["game"]
        folder = ASSETS / game
        shutil.rmtree(folder, ignore_errors=True)
        folder.mkdir(parents=True)
        (folder / "Contents.json").write_text(json.dumps(INFO, indent=2) + "\n")

        files = {s["id"]: ROOT / s["file"] for s in script["sources"]}
        docs, rendered = {}, {}
        for image in script.get("images", []):
            key = (image["source"], image["page"])
            if key not in rendered:
                doc = docs.setdefault(image["source"], pypdfium2.PdfDocument(files[image["source"]]))
                rendered[key] = doc[image["page"] - 1].render(scale=SCALE).to_pil().convert("RGB")
            page = rendered[key]
            x0, y0, x1, y1 = image["crop"]
            w, h = page.size
            crop = page.crop((round(x0 * w), round(y0 * h), round(x1 * w), round(y1 * h)))

            name = f"{game}-{image['id']}"
            imageset = folder / f"{name}.imageset"
            imageset.mkdir()
            crop.save(imageset / f"{name}.jpg", quality=85, optimize=True)
            contents = {"images": [{"filename": f"{name}.jpg", "idiom": "universal"}], **INFO}
            (imageset / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
        print(f"{path.relative_to(ROOT)}: {len(script.get('images', []))} images")


if __name__ == "__main__":
    main()
