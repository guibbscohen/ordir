# Knarr — official sources

The PDF is the publisher's (Pandasaurus Games, under license from Bombyx) and is not stored in this repo.
It is the English rulebook linked from Knarr's page on pandasaurusgames.com. Download it with
`python3 tools/fetch_sources.py`, which checks it against the SHA-256 recorded in the turn script. Turn
scripts cite it by PDF page, and `tools/validate_turn_scripts.py` checks every cited excerpt against it.

| File | Source | Pages |
| --- | --- | --- |
| `rulebook-KNARR-ENG-PAN.pdf` | https://www.dropbox.com/scl/fi/a57vjcbllhfruqk2ygvu6/rulebook-KNARR-ENG-PAN.pdf (linked from https://www.pandasaurusgames.com/products/knarr) | 12 |

The guide covers the base game for 2–4 players. The Artifacts variant (page 10) is not in the guide yet.

Component pictures in the app are cropped from these pages by `tools/crop_source_images.py`; each
picture's page and crop box are listed under `images` in the turn script.
