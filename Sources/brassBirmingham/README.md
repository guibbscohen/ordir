# Brass: Birmingham — official sources

The PDF is the publisher's (Roxley Games) and is not stored in this repo. It is the English rulebook
linked from roxley.com/brass-birmingham. Download it with `python3 tools/fetch_sources.py`, which checks it
against the SHA-256 recorded in the turn script. Turn scripts cite it by PDF page, and
`tools/validate_turn_scripts.py` checks every cited excerpt against it.

| File | Source | Pages |
| --- | --- | --- |
| `Brass-Birmingham-Rulebook.pdf` | https://cdn.shopify.com/s/files/1/0246/2190/8043/files/Brass-Birmingham-Rulebook.pdf (rulebook v2018.11) | 7 |

Each PDF page after the first is a spread of two printed pages, so citations use the PDF page (the
one the app opens), not the printed number: PDF page 3 is printed pages 4–5, page 4 is 6–7, page 5
is 8–9, page 6 is 10–11 and page 7 is 12.

The guide covers the base game for 2–4 players (no expansions).

Component pictures in the app are cropped from these pages by `tools/crop_source_images.py`; each
picture's page and crop box are listed under `images` in the turn script.
