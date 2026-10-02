# Star Wars: Rebellion — official sources

The PDFs are the publisher's (Fantasy Flight Games) and are not stored in this repo. Download them with
`python3 tools/fetch_sources.py`, which checks each file against the SHA-256 recorded in the turn
script. Printed page numbers match PDF pages. Turn scripts cite these files by page, and
`tools/validate_turn_scripts.py` checks every cited excerpt against them.

| File | Source | Pages |
| --- | --- | --- |
| `sw03_learn_to_play_web.pdf` | https://cdn.svc.asmodee.net/production-fantasyflightgames/uploads/2026/09/sw03_learn_to_play_web.pdf | 20 |
| `sw03_rules_reference_web.pdf` | https://cdn.svc.asmodee.net/production-fantasyflightgames/uploads/2026/09/sw03_rules_reference_web.pdf | 16 |
| `sw03_faq_v2_1.pdf` | https://cdn.svc.asmodee.net/production-fantasyflightgames/uploads/2026/09/sw03_faq_v2_1.pdf | 8 (FAQ v2.1, May 2019) |
| `expansions/sw04_rulebook_web.pdf` | https://cdn.svc.asmodee.net/production-fantasyflightgames/uploads/2026/09/sw04_rulebook_web.pdf | 2 (Rise of the Empire rulesheet) |

The FAQ is final: where its errata differ from the Rules Reference (for example the Rebel player's
starting units and when the Rebel base may be revealed), the turn script follows the FAQ.

Component pictures in the app are cropped from these pages by `tools/crop_source_images.py`; each
picture's page and crop box are listed under `images` in the turn script.
