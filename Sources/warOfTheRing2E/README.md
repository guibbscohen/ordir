# War of the Ring (Second Edition) — official sources

The PDFs are the publisher's (Ares Games, under license from Sophisticated Games) and are not stored
in this repo. They are downloaded from the game's official site, warofthering.eu. Download them with
`python3 tools/fetch_sources.py`, which checks each file against the SHA-256 recorded in the turn
script. Printed page numbers match PDF pages. Turn scripts cite these files by page, and
`tools/validate_turn_scripts.py` checks every cited excerpt against them.

| File | Source | Pages |
| --- | --- | --- |
| `WotR_2nd_Edition_Rules.pdf` | https://warofthering.eu/WotR_2nd_Edition_Rules.pdf | 48 |
| `WotR_2nd_Ed_FAQ.pdf` | https://warofthering.eu/WotR_2nd_Ed_FAQ.pdf | 3 (FAQ 1.2, September 2014) |
| `expansions/LOME_rules.pdf` | https://warofthering.eu/LOME_rules.pdf | 32 (Lords of Middle-earth) |
| `expansions/WoMe_rules.pdf` | https://warofthering.eu/WoMe_rules.pdf | 28 (Warriors of Middle-earth) |

The FAQ is final: where it corrects the rulebook (for example how hand-limit discards follow the draws),
the turn script follows the FAQ.

Kings of Middle-earth is not included yet: its rules are only on aresgames.eu, which blocks automated
downloads. Add it once its PDF is available here.

Component pictures in the app are cropped from these pages by `tools/crop_source_images.py`; each
picture's page and crop box are listed under `images` in the turn script.
