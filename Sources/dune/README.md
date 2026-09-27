# Dune: War for Arrakis — official sources

Downloaded 2026-09-27 from the publisher (CMON). Expansion page numbers match their PDF pages. Turn scripts cite these files by page, and
`tools/validate_turn_scripts.py` checks every cited excerpt against them.

| File | Source | Pages |
| --- | --- | --- |
| `Dune-WIP-Rulebook.pdf` | https://resources.cmon.com/Dune-WIP-Rulebook.pdf | 36 (printed page numbers match PDF pages) |
| `Dune-FAQ-3_0.pdf` | https://www.cmon.com/wp-content/uploads/2024/01/Dune-FAQ-3_0.pdf | 4 (FAQ 3.0, June 2024) |
| `expansions/Dune_Desert_War_Rulebook_web.pdf` | https://resources.cmon.com/Dune_Desert_War_Rulebook_web.pdf | 8 |
| `expansions/Smugglers_Rulebook_web.pdf` | http://resources.cmon.com/Smugglers_Rulebook_web.pdf | 8 |
| `expansions/Spacing_Guild_Rulebook_web.pdf` | http://resources.cmon.com/Spacing_Guild_Rulebook_web.pdf | 8 |

The rulebook is the publisher's work-in-progress edition. FAQ 3.0 is final: where it differs from the
rulebook (for example FAQ modified rule 1 on Imperium Bans), the turn script follows the FAQ.

Component pictures in the app are cropped from these pages by `tools/crop_source_images.py`; each
picture's page and crop box are listed under `images` in the turn script.
