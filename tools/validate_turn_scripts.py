#!/usr/bin/env python3
"""Check every turn script under Ordir/Games against its official sources.

For each step (and each loop) it verifies the shape of the data and that every citation's
excerpt really appears on the cited page of the downloaded PDF. Every image must name a real source
page and have its generated asset (tools/crop_source_images.py). Run from the repo root:

    python3 tools/validate_turn_scripts.py

Needs pypdf (`pip install pypdf`). Exits non-zero on the first file with problems.
"""
import json
import pathlib
import re
import sys
import unicodedata

from pypdf import PdfReader

ROOT = pathlib.Path(__file__).resolve().parent.parent
SIDES = {"atreides", "harkonnen", "both"}


def normalise(text):
    # PDF extraction splits words ("STRA TEGY") and mangles punctuation, so compare letters and digits only.
    text = unicodedata.normalize("NFKC", text).lower()
    return re.sub(r"[^a-z0-9]", "", text)


def check_citations(citations, where, sources, pages, errors):
    if not citations:
        errors.append(f"{where}: no citations")
    for c in citations:
        source, page = c.get("source"), c.get("page")
        if source not in sources:
            errors.append(f"{where}: unknown source {source!r}")
            continue
        if not isinstance(page, int) or not 1 <= page <= len(pages[source]):
            errors.append(f"{where}: {source} has no page {page}")
            continue
        if source == "faq" and not c.get("entry"):
            errors.append(f"{where}: FAQ citation needs an entry")
        excerpt = c.get("excerpt", "")
        if len(normalise(excerpt)) < 20:
            errors.append(f"{where}: excerpt too short to verify")
        elif normalise(excerpt) not in pages[source][page - 1]:
            errors.append(f"{where}: excerpt not found on {source} p. {page}: {excerpt[:60]!r}")


def validate(path):
    script = json.loads(path.read_text())
    errors = []
    sources = {s["id"]: s for s in script["sources"]}
    pages = {
        sid: [normalise(p.extract_text() or "") for p in PdfReader(ROOT / s["file"]).pages]
        for sid, s in sources.items()
    }
    images = {}
    for image in script.get("images", []):
        where = f"image {image.get('id')}"
        images[image.get("id")] = image
        source, page, crop = image.get("source"), image.get("page"), image.get("crop", [])
        if not image.get("caption"):
            errors.append(f"{where}: missing caption")
        if source not in sources or not isinstance(page, int) or not 1 <= page <= len(pages[source]):
            errors.append(f"{where}: no page {page} in source {source!r}")
        if len(crop) != 4 or not (0 <= crop[0] < crop[2] <= 1 and 0 <= crop[1] < crop[3] <= 1):
            errors.append(f"{where}: crop must be [x0, y0, x1, y1] fractions of the page")
        name = f"{script['game']}-{image.get('id')}"
        if not (ROOT / "Ordir" / "Assets.xcassets" / script["game"] / f"{name}.imageset" / f"{name}.jpg").exists():
            errors.append(f"{where}: asset missing, run tools/crop_source_images.py")

    expansions = {e["id"] for e in script.get("expansions", [])}
    for e in expansions - set(sources):
        errors.append(f"expansion {e}: needs a source with the same id")

    ids = set()
    for phase in script["phases"]:
        if not phase.get("steps"):
            errors.append(f"{phase['id']}: phase has no steps")
        if "loop" in phase:
            loop = phase["loop"]
            if not loop.get("endLabel") or not loop.get("note"):
                errors.append(f"{phase['id']}: loop needs endLabel and note")
            check_citations(loop.get("citations", []), f"{phase['id']} loop", sources, pages, errors)
        for step in phase["steps"]:
            where = step.get("id", "?")
            if where in ids:
                errors.append(f"{where}: duplicate step id")
            ids.add(where)
            if step.get("side") not in SIDES:
                errors.append(f"{where}: side must be one of {sorted(SIDES)}")
            for field in ("title", "instruction"):
                if not step.get(field, "").strip():
                    errors.append(f"{where}: missing {field}")
            if not step.get("components"):
                errors.append(f"{where}: no components")
            if not step.get("images"):
                errors.append(f"{where}: no images")
            for image_id in step.get("images", []):
                if image_id not in images:
                    errors.append(f"{where}: unknown image {image_id!r}")
            if "expansion" in step and step["expansion"] not in expansions:
                errors.append(f"{where}: unknown expansion {step['expansion']!r}")
            check_citations(step.get("citations", []), where, sources, pages, errors)
            if not all(isinstance(b, str) and b.strip() for b in step.get("bullets", [])):
                errors.append(f"{where}: bullets must be non-empty strings")
            for n, reminder in enumerate(step.get("reminders", []), 1):
                at = f"{where} reminder {n}"
                if not reminder.get("text", "").strip():
                    errors.append(f"{at}: missing text")
                if "expansion" in reminder and reminder["expansion"] not in expansions:
                    errors.append(f"{at}: unknown expansion {reminder['expansion']!r}")
                check_citations(reminder.get("citations", []), at, sources, pages, errors)
            for n, addition in enumerate(step.get("additions", []), 1):
                at = f"{where} addition {n}"
                if addition.get("expansion") not in expansions:
                    errors.append(f"{at}: unknown expansion {addition.get('expansion')!r}")
                if not addition.get("text", "").strip():
                    errors.append(f"{at}: missing text")
                if not addition.get("images"):
                    errors.append(f"{at}: no images")
                for image_id in addition.get("images", []):
                    if image_id not in images:
                        errors.append(f"{at}: unknown image {image_id!r}")
                check_citations(addition.get("citations", []), at, sources, pages, errors)
    return errors


def main():
    scripts = sorted((ROOT / "Ordir" / "Games").rglob("*.turnscript.json"))
    if not scripts:
        sys.exit("No turn scripts found.")
    failed = False
    for path in scripts:
        errors = validate(path)
        rel = path.relative_to(ROOT)
        if errors:
            failed = True
            print(f"FAIL {rel}")
            for e in errors:
                print(f"  - {e}")
        else:
            print(f"ok   {rel}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
