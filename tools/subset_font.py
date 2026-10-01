#!/usr/bin/env python3
"""Subset Google Sans Flex (SIL OFL 1.1) to Latin for the app and the browser preview.

Source: google/fonts, ofl/googlesansflex. Weight and optical size stay variable; grade, roundness,
slant and width are pinned to their defaults, which keeps the files small. Run from the repo
root with the font's folder from a google/fonts checkout:

    python3 tools/subset_font.py path/to/google/fonts/ofl/googlesansflex

Writes Ordir/Fonts/GoogleSansFlex.ttf (app), Preview/fonts/GoogleSansFlex.woff2 (preview) and
copies OFL.txt next to each. Needs fonttools and brotli (`pip install fonttools brotli`).
"""
import pathlib
import shutil
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = pathlib.Path(__file__).resolve().parent.parent
# Basic Latin, Latin-1, Latin Extended-A, general punctuation, currency and arrows: every language
# the app's copy and the rulebooks use.
UNICODES = "U+0000-024F,U+02C6-02DD,U+1E00-1EFF,U+2000-206F,U+20A0-20CF,U+2100-215F,U+2190-21FF,U+2212,U+25CF"


def main():
    source = pathlib.Path(sys.argv[1])
    pinned = instancer.instantiateVariableFont(
        TTFont(next(source.glob("GoogleSansFlex*.ttf"))), {"GRAD": 0, "ROND": 0, "slnt": 0, "wdth": 100})
    font = ROOT / "build" / "GoogleSansFlex-pinned.ttf"
    font.parent.mkdir(exist_ok=True)
    pinned.save(font)
    for out, flavor in [(ROOT / "Ordir" / "Fonts" / "GoogleSansFlex.ttf", None),
                        (ROOT / "Preview" / "fonts" / "GoogleSansFlex.woff2", "woff2")]:
        out.parent.mkdir(parents=True, exist_ok=True)
        args = [str(font), f"--unicodes={UNICODES}", "--layout-features=*", f"--output-file={out}"]
        if flavor:
            args.append(f"--flavor={flavor}")
        subset.main(args)
        shutil.copy(source / "OFL.txt", out.parent / "OFL.txt")
        print(f"{out.relative_to(ROOT)}: {out.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
