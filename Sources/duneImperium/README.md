# Dune: Imperium — official sources

The PDFs are the publisher's (Dire Wolf Digital, under license from Gale Force Nine) and are not stored
in this repo. They are the English files on Dire Wolf's Dune: Imperium resources page
(https://www.direwolfdigital.com/dune-imperium/resources/). Download them with
`python3 tools/fetch_sources.py`, which checks each file against the SHA-256 recorded in the turn script.
Turn scripts cite them by PDF page, and `tools/validate_turn_scripts.py` checks every cited excerpt
against them.

| File | Source | Pages |
| --- | --- | --- |
| `DUNE_IMPERIUM_Rules_2020_10_26.pdf` | https://d19y2ttatozxjp.cloudfront.net/pdfs/DUNE_IMPERIUM_Rules_2020_10_26.pdf | 20 |
| `DUNE_IMPERIUM_FAQ_25-1-13.pdf` | https://d19y2ttatozxjp.cloudfront.net/pdfs/DUNE_IMPERIUM_FAQ_25-1-13.pdf | 4 (January 13, 2025) |
| `expansions/DUNE_IMPERIUM_RISE_OF_IX_Rulebook_22-2-11.pdf` | https://d19y2ttatozxjp.cloudfront.net/pdfs/DUNE_IMPERIUM_RISE_OF_IX_Rulebook_22-2-11.pdf | 12 (Rise of Ix) |
| `expansions/DUNE_IMPERIUM_IMMORTALITY_Rulebook.pdf` | https://d19y2ttatozxjp.cloudfront.net/pdfs/DUNE_IMPERIUM_IMMORTALITY_Rulebook.pdf | 16 (Immortality) |
| `expansions/DUNE_IMPERIUM_BLOODLINES_Rulebook.pdf` | https://d19y2ttatozxjp.cloudfront.net/pdfs/DUNE_IMPERIUM_BLOODLINES_Rulebook.pdf | 12 (Bloodlines) |

The FAQ is final: where it corrects a rulebook, the turn script follows the FAQ. The guide covers 3–4
players; the House Hagal rules for 1–2 players, Rise of Ix's Epic Game mode and Bloodlines' Tech Module
are not in it yet. Bloodlines is written for Uprising; the guide uses its "When playing BLOODLINES with
DUNE: IMPERIUM" changes (page 3).

Component pictures in the app are cropped from these pages by `tools/crop_source_images.py`; each
picture's page and crop box are listed under `images` in the turn script.
