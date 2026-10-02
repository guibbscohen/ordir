# Terraforming Mars — official sources

The PDFs are the publisher's (FryxGames, published with Stronghold Games) and are not stored in this repo. They
are the English rules linked from each game's page on fryxgames.se. Download them with
`python3 tools/fetch_sources.py`, which checks each against the SHA-256 recorded in the turn script. Turn
scripts cite them by PDF page, and `tools/validate_turn_scripts.py` checks every cited excerpt against them.

| File | Source | Pages |
| --- | --- | --- |
| `TMRULESFINAL.pdf` | https://fryxgames.se/wp-content/uploads/2023/04/TMRULESFINAL.pdf (linked from https://fryxgames.se/games/terraforming-mars/) | 16 |
| `expansions/TM_PRELUDE_ENG_RULESi.pdf` | https://fryxgames.se/wp-content/uploads/2023/07/TM_PRELUDE_ENG_RULESi.pdf | 4 |
| `expansions/TM_VENUS_ENG_RULESi.pdf` | https://fryxgames.se/wp-content/uploads/2023/07/TM_VENUS_ENG_RULESi.pdf | 4 |
| `expansions/TM_COLONIES_ENG_RULESi.pdf` | https://fryxgames.se/wp-content/uploads/2023/07/TM_COLONIES_ENG_RULESi.pdf | 4 |
| `expansions/TM_TURMOIL_ENG_RULESi.pdf` | https://fryxgames.se/wp-content/uploads/2023/07/TM_TURMOIL_ENG_RULESi.pdf | 8 |
| `expansions/TM_HE_WRAP_ENGi.pdf` | https://fryxgames.se/wp-content/uploads/2023/07/TM_HE_WRAP_ENGi.pdf (the Hellas & Elysium box wrap) | 1 |

The guide covers the standard game for 2–5 players, with Prelude, Venus Next, Colonies, Turmoil and the
Hellas or Elysium map as options, and notes the Corporate Era (extended game) in setup. The solo and draft
variants (rulebook page 13) are not in the guide yet.

Component pictures in the app are cropped from these pages by `tools/crop_source_images.py`; each
picture's page and crop box are listed under `images` in the turn script.
